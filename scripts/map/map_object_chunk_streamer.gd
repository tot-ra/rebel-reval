class_name MapObjectChunkStreamer
extends Node

## Shared load/unload lifecycle for stable-ID map objects. A boundary-spanning
## object remains one complete instance while any consumer chunk is resident;
## chunks never create clipped authoritative duplicates.

signal object_loaded(handle: Dictionary, instance: Node)
signal object_unloaded(handle: Dictionary)

var index: MapChunkRuntimeIndex
var _factory: Callable
var _loaded_chunks: Dictionary = {}
var _instances: Dictionary = {}
var _parents_by_kind: Dictionary = {}


func configure(runtime_index: MapChunkRuntimeIndex, factory: Callable, parents_by_kind: Dictionary = {}) -> void:
	assert(runtime_index != null)
	assert(factory.is_valid())
	index = runtime_index
	_factory = factory
	_parents_by_kind = parents_by_kind.duplicate()
	_load_persistent_records()


func load_chunk(coordinates: Vector2i) -> void:
	if index == null or _loaded_chunks.has(coordinates):
		return
	_loaded_chunks[coordinates] = true
	for record in index.records_consumed_by(coordinates):
		if record.get("residency", MapChunkRuntimeIndex.RESIDENCY_STREAMED) == MapChunkRuntimeIndex.RESIDENCY_STREAMED:
			_ensure_loaded(record)


func unload_chunk(coordinates: Vector2i) -> void:
	if not _loaded_chunks.erase(coordinates):
		return
	for record in index.records_consumed_by(coordinates):
		if record.get("residency", MapChunkRuntimeIndex.RESIDENCY_STREAMED) != MapChunkRuntimeIndex.RESIDENCY_STREAMED:
			continue
		if not _has_loaded_consumer(record):
			_free_instance(record["id"])


func update_active_chunks(coordinates: Array[Vector2i]) -> void:
	var wanted: Dictionary = {}
	for chunk in coordinates:
		wanted[chunk] = true
	for loaded in loaded_chunk_coordinates():
		if not wanted.has(loaded):
			unload_chunk(loaded)
	var ordered: Array[Vector2i] = coordinates.duplicate()
	ordered.sort_custom(_chunk_less)
	for chunk in ordered:
		load_chunk(chunk)


func unload_all_chunks() -> void:
	for coordinates in loaded_chunk_coordinates():
		unload_chunk(coordinates)


func loaded_chunk_coordinates() -> Array[Vector2i]:
	var coordinates: Array[Vector2i] = []
	coordinates.assign(_loaded_chunks.keys())
	coordinates.sort_custom(_chunk_less)
	return coordinates


func loaded_instance(object_id: StringName) -> Node:
	var instance := _instances.get(String(object_id)) as Node
	return instance if instance != null and is_instance_valid(instance) else null


func resolve(object_id: StringName) -> Dictionary:
	if index == null:
		return {}
	var record := index.record(object_id)
	if record.is_empty():
		return {}
	record["loaded"] = loaded_instance(object_id) != null
	record["instance"] = loaded_instance(object_id)
	return record


func loaded_object_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for object_id in _instances:
		if loaded_instance(StringName(object_id)) != null:
			ids.append(StringName(object_id))
	ids.sort()
	return ids


func loaded_instance_count() -> int:
	return loaded_object_ids().size()


func duplicate_instance_ids() -> Array[StringName]:
	var counts: Dictionary = {}
	_collect_stable_ids(self, counts)
	var duplicates: Array[StringName] = []
	for object_id in counts:
		if int(counts[object_id]) > 1:
			duplicates.append(StringName(object_id))
	duplicates.sort()
	return duplicates


func _load_persistent_records() -> void:
	for record in index.persistent_records():
		_ensure_loaded(record)


func _ensure_loaded(record: Dictionary) -> Node:
	var object_id: StringName = record["id"]
	var existing := loaded_instance(object_id)
	if existing != null:
		return existing
	var instance := _factory.call(record) as Node
	if instance == null:
		return null
	instance.set_meta(&"stable_id", object_id)
	instance.set_meta(&"stable_handle", record["handle"])
	instance.set_meta(&"owner_chunk", record["owner_chunk"])
	instance.set_meta(&"consumer_chunks", record["consumer_chunks"])
	instance.set_meta(&"streaming_residency", record["residency"])
	_parent_for(record).add_child(instance)
	_instances[String(object_id)] = instance
	object_loaded.emit(record["handle"], instance)
	return instance


func _free_instance(object_id: StringName) -> void:
	var key := String(object_id)
	var instance := loaded_instance(object_id)
	if instance == null:
		_instances.erase(key)
		return
	var handle := index.stable_handle(object_id)
	_instances.erase(key)
	var parent := instance.get_parent()
	if parent != null:
		parent.remove_child(instance)
	instance.free()
	object_unloaded.emit(handle)


func _has_loaded_consumer(record: Dictionary) -> bool:
	for consumer in record.get("consumer_chunks", []):
		if _loaded_chunks.has(consumer):
			return true
	return false


func _parent_for(record: Dictionary) -> Node:
	var parent := _parents_by_kind.get(record["kind"]) as Node
	return parent if parent != null else self


func _collect_stable_ids(node: Node, counts: Dictionary) -> void:
	if node.has_meta(&"stable_id"):
		var key := String(node.get_meta(&"stable_id"))
		counts[key] = int(counts.get(key, 0)) + 1
	for child in node.get_children():
		_collect_stable_ids(child, counts)


func _chunk_less(left: Vector2i, right: Vector2i) -> bool:
	return left.y < right.y or (left.y == right.y and left.x < right.x)
