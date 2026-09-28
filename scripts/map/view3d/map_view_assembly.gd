extends RefCounted

## WB-07 (R-979) resumable work queue behind MapView3D assembly. It owns the unit
## plan, the budget loop and the timing records. The stage bodies stay on
## MapView3D because they build its private nodes. Both create() and
## create_staged() drain the same plan, so the two paths cannot drift apart.

enum State { SYNCHRONOUS, RUNNING, COMPLETE, CANCELLED }

const PackedScenes := preload("res://scripts/map/view3d/map_view_packed_scenes.gd")
const WorkerJob := preload("res://scripts/map/view3d/map_view_worker_job.gd")

## The flag stays off until the ADR 0019 phase gates pass; the budget is
## main-thread milliseconds per frame (a quarter of a 60 Hz frame).
const ENABLED_SETTING := "world_host/async_location_assembly_enabled"
const FRAME_BUDGET_SETTING := "world_host/location_assembly_frame_budget_ms"
const DEFAULT_FRAME_BUDGET_MSEC := 4.0
## Rows per scatter band unit; see scatter_chunk_units().
const SCATTER_BAND_ROWS := 4
## Stable stage names, in execution order. The performance report and the WB-07
## report key their per-stage rows on these strings.
const STAGES: Array[StringName] = [
	&"height_field",
	&"surroundings",
	&"terrain_mesh",
	&"interior_shell",
	&"decals",
	&"object_index",
	&"buildings_props",
	&"scatter",
	&"chunk_finalize",
	&"transition_visuals",
	&"anchors",
	&"lighting",
	&"sky_weather",
	&"view_effects",
]

var state := State.SYNCHRONOUS
var units: Array[Dictionary] = []
## Stage name -> accumulated microseconds, in first-run order.
var stage_usec: Dictionary = {}
## One {"stage", "label", "usec"} per executed unit, in execution order.
var unit_log: Array[Dictionary] = []
## Main-thread microseconds per frame spent by MapView3D.assemble_async().
var frame_usec := PackedInt64Array()
## WB-07c (R-1006): GLB scenes and kit plates this queue's units loaded (path ->
## resource), kept for the queue's, and so the owning view's, lifetime.
var scene_pins: Dictionary = {}
## Stage name -> executed unit count; with stage_usec, the per-stage mean cost.
var _stage_units: Dictionary = {}
## drain() queues run inside another queue's unit and pin into that queue's set.
var _owns_scene_pins := true


## Whether scene entry points use staged assembly, threaded navigation and
## threaded scene loads. Default off per ADR 0019.
static func enabled() -> bool:
	return bool(ProjectSettings.get_setting(ENABLED_SETTING, false))


static func frame_budget_msec() -> float:
	var budget: Variant = ProjectSettings.get_setting(FRAME_BUDGET_SETTING, DEFAULT_FRAME_BUDGET_MSEC)
	return maxf(float(budget), 0.0)


static func unit(stage: StringName, label: String, run: Callable) -> Dictionary:
	return {"stage": stage, "label": label, "run": run}


## WB-07b (R-1005): a unit that waits for a MapViewWorkerJob. Staged assembly
## gives the rest of the frame back while the worker runs, so waiting costs no
## main-thread time; the synchronous path blocks on it instead. The unit that
## publishes the result follows it in the queue.
static func await_job(stage: StringName, label: String, job: RefCounted) -> Dictionary:
	return {"stage": stage, "label": "await_%s" % label, "job": job}


## Drains builder units outside a view (the public build_* entry points), with
## the same follow-up and job semantics as the view queue.
static func drain(plan: Array[Dictionary]) -> void:
	var queue: RefCounted = new()
	queue._owns_scene_pins = false
	queue.run_all(plan)


## WB-07c (R-1006): loads `paths` through threaded ResourceLoader requests that
## start now, then pins them in the running queue's set. A later builder load()
## of any of them returns at once instead of reading the GLB on the main thread.
static func scene_prefetch_units(
	stage: StringName, label: String, paths: PackedStringArray
) -> Array[Dictionary]:
	if paths.is_empty():
		return []
	var missing := PackedScenes.uncached(paths)
	var pin := func(_loads: RefCounted) -> void:
		for path in paths:
			PackedScenes.load_pinned(path)
	var pin_label := "%s_scene_pins" % label
	if missing.is_empty():
		return [unit(stage, pin_label, pin.bind(null))]
	if DisplayServer.get_name() == "headless":
		return _serial_scene_prefetch_units(stage, label, missing, pin_label, pin)
	var loads: RefCounted = WorkerJob.load_resources(missing)
	return [await_job(stage, "%s_scenes" % label, loads), unit(stage, pin_label, pin.bind(loads))]


