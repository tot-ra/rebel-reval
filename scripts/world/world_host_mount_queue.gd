class_name WorldHostMountQueue
extends RefCounted

## WB-08c (R-1044): staged, in-flight neighbour mounts for WorldHost.
##
## A synchronous seam mount measured 4.3-6.6 s frames in the R-1043 walk trace.
## Behind `world_host/async_location_assembly_enabled` a neighbour mounts in three
## phases instead, so the main thread never pays more than the frame budget:
##   PREPARING  - a WorkerThreadPool task compiles the definition, builds the grid
##                and assembles the detached logic package (collision, navigation,
##                doors). Probe on lower_town_slice / south_quarter: 210 / 340 ms
##                of pure data and detached nodes, none of it in the tree.
##   ASSEMBLING - MapView3D.create_hosted_staged() drains its unit plan within the
##                shared per-frame budget (R-979).
##   VERIFYING  - a worker walks both finished, detached packages for host-global
##                nodes and stable handles (WorldHostPackageInspector), which the
##                trace measured at ~11 ms of the mount frame on the main thread,
##                and splits the view for sliced tree entry (WB-08e).
##   ENTERING   - WB-08e (R-1069): the view enters a hidden host staging root in
##                budgeted slices (a whole district cost ~8 ms in one frame). No
##                seam, registry or navigation sees it until the host mounts it.
##   READY      - WorldHost mounts the logic package and reveals the view.
## REFINING is the ADR 0019 "low-priority visuals defer first" fallback: when the
## player reaches the seam while only decoration stages remain, the view pauses,
## a worker verifies and splits the part already built, it enters in slices, and
## the host mounts it early (collision truth is complete, ground and buildings
## exist). The remaining view units then keep running inside the tree.
## Evicted packages leave in slices too (step_evictions): the host detaches the
## logic package at once, so navigation and collision leave immediately, and the
## hidden view and the detached nodes are freed within the frame budget.
## The active (owning) map is never staged; WorldHost loads it synchronously.

# VERIFYING_EARLY and ENTERING are appended so the older values keep their ints.
enum Phase { PREPARING, ASSEMBLING, VERIFYING, READY, REFINING, FAILED, VERIFYING_EARLY, ENTERING }

const Assembly := preload("res://scripts/map/view3d/map_view_assembly.gd")
## First stage whose absence the player may see without losing gameplay truth.
## Everything from here on (scatter, batching, door/anchor visuals, local lights,
## weather binding, view effects) is decoration by ADR 0019's fallback order.
const FIRST_DEFERRABLE_STAGE := &"scatter"
## Retry backoff for failed neighbour mounts, in streaming ticks (physics frames):
## 0.5 s, doubling per consecutive failure, capped at 8 s. R-1043 retried a
## failing neighbour synchronously every frame while it stayed in the band.
const RETRY_BACKOFF_TICKS := 30
const RETRY_BACKOFF_MAX_TICKS := 480
## Largest subtree that enters (or leaves) the tree as one slice. A procedural
## view node costs a few microseconds to enter, so a slice stays far below the
## budget; scripted or non-container subtrees are atomic whatever their size.
const ENTRY_SLICE_MAX_NODES := 64

var enabled: bool
var frame_budget_usec: int
## Artificial delayed I/O for the ADR 0019 gate: the worker sleeps this long
## before preparing. Tests and benchmarks only; never set by a launch path.
var prepare_delay_msec := 0
## Main-thread microseconds of the most expensive single entry/eviction slice
## (trace diagnostics; an atomic subtree over the budget shows up here).
var max_slice_usec := 0
## "enter|evict <class> <name> (<n> nodes)" of that slice.
var max_slice_label := ""
## Peak teardown-only slice (R-1077). Entry slices stay in max_slice_usec.
var max_evict_slice_usec := 0
## Entry plus teardown slice microseconds spent in the current tick.
var tick_slice_usec := 0

