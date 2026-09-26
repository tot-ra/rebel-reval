extends RefCounted

## WB-07 (R-979) resumable work queue behind MapView3D assembly. It owns the unit
## plan, the budget loop and the timing records. The stage bodies stay on
## MapView3D because they build its private nodes. Both create() and
## create_staged() drain the same plan, so the two paths cannot drift apart.

enum State { SYNCHRONOUS, RUNNING, COMPLETE, CANCELLED }

## The flag stays off until the ADR 0019 phase gates pass; the budget is
## main-thread milliseconds per frame (a quarter of a 60 Hz frame).
const ENABLED_SETTING := "world_host/async_location_assembly_enabled"
const FRAME_BUDGET_SETTING := "world_host/location_assembly_frame_budget_ms"
const DEFAULT_FRAME_BUDGET_MSEC := 4.0
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


## Whether scene entry points use staged assembly, threaded navigation and
## threaded scene loads. Default off per ADR 0019.
static func enabled() -> bool:
	return bool(ProjectSettings.get_setting(ENABLED_SETTING, false))


static func frame_budget_msec() -> float:
	var budget: Variant = ProjectSettings.get_setting(FRAME_BUDGET_SETTING, DEFAULT_FRAME_BUDGET_MSEC)
	return maxf(float(budget), 0.0)


static func unit(stage: StringName, label: String, run: Callable) -> Dictionary:
	return {"stage": stage, "label": label, "run": run}


## Ordered work units for one view. Order matches the pre-WB-07 monolithic
## MapView3D._assemble() exactly; object chunks follow MapObjectChunkStreamer's
## sorted load order, so the staged tree is node-for-node the synchronous tree.
static func plan_for(view: Node3D, chunks: Array[Vector2i]) -> Array[Dictionary]:
	var ordered: Array[Vector2i] = chunks.duplicate()
	ordered.sort_custom(
		func(left: Vector2i, right: Vector2i) -> bool:
			return left.y < right.y or (left.y == right.y and left.x < right.x)
	)
	# The height field is a pure, cached derivation that surroundings, terrain,
	# props and scatter all read; paying it first keeps the terrain unit smaller.
	var plan: Array[Dictionary] = [
		unit(&"height_field", "height_field", Callable(view, &"_stage_height_field")),
		unit(&"surroundings", "surroundings", Callable(view, &"_stage_surroundings")),
		unit(&"terrain_mesh", "terrain_mesh", Callable(view, &"_stage_terrain_mesh")),
		unit(&"interior_shell", "interior_shell", Callable(view, &"_stage_interior_shell")),
		unit(&"decals", "containers_and_decals", Callable(view, &"_stage_containers_and_decals")),
		unit(&"object_index", "object_index", Callable(view, &"_stage_object_index")),
	]
	for chunk in ordered:
		var label := "chunk_%d_%d" % [chunk.x, chunk.y]
		plan.append(
			unit(&"buildings_props", label, Callable(view, &"_expand_object_chunk").bind(chunk))
		)
	for chunk in chunks:
		var label := "chunk_%d_%d" % [chunk.x, chunk.y]
		plan.append(unit(&"scatter", label, Callable(view, &"_load_scatter_chunk").bind(chunk)))
	var finalize := Callable(view, &"_stage_chunk_finalize").bind(chunks)
	plan.append(unit(&"chunk_finalize", "chunk_finalize", finalize))
	for stage: StringName in [
		&"transition_visuals", &"anchors", &"lighting", &"sky_weather", &"view_effects"
	]:
		plan.append(unit(stage, String(stage), Callable(view, StringName("_stage_%s" % stage))))
	return plan


func run_all(plan: Array[Dictionary]) -> void:
	units = plan
	while not units.is_empty():
		run_next()


func start(plan: Array[Dictionary]) -> void:
	units = plan
	state = State.RUNNING


## Runs units until budget_usec is spent. A unit is never split, so one call may
## overrun by at most the unit that crossed the budget. Returns true only when
## this call drained the queue; the owner then finishes the view.
func step(budget_usec: int) -> bool:
	if state != State.RUNNING:
		return false
	var started := Time.get_ticks_usec()
	while not units.is_empty():
		run_next()
		if Time.get_ticks_usec() - started >= budget_usec:
			break
	return units.is_empty()


## A unit may return an Array of follow-up units (an object chunk expanding into
## one unit per object); they run next, ahead of everything already queued.
func run_next() -> void:
	var next: Dictionary = units.pop_front()
	var started := Time.get_ticks_usec()
	var follow_ups: Variant = (next["run"] as Callable).call()
	var elapsed := Time.get_ticks_usec() - started
	if follow_ups is Array:
		var expanded: Array = follow_ups
		for index in range(expanded.size() - 1, -1, -1):
			units.push_front(expanded[index])
	var stage: StringName = next["stage"]
	stage_usec[stage] = int(stage_usec.get(stage, 0)) + elapsed
	unit_log.append({"stage": stage, "label": next["label"], "usec": elapsed})


func cancel() -> bool:
	if state != State.RUNNING:
		return false
	units.clear()
	state = State.CANCELLED
	return true
