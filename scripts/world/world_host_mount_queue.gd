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
##                trace measured at ~11 ms of the mount frame on the main thread.
##   READY      - WorldHost mounts logic and view packages in one step.
## REFINING is the ADR 0019 "low-priority visuals defer first" fallback: when the
## player reaches the seam while only decoration stages remain, the host mounts
## the package early (collision truth is complete, ground and buildings exist)
## and the remaining view units keep running inside the tree.
## The active (owning) map is never staged; WorldHost loads it synchronously.

enum Phase { PREPARING, ASSEMBLING, VERIFYING, READY, REFINING, FAILED }

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

var enabled: bool
var frame_budget_usec: int
## Artificial delayed I/O for the ADR 0019 gate: the worker sleeps this long
## before preparing. Tests and benchmarks only; never set by a launch path.
var prepare_delay_msec := 0

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


func _init() -> void:
	enabled = bool(ProjectSettings.get_setting(Assembly.ENABLED_SETTING, false))
	frame_budget_usec = int(Assembly.frame_budget_msec() * 1000.0)


## One streaming tick passed; releases drained worker results that have ended.
func advance_tick() -> void:
	_tick += 1
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
	return pending != null and pending.phase != Phase.REFINING


## Locations still preparing or assembling, sorted as text. They count against
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


## Runs in-flight work within `budget_usec` of main-thread time. Returns
## {"ready", "refined", "failed"}: PendingMounts to mount, early mounts whose view
## just completed (removed from the queue), and locations whose prepare failed.
func step(budget_usec: int) -> Dictionary:
	var result := {"ready": [], "refined": [], "failed": [] as Array[StringName]}
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
		if pending.phase == Phase.ASSEMBLING or pending.phase == Phase.REFINING:
			# A zero budget runs exactly one unit per view (MapViewAssembly.step()).
			pending.view.step_assembly(maxi(remaining, 0))
			if pending.view.is_assembly_complete():
				if pending.phase == Phase.REFINING:
					_pending.erase(location_id)
					result["refined"].append(pending)
					continue
				_start_verify(pending)
		if pending.phase == Phase.VERIFYING and WorkerThreadPool.is_task_completed(pending.task_id):
			_join(pending)
			pending.phase = Phase.READY
		if pending.phase == Phase.READY:
			result["ready"].append(pending)
	return result


## Hands a READY mount to the host (it leaves the queue).
func take_ready(pending: PendingMount) -> void:
	_pending.erase(pending.location_id)


## Early mount at the seam deadline: only when every remaining view unit is
## decoration. The mount stays queued as REFINING until the view completes.
func take_early(location_id: StringName) -> PendingMount:
	var pending := _pending.get(location_id) as PendingMount
	if pending == null:
		return null
	if pending.phase == Phase.VERIFYING:
		# The deadline is here and the walk is nearly done: finish it now.
		_join(pending)
		pending.phase = Phase.READY
	if pending.phase == Phase.READY:
		_pending.erase(location_id)
		return pending
	if pending.phase != Phase.ASSEMBLING or not only_decoration_left(pending.view):
		return null
	pending.phase = Phase.REFINING
	var miss := _open_misses.get(location_id, {}) as Dictionary
	if not miss.is_empty():
		miss["early_mounted"] = true
		miss["deferred_from_stage"] = String(pending.view.next_assembly_stage())
		miss["deferred_units"] = pending.view.pending_assembly_unit_count()
	return pending


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
		Phase.PREPARING, Phase.VERIFYING:
			# A worker still reads (or builds) these packages: free them once it ends.
			_draining.append(pending)
		Phase.REFINING:
			pending.view.cancel_assembly()
		_:
			if pending.view != null:
				pending.view.cancel_assembly()
			_release(pending)
	return true


func cancel_all() -> void:
	for location_id in _sorted_ids():
		cancel(location_id)


## Blocks until every worker task ended. Only for host teardown.
func join_all() -> void:
	cancel_all()
	for drained in _draining:
		_join(drained)
		_release(drained)
	_draining.clear()


func draining_count() -> int:
	return _draining.size()


## Frees the detached packages of a mount the host could not mount.
func discard(pending: PendingMount) -> void:
	_pending.erase(pending.location_id)
	if pending.view != null:
		pending.view.cancel_assembly()
	_release(pending)


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


func _start_verify(pending: PendingMount) -> void:
	pending.phase = Phase.VERIFYING
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
			gate.end_scene_work(),
		false,
		"WorldHost verify %s" % String(location_id)
	)


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
	for node: Node in [package, pending.view]:
		if node != null and is_instance_valid(node) and node.get_parent() == null:
			if node is MapView3D:
				# Same teardown as a view leaving the tree (dummy-renderer RID noise).
				MapView3D._strip_geometry_materials(node)
			node.free()
	pending.logic_package = null
	pending.view = null