var _pending: Dictionary = {}
## Cancelled while a worker task (prepare or verify) still runs. Never blocks the frame: polled
## every tick and released once the task ends (the R-1005 join contract).
var _draining: Array[PendingMount] = []
var _failures: Dictionary = {}
var _consecutive_failures: Dictionary = {}
var _retry_tick: Dictionary = {}
var _tick := 0
var _misses: Array[Dictionary] = []
var _open_misses: Dictionary = {}
var _globals: Dictionary = {}
## Creates the hidden, positioned host root a view enters (WorldHost binds it).
var _staging_root_factory := Callable()
## Roots being torn down in slices: hidden view roots still in the tree and
## detached logic packages or view slices. Oldest first.
var _evicting: Array[Node] = []


class PendingMount:
	extends RefCounted
	var location_id: StringName
	var phase: int = Phase.PREPARING
	var task_id := -1
	## Written once by the worker; read on the main thread only after the task ends.
	var prepared: Dictionary = {}
	var definition: MapDefinition
	var grid: MapTerrainGrid
	var logic_package: Node2D
	var view: MapView3D
	## WorldHostPackageInspector.inspect() result, written by the verify task.
	var inspection: Dictionary = {}
	var started_tick := 0
	## WB-08e: [parent, child] slices from split_for_entry(), written by the verify
	## task, and how many have entered the staging root so far.
	var entry_units: Array[Array] = []
	var entry_cursor := 0
	## Hidden host root the view enters; becomes the mounted view root.
	var view_root: Node3D
	## Set on the step that finished an early entry; the host mounts it and clears it.
	var mount_now := false


func _init() -> void:
	enabled = bool(ProjectSettings.get_setting(Assembly.ENABLED_SETTING, false))
	frame_budget_usec = int(Assembly.frame_budget_msec() * 1000.0)


## One streaming tick passed; releases drained worker results that have ended.
func advance_tick() -> void:
	_tick += 1
	tick_slice_usec = 0
	for index in range(_draining.size() - 1, -1, -1):
		var drained := _draining[index]
		if WorkerThreadPool.is_task_completed(drained.task_id):
			_join(drained)
			_release(drained)
			_draining.remove_at(index)


func tick() -> int:
	return _tick


func has_pending(location_id: StringName) -> bool:
	var pending := _pending.get(location_id) as PendingMount
	return pending != null and (pending.phase != Phase.REFINING or pending.mount_now)


## Locations still preparing, assembling, verifying or entering, sorted as text. They count against
## the residency cap but are never mounted, so no seam is active toward them.
func in_flight_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for location_id in _sorted_ids():
		if has_pending(location_id):
			ids.append(location_id)
	return ids


## The staged view of an in-flight or refining mount, or null (diagnostics, tests).
func pending_view(location_id: StringName) -> MapView3D:
	var pending := _pending.get(location_id) as PendingMount
	return pending.view if pending != null else null


func phase_of(location_id: StringName) -> int:
	var pending := _pending.get(location_id) as PendingMount
	return pending.phase if pending != null else -1


## Starts preparing `location_id` on a worker. False when it is already queued or
## still inside its retry backoff.
func start(location_id: StringName, provider: Callable) -> bool:
	if _pending.has(location_id) or not may_retry(location_id) or not provider.is_valid():
		return false
	var pending := PendingMount.new()
	pending.location_id = location_id
	pending.started_tick = _tick
	var delay := prepare_delay_msec
	pending.task_id = WorkerThreadPool.add_task(
		func() -> void: _prepare(pending, provider, delay),
		false,
		"WorldHost prepare %s" % String(location_id)
	)
	_pending[location_id] = pending
	return true


## Mounts whose view finished entering on an earlier tick: {"ready", "early"}.
## `ready` leave the queue with take_ready(); `early` stay queued as REFINING (the
## host clears `mount_now` once mounted). WB-08e: the host mounts these before it
## calls step(), so a mount never shares its tick with a full budget of slices.
func handovers() -> Dictionary:
	var result := {"ready": [], "early": []}
	for location_id in _sorted_ids():
		var pending := _pending[location_id] as PendingMount
		if pending.phase == Phase.READY:
			result["ready"].append(pending)
		elif pending.phase == Phase.REFINING and pending.mount_now:
			result["early"].append(pending)
	return result