## WHY: the headless dummy renderer's mesh RID_Owner is not thread-safe. A GLB
## whose meshes load on a loader thread while the main thread or another loader
## thread creates a mesh corrupts it ("Attempting to initialize the wrong RID").
## Headless therefore loads one GLB at a time, each started at its own await, so
## nothing else of this view creates a mesh meanwhile.
static func _serial_scene_prefetch_units(
	stage: StringName,
	label: String,
	missing: PackedStringArray,
	pin_label: String,
	pin: Callable
) -> Array[Dictionary]:
	var units: Array[Dictionary] = []
	for path in missing:
		var start := func() -> Array[Dictionary]:
			var job: RefCounted = WorkerJob.load_resources(PackedStringArray([path]))
			# The bound job keeps the resource cached until load_pinned() pins it.
			var keep := func(_loads: RefCounted) -> void: PackedScenes.load_pinned(path)
			return [
				await_job(stage, "%s_scene" % label, job),
				unit(stage, "%s_scene_pin" % label, keep.bind(job)),
			]
		units.append(unit(stage, "%s_scene_start" % label, start))
	units.append(unit(stage, pin_label, pin.bind(null)))
	return units


## Ordered work units for one view. Order matches the pre-WB-07 monolithic
## MapView3D._assemble() exactly; object chunks follow MapObjectChunkStreamer's
## sorted load order, so the staged tree is node-for-node the synchronous tree.
static func plan_for(view: Node3D, chunks: Array[Vector2i]) -> Array[Dictionary]:
	var ordered: Array[Vector2i] = chunks.duplicate()
	ordered.sort_custom(
		func(left: Vector2i, right: Vector2i) -> bool:
			return left.y < right.y or (left.y == right.y and left.x < right.x)
	)
	var definition: MapDefinition = view.get("definition")
	var scene_paths := PackedStringArray()
	var scenes_key := ""
	if definition != null:
		scenes_key = PackedScenes.map_key(definition)
		scene_paths = PackedScenes.learned_paths(scenes_key)
		scene_paths.append_array(
			MapViewMeshBuilderBuildingHouses.production_resource_paths(definition.buildings)
		)
	# The height field is a pure, cached derivation that surroundings, terrain,
	# props and scatter all read; paying it first keeps the terrain unit smaller.
	var plan: Array[Dictionary] = [
		unit(&"height_field", "height_field", Callable(view, &"_stage_height_field")),
	]
	# The GLB loads start with the plan and are awaited before the neighbor
	# previews, whose houses, yards and livestock use the same kits.
	plan.append_array(scene_prefetch_units(&"height_field", "objects", scene_paths))
	plan.append_array([
		unit(&"surroundings", "surroundings", Callable(view, &"_stage_surroundings")),
		unit(&"terrain_mesh", "terrain_mesh", Callable(view, &"_stage_terrain_mesh")),
		unit(&"interior_shell", "interior_shell", Callable(view, &"_stage_interior_shell")),
		unit(&"decals", "containers_and_decals", Callable(view, &"_stage_containers_and_decals")),
		unit(&"object_index", "object_index", Callable(view, &"_stage_object_index")),
	])
	for chunk in ordered:
		var label := "chunk_%d_%d" % [chunk.x, chunk.y]
		plan.append(
			unit(&"buildings_props", label, Callable(view, &"_expand_object_chunk").bind(chunk))
		)
	for chunk in chunks:
		var label := "chunk_%d_%d" % [chunk.x, chunk.y]
		plan.append(unit(&"scatter", label, scatter_chunk_units.bind(view, chunk, label)))
	var finalize := Callable(view, &"_stage_chunk_finalize").bind(chunks)
	plan.append(unit(&"chunk_finalize", "chunk_finalize", finalize))
	for stage: StringName in [
		&"transition_visuals", &"anchors", &"lighting", &"sky_weather", &"view_effects"
	]:
		plan.append(unit(stage, String(stage), Callable(view, StringName("_stage_%s" % stage))))
	if not scenes_key.is_empty():
		var remember := PackedScenes.remember_active.bind(scenes_key)
		plan.append(unit(&"view_effects", "remember_scenes", remember))
	return plan


