extends RefCounted

## WB-07b (R-1005): one WorkerThreadPool task, or one group task, whose result a
## later main-thread assembly unit publishes. Workers only compute plain data
## (packed arrays, dictionaries, images, map definitions) into objects no other
## thread can see. Nodes, meshes, textures and every static cache are created or
## written on the main thread after wait(), so no builder cache is shared across
## threads.

## Threads one group task may occupy. GDScript bands share refcounted objects
## (the grid, the field dictionary, string keys), so atomic contention caps the
## gain: on an 18-thread M5 Pro the lower_town_slice ground bake takes 2.5 s on
## one thread, 1.7 s on 4 or 8 and 2.2 s on all 18. Four also leaves the pool free
## for threaded loads and navigation bakes while a neighbour assembles.
const GROUP_THREADS := 4

## R-1070: Godot 4.7 SIGSEGV'd when a pattern bake overlapped a WorldHost
## PREPARING task that instantiated Door scenes. Compute jobs (images, packed
## arrays) may share the pool; scene/script instantiation waits until they
## finish, and the reverse. One kind at a time, not one thread at a time.
static var _kind_gate := Mutex.new()
static var _compute_active := 0
static var _scene_active := 0

var _task_id := -1
var _group := false
var _waited := false
## WB-07d (R-1010): paths of a threaded ResourceLoader prefetch; empty otherwise.
var _load_paths := PackedStringArray()
## Single task: the callable's return value. Group task: one entry per index, in
## index order. Each index writes only its own slot object, never a shared one.
var _slots: Array = []


static func begin_compute_work() -> void:
	_enter_kind(true)


static func end_compute_work() -> void:
	_leave_kind(true)


static func begin_scene_work() -> void:
	_enter_kind(false)


static func end_scene_work() -> void:
	_leave_kind(false)


static func _enter_kind(as_compute: bool) -> void:
	while true:
		_kind_gate.lock()
		var other_active := _scene_active if as_compute else _compute_active
		if other_active == 0:
			if as_compute:
				_compute_active += 1
			else:
				_scene_active += 1
			_kind_gate.unlock()
			return
		_kind_gate.unlock()
		OS.delay_msec(1)


static func _leave_kind(as_compute: bool) -> void:
	_kind_gate.lock()
	if as_compute:
		_compute_active = maxi(_compute_active - 1, 0)
	else:
		_scene_active = maxi(_scene_active - 1, 0)
	_kind_gate.unlock()


## Runs work() -> Variant on a worker thread.
static func run(work: Callable, description := "") -> RefCounted:
	var job: RefCounted = new()
	var slot := {}
	job._slots = [slot]
	job._task_id = WorkerThreadPool.add_task(
		func() -> void:
			begin_compute_work()
			slot["value"] = work.call()
			end_compute_work(),
		true,
		description
	)
	return job


## Runs work(index) -> Variant for index in [0, count) across the worker pool.
static func run_group(work: Callable, count: int, description := "") -> RefCounted:
	var job: RefCounted = new()
	var slots: Array = []
	for index in count:
		slots.append({})
	job._slots = slots
	job._group = true
	if count <= 0:
		job._waited = true
		return job
	job._task_id = WorkerThreadPool.add_group_task(
		func(index: int) -> void:
			begin_compute_work()
			slots[index]["value"] = work.call(index)
			end_compute_work(),
		count,
		GROUP_THREADS,
		true,
		description
	)
	return job


## A job that already holds its value; lets callers skip the pool for empty work.
static func done(value: Variant) -> RefCounted:
	var job: RefCounted = new()
	job._slots = [{"value": value}]
	job._waited = true
	return job


## WB-07d (R-1010): loads resources through ResourceLoader's threaded requests.
## value() is the Array of loaded resources in path order (null for a failed
## load). Holding it keeps them in the resource cache, so a later load() of the
## same path on the main thread returns at once instead of reading the file.
static func load_resources(paths: PackedStringArray) -> RefCounted:
	var job: RefCounted = new()
	job._slots = [{}]
	job._load_paths = paths
	for path in paths:
		ResourceLoader.load_threaded_request(path)
	return job


func is_done() -> bool:
	if _waited:
		return true
	if not _load_paths.is_empty():
		for path in _load_paths:
			if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				return false
		return true
	if _group:
		return WorkerThreadPool.is_group_task_completed(_task_id)
	return WorkerThreadPool.is_task_completed(_task_id)


## Blocks until the work finished. Safe to call more than once: the pool must be
## waited exactly once per task, or the task leaks.
func wait() -> void:
	if _waited:
		return
	_waited = true
	if not _load_paths.is_empty():
		# load_threaded_get() blocks until done and must be called once per request.
		var loaded: Array = []
		for path in _load_paths:
			loaded.append(ResourceLoader.load_threaded_get(path))
		_slots[0]["value"] = loaded
		return
	if _group:
		WorkerThreadPool.wait_for_group_task_completion(_task_id)
	else:
		WorkerThreadPool.wait_for_task_completion(_task_id)


## WB-07d (R-1010): a job dropped without wait() still joins its task, because
## the pool must be waited once per task. This covers bakes that were started but
## whose await unit had not been queued yet when a staged assembly was cancelled
## (neighbor-preview material bakes start one pass before their previews).
## Inlined: a RefCounted cannot call its own methods during PREDELETE.
func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE or _waited:
		return
	_waited = true
	if not _load_paths.is_empty():
		for path in _load_paths:
			ResourceLoader.load_threaded_get(path)
	elif _group:
		WorkerThreadPool.wait_for_group_task_completion(_task_id)
	elif _task_id >= 0:
		WorkerThreadPool.wait_for_task_completion(_task_id)


## The finished value (single task) after waiting.
func value() -> Variant:
	wait()
	return _slots[0].get("value")


## The finished values of a group task, in index order, after waiting.
func values() -> Array:
	wait()
	var result: Array = []
	for slot in _slots:
		result.append(slot.get("value"))
	return result