## Runs in-flight work within `budget_usec` of main-thread time. Returns
## {"refined", "failed"}: early mounts whose view just completed (removed from the
## queue) and locations whose prepare failed. Finished entries wait in handovers().
func step(budget_usec: int) -> Dictionary:
	var result := {"refined": [], "failed": [] as Array[StringName]}
	var started := Time.get_ticks_usec()
	for location_id in _sorted_ids():
		var pending := _pending[location_id] as PendingMount
		if pending.phase == Phase.PREPARING:
			if not WorkerThreadPool.is_task_completed(pending.task_id):
				continue
			_join(pending)
			if not _adopt_prepared(pending):
				_pending.erase(location_id)
				result["failed"].append(location_id)
				continue
		var remaining := budget_usec - int(Time.get_ticks_usec() - started)
		if budget_usec > 0 and remaining <= 0:
			break
		if pending.phase == Phase.ASSEMBLING or (
			pending.phase == Phase.REFINING and not pending.mount_now
		):
			# A zero budget runs exactly one unit per view (MapViewAssembly.step()).
			pending.view.step_assembly(maxi(remaining, 0))
			if pending.view.is_assembly_complete():
				if pending.phase == Phase.REFINING:
					_pending.erase(location_id)
					result["refined"].append(pending)
					continue
				_start_verify(pending, Phase.VERIFYING)
		if (
			(pending.phase == Phase.VERIFYING or pending.phase == Phase.VERIFYING_EARLY)
			and WorkerThreadPool.is_task_completed(pending.task_id)
		):
			_join(pending)
			pending.phase = Phase.ENTERING
		if pending.phase == Phase.ENTERING:
			remaining = budget_usec - int(Time.get_ticks_usec() - started)
			if budget_usec > 0 and remaining <= 0:
				continue
			if not _enter_slices(pending, maxi(remaining, 0)):
				continue
			if pending.view.is_assembly_complete():
				pending.phase = Phase.READY
			else:
				pending.phase = Phase.REFINING
				pending.mount_now = true
	return result


## Hands a READY mount to the host (it leaves the queue).
func take_ready(pending: PendingMount) -> void:
	_pending.erase(pending.location_id)


## The player reached `location_id` before it was ready. Accepted (true) when the
## mount is already verifying or entering, or when every remaining view unit is
## decoration: the view then pauses and a worker verifies and splits the built
## part (never walked on the main thread). The host keeps the player waiting at
## the sealed seam until step() hands the mount over. False keeps waiting too.
func request_early(location_id: StringName) -> bool:
	var pending := _pending.get(location_id) as PendingMount
	if pending == null:
		return false
	if pending.phase in [Phase.VERIFYING, Phase.VERIFYING_EARLY, Phase.ENTERING, Phase.READY]:
		return true
	if pending.phase != Phase.ASSEMBLING or not only_decoration_left(pending.view):
		return false
	var miss := _open_misses.get(location_id, {}) as Dictionary
	if not miss.is_empty():
		miss["early_mounted"] = true
		miss["deferred_from_stage"] = String(pending.view.next_assembly_stage())
		miss["deferred_units"] = pending.view.pending_assembly_unit_count()
	_start_verify(pending, Phase.VERIFYING_EARLY)
	return true


static func only_decoration_left(view: MapView3D) -> bool:
	if view == null:
		return false
	var stage := view.next_assembly_stage()
	if stage.is_empty():
		return view.is_assembly_complete()
	return Assembly.STAGES.find(stage) >= Assembly.STAGES.find(FIRST_DEFERRABLE_STAGE)