## WB-07c (R-1006): one scatter chunk as row-band units plus two emit units. Each
## band is SCATTER_BAND_ROWS rows of the per-cell pass (about 1-2 ms warm on
## Lower Town); the layer and shore units emit, and the shore unit adds the
## finished chunk to the view.
static func scatter_chunk_units(view: Node3D, chunk: Vector2i, label: String) -> Array[Dictionary]:
	var grid: MapTerrainGrid = view.get("grid")
	var state := MapViewMeshBuilderScatter.begin_scatter(
		view.get("definition"), grid, grid.chunk_bounds(chunk)
	)
	var bounds: Rect2i = state["bounds"]
	var units: Array[Dictionary] = []
	var row: int = state["next_row"]
	while row < bounds.end.y:
		row = mini(row + SCATTER_BAND_ROWS, bounds.end.y)
		var band := MapViewMeshBuilderScatter.collect_rows.bind(state, row)
		units.append(unit(&"scatter", "%s_rows_%d" % [label, row], band))
	var layers := MapViewMeshBuilderScatter.emit_layers.bind(state)
	units.append(unit(&"scatter", "%s_layers" % label, layers))
	var emit := func() -> void:
		view.call(&"_load_scatter_chunk", chunk, MapViewMeshBuilderScatter.emit_shore(state))
	units.append(unit(&"scatter", "%s_shore" % label, emit))
	return units


func run_all(plan: Array[Dictionary]) -> void:
	units = plan
	while not units.is_empty():
		run_next()


func start(plan: Array[Dictionary]) -> void:
	units = plan
	state = State.RUNNING


## Runs units until budget_usec is spent. A unit is never split, so one call may
## overrun by at most the unit that crossed the budget. WB-08c (R-1044): after the
## first unit of a call, a unit whose stage mean no longer fits the rest of the
## budget waits for the next frame, so ordinary units stop crossing the budget.
## The first unit always runs, so a heavy unit still makes progress (and still
## overruns: those are R-1006's to split). Returns true only when this call
## drained the queue; the owner then finishes the view.
func step(budget_usec: int) -> bool:
	if state != State.RUNNING:
		return false
	var started := Time.get_ticks_usec()
	var ran := 0
	while not units.is_empty():
		var elapsed := Time.get_ticks_usec() - started
		if ran > 0 and elapsed + _expected_usec(units[0]) > budget_usec:
			break
		# A worker job is still running: yield the frame instead of blocking on it.
		if not run_next():
			break
		ran += 1
		if Time.get_ticks_usec() - started >= budget_usec:
			break
	return units.is_empty()


## A unit may return an Array of follow-up units (an object chunk expanding into
## one unit per object); they run next, ahead of everything already queued.
## Returns false, without running anything, when the next unit awaits a worker
## job that has not finished during a staged assembly.
func run_next() -> bool:
	var next: Dictionary = units.pop_front()
	var job: RefCounted = next.get("job")
	if job != null and state == State.RUNNING and not job.is_done():
		units.push_front(next)
		return false
	var started := Time.get_ticks_usec()
	var follow_ups: Variant = null
	if job != null:
		job.wait()
	else:
		if _owns_scene_pins:
			PackedScenes.push_pins(scene_pins)
		follow_ups = (next["run"] as Callable).call()
		if _owns_scene_pins:
			PackedScenes.pop_pins()
	var elapsed := Time.get_ticks_usec() - started
	if follow_ups is Array:
		var expanded: Array = follow_ups
		for index in range(expanded.size() - 1, -1, -1):
			units.push_front(expanded[index])
	var stage: StringName = next["stage"]
	stage_usec[stage] = int(stage_usec.get(stage, 0)) + elapsed
	_stage_units[stage] = int(_stage_units.get(stage, 0)) + 1
	unit_log.append({"stage": stage, "label": next["label"], "usec": elapsed})
	return true


## Mean cost of the unit's stage so far; 0 for an await unit or an unseen stage.
func _expected_usec(next: Dictionary) -> int:
	if next.get("job") != null:
		return 0
	var stage: StringName = next["stage"]
	var count := int(_stage_units.get(stage, 0))
	return int(stage_usec.get(stage, 0)) / count if count > 0 else 0


func cancel() -> bool:
	if state != State.RUNNING:
		return false
	_join_queued_jobs()
	units.clear()
	state = State.CANCELLED
	return true


## Every started worker job has an await unit queued behind it. Joining them on
## cancel or when the view is freed mid-assembly keeps no task un-waited in the
## pool; their results are dropped.
func _join_queued_jobs() -> void:
	for queued in units:
		var job: RefCounted = queued.get("job")
		if job != null:
			job.wait()


func _notification(what: int) -> void:
	# Inlined: GDScript cannot call own methods during PREDELETE of a RefCounted.
	if what == NOTIFICATION_PREDELETE:
		for queued in units:
			var job: RefCounted = queued.get("job")
			if job != null:
				job.wait()
