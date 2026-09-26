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

var _task_id := -1
var _group := false
var _waited := false
## Single task: the callable's return value. Group task: one entry per index, in
## index order. Each index writes only its own slot object, never a shared one.
var _slots: Array = []


## Runs work() -> Variant on a worker thread.
static func run(work: Callable, description := "") -> RefCounted:
	var job: RefCounted = new()
	var slot := {}
	job._slots = [slot]
	job._task_id = WorkerThreadPool.add_task(
		func() -> void: slot["value"] = work.call(), true, description
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
		func(index: int) -> void: slots[index]["value"] = work.call(index),
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


func is_done() -> bool:
	if _waited:
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
	if _group:
		WorkerThreadPool.wait_for_group_task_completion(_task_id)
	else:
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