## Stops an in-flight or refining mount. PREPARING work is drained without
## blocking the frame; a staged view cancels (joining its worker jobs) and its
## detached nodes are freed. A REFINING view is already mounted: the host frees it.
func cancel(location_id: StringName) -> bool:
	var pending := _pending.get(location_id) as PendingMount
	if pending == null:
		return false
	_pending.erase(location_id)
	_open_misses.erase(location_id)
	match pending.phase:
		Phase.PREPARING, Phase.VERIFYING, Phase.VERIFYING_EARLY:
			# A worker still reads (or builds) these packages: free them once it ends.
			_draining.append(pending)
		Phase.REFINING when not pending.mount_now:
			pending.view.cancel_assembly()
		_:
			_teardown(pending)
	return true


func cancel_all() -> void:
	for location_id in _sorted_ids():
		cancel(location_id)


## Blocks until every worker task ended. Only for host teardown: detached
## packages still waiting for a sliced free are freed now; roots inside the host
## tree go with the host.
func join_all() -> void:
	cancel_all()
	for drained in _draining:
		_join(drained)
		_release(drained)
	_draining.clear()
	for root in _evicting:
		if is_instance_valid(root) and root.get_parent() == null:
			root.free()
	_evicting.clear()


func draining_count() -> int:
	return _draining.size()


## Frees the packages of a mount the host could not mount.
func discard(pending: PendingMount) -> void:
	_pending.erase(pending.location_id)
	_teardown(pending)


## WB-08e: hands a mounted view root (already detached from gameplay) to the
## sliced teardown. It is hidden and stops processing now; its nodes leave the
## tree over the next ticks. The root is renamed so the location can mount again
## at once without a name clash.
func evict_view_root(view_root: Node3D) -> void:
	if view_root == null or not is_instance_valid(view_root):
		return
	view_root.name = "%s__evicting_%d" % [String(view_root.name), view_root.get_instance_id()]
	view_root.visible = false
	for child in view_root.get_children():
		# Its _process reads nodes that are about to leave; stop it first.
		child.set_process(false)
		child.set_physics_process(false)
	_evicting.append(view_root)


## WB-08e: queues a detached subtree (a logic package that left the tree, or a
## view slice that never entered) for a sliced free.
func evict_detached(root: Node) -> void:
	if root != null and is_instance_valid(root):
		_evicting.append(root)


func evicting_count() -> int:
	return _evicting.size()


## Tears queued roots down within `budget_usec` (0: exactly one slice; negative:
## everything, for teardown and tests). One slice removes the last leaf or atomic
## subtree of a root, so no single tree exit costs a whole district.
func step_evictions(budget_usec: int) -> void:
	var started := Time.get_ticks_usec()
	while not _evicting.is_empty():
		var root := _evicting[0]
		if not is_instance_valid(root):
			_evicting.remove_at(0)
			continue
		var slice_started := Time.get_ticks_usec()
		var node := WorldHostPackageInspector.next_removal(root)
		var is_root := node == root
		var label := "%s %s" % [node.get_class(), String(node.name)]
		var parent := node.get_parent()
		if parent != null:
			parent.remove_child(node)
		# WHY: MultiMesh still needs the strip to avoid dummy-renderer
		# material_get_instance_shader_parameters ERRORs. A leaf mesh can
		# free with its BoxMesh RID intact (R-1077).
		if WorldHostPackageInspector.needs_geometry_strip(node):
			MapView3D._strip_geometry_materials(node)
		node.free()
		if is_root:
			_evicting.remove_at(0)
		var now := Time.get_ticks_usec()
		_record_slice(&"evict", null, int(now - slice_started), label)
		if budget_usec >= 0 and (budget_usec == 0 or now - started >= budget_usec):
			return


func _record_slice(kind: StringName, node: Node, usec: int, label := "") -> void:
	tick_slice_usec += usec
	if kind == &"evict" and usec > max_evict_slice_usec:
		max_evict_slice_usec = usec
	if usec <= max_slice_usec:
		return
	max_slice_usec = usec
	if node != null:
		label = "%s %s (%d nodes)" % [
			node.get_class(), String(node.name), node.get_child_count(true) + 1
		]
	max_slice_label = "%s %s" % [kind, label]


## Frees what a cancelled or rejected mount still owns. Before tree entry nothing
## is in the tree; once entry started, the staging root and the slices that have
## not entered yet go through the sliced teardown.
func _teardown(pending: PendingMount) -> void:
	if pending.view != null:
		pending.view.cancel_assembly()
	if pending.view_root == null:
		_release(pending)
		return
	evict_view_root(pending.view_root)
	for index in range(pending.entry_cursor, pending.entry_units.size()):
		evict_detached(pending.entry_units[index][1] as Node)
	if pending.logic_package != null and pending.logic_package.get_parent() == null:
		evict_detached(pending.logic_package)
	pending.entry_units = []
	pending.view_root = null
	pending.logic_package = null
	pending.view = null


func record_failure(location_id: StringName) -> void:
	_failures[location_id] = failure_count(location_id) + 1
	var consecutive := int(_consecutive_failures.get(location_id, 0)) + 1
	_consecutive_failures[location_id] = consecutive
	var wait := mini(RETRY_BACKOFF_TICKS << mini(consecutive - 1, 8), RETRY_BACKOFF_MAX_TICKS)
	_retry_tick[location_id] = _tick + wait


func record_success(location_id: StringName) -> void:
	_consecutive_failures.erase(location_id)
	_retry_tick.erase(location_id)


func failure_count(location_id: StringName) -> int:
	return int(_failures.get(location_id, 0))


func may_retry(location_id: StringName) -> bool:
	return _tick >= int(_retry_tick.get(location_id, 0))


## A hard-readiness miss: the player reached `location_id` before it was ready.
## One record per edge visit, with package/chunk diagnostics (ADR 0019 gate).
func record_miss(location_id: StringName, from_location_id: StringName) -> Dictionary:
	if _open_misses.has(location_id):
		var open := _open_misses[location_id] as Dictionary
		open["waited_ticks"] = _tick - int(open["tick"])
		return open
	var pending := _pending.get(location_id) as PendingMount
	var view := pending.view if pending != null else null
	var miss := {
		"location_id": String(location_id),
		"from_location_id": String(from_location_id),
		"tick": _tick,
		"waited_ticks": 0,
		"phase": Phase.keys()[pending.phase] if pending != null else "UNQUEUED",
		"ticks_in_flight": _tick - pending.started_tick if pending != null else 0,
		"logic_package_ready": pending != null and pending.logic_package != null,
		"next_stage": String(view.next_assembly_stage()) if view != null else "",
		"pending_units": view.pending_assembly_unit_count() if view != null else -1,
		"early_mounted": false,
	}
	_misses.append(miss)
	_open_misses[location_id] = miss
	return miss


## The edge visit ended (mounted, cancelled, or the player turned back).
func close_miss(location_id: StringName) -> void:
	_open_misses.erase(location_id)


func misses() -> Array[Dictionary]:
	return _misses.duplicate(true)


func _sorted_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for location_id in _pending.keys():
		ids.append(StringName(location_id))
	ids.sort_custom(
		func(left: StringName, right: StringName) -> bool: return String(left) < String(right)
	)
	return ids


## Worker body. Door scenes still instantiate here; wait until compute workers
## (pattern bakes) are idle so the two kinds never overlap (R-1070).
## Runtime load, not preload: a compile-time edge into map_view_worker_job.gd
## hides this class_name from world_host.gd (R-1070).
static func _worker_kind_gate():
	return load("res://scripts/map/view3d/map_view_worker_job.gd")


static func _prepare(pending: PendingMount, provider: Callable, delay_msec: int) -> void:
	var gate = _worker_kind_gate()
	gate.begin_scene_work()
	if delay_msec > 0:
		OS.delay_msec(delay_msec)
	var definition := provider.call(pending.location_id) as MapDefinition
	if definition == null:
		gate.end_scene_work()
		return
	var grid := MapBuilder.build(definition)
	pending.prepared = {
		"definition": definition,
		"grid": grid,
		"logic_package": MapSceneBootstrap.assemble_location_package(definition, grid),
	}
	gate.end_scene_work()


## `phase` is VERIFYING (the view is complete) or VERIFYING_EARLY (the view is
## paused before its decoration: step() does not run it until it has entered).
## The worker inspects both detached packages, then splits the view for sliced
## tree entry; nothing else touches them until the task ends.
func _start_verify(pending: PendingMount, phase: int) -> void:
	pending.phase = phase
	var location_id := pending.location_id
	var logic_package := pending.logic_package
	var view := pending.view
	pending.task_id = WorkerThreadPool.add_task(
		func() -> void:
			var gate = _worker_kind_gate()
			gate.begin_scene_work()
			pending.inspection = WorldHostPackageInspector.inspect(
				location_id, logic_package, view
			)
			# The split edits (detached) nodes: scene work too (R-1070).
			pending.entry_units = WorldHostPackageInspector.split_for_entry(
				view, ENTRY_SLICE_MAX_NODES
			)
			gate.end_scene_work(),
		false,
		"WorldHost verify %s" % String(location_id)
	)


## Adds split slices to the hidden staging root until `budget_usec` is spent
## (0: exactly one slice). True once the whole view has entered.
func _enter_slices(pending: PendingMount, budget_usec: int) -> bool:
	if pending.view_root == null:
		pending.view_root = _staging_root_factory.call(pending.location_id) as Node3D
	var started := Time.get_ticks_usec()
	while pending.entry_cursor < pending.entry_units.size():
		var slice_started := Time.get_ticks_usec()
		var unit := pending.entry_units[pending.entry_cursor]
		var parent := unit[0] as Node
		(parent if parent != null else pending.view_root).add_child(unit[1] as Node)
		pending.entry_cursor += 1
		var now := Time.get_ticks_usec()
		_record_slice(&"enter", unit[1] as Node, int(now - slice_started))
		if budget_usec == 0 or now - started >= budget_usec:
			break
	return pending.entry_cursor >= pending.entry_units.size()


func _adopt_prepared(pending: PendingMount) -> bool:
	if pending.prepared.is_empty():
		pending.phase = Phase.FAILED
		return false
	pending.definition = pending.prepared["definition"] as MapDefinition
	pending.grid = pending.prepared["grid"] as MapTerrainGrid
	pending.logic_package = pending.prepared["logic_package"] as Node2D
	pending.prepared = {}
	pending.view = MapView3D.create_hosted_staged(pending.definition, pending.grid, _globals)
	pending.phase = Phase.ASSEMBLING
	return true


## The host globals every staged view binds (WorldHost.view_globals()).
func bind_globals(globals: Dictionary) -> void:
	_globals = globals


## `factory(location_id) -> Node3D`: a hidden, positioned root inside the host's
## view layer that a view enters before it is mounted (WorldHost binds it).
func bind_staging_root_factory(factory: Callable) -> void:
	_staging_root_factory = factory


static func _join(pending: PendingMount) -> void:
	if pending.task_id >= 0:
		WorkerThreadPool.wait_for_task_completion(pending.task_id)
		pending.task_id = -1


## Frees detached (never mounted) packages. A prepared result that was never
## adopted still owns its logic package.
static func _release(pending: PendingMount) -> void:
	var package := pending.logic_package
	if package == null and not pending.prepared.is_empty():
		package = pending.prepared.get("logic_package") as Node2D
	pending.prepared = {}
	var roots: Array[Node] = [package, pending.view]
	# A split view (WB-08e) is several detached subtrees; free every one of them.
	for unit in pending.entry_units:
		if unit[1] != pending.view:
			roots.append(unit[1] as Node)
	for node in roots:
		if node != null and is_instance_valid(node) and node.get_parent() == null:
			if node != package:
				# Same teardown as a view leaving the tree (dummy-renderer RID noise).
				MapView3D._strip_geometry_materials(node)
			node.free()
	pending.entry_units = []
	pending.logic_package = null
	pending.view = null
