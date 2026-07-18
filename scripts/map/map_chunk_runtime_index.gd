class_name MapChunkRuntimeIndex
extends RefCounted

## Immutable, runtime-neutral spatial index over canonical MapDefinition data.
## Stable IDs and global transforms remain authoritative; chunks only describe
## disposable ownership and residency hints.

const RESIDENCY_STREAMED := &"streamed"
const RESIDENCY_PERSISTENT := &"persistent"

var location_id: StringName
var map_fingerprint: String
var cell_size: int
var chunk_size_cells: int
var _records: Dictionary = {}
var _owners: Dictionary = {}
var _consumers: Dictionary = {}
var _diagnostics: Array[String] = []


static func build(definition: MapDefinition, chunk_size: int) -> MapChunkRuntimeIndex:
	assert(definition != null)
	assert(chunk_size > 0)
	var index := MapChunkRuntimeIndex.new()
	index.location_id = definition.location
	index.map_fingerprint = definition.fingerprint
	index.cell_size = definition.cell_size
	index.chunk_size_cells = chunk_size
	index._index_definition(definition)
	return index


func has_object(object_id: StringName) -> bool:
	return _records.has(String(object_id))


func record(object_id: StringName) -> Dictionary:
	return (_records.get(String(object_id), {}) as Dictionary).duplicate(true)


func owner_for(object_id: StringName) -> Vector2i:
	return _owners.get(String(object_id), Vector2i.ZERO)


func stable_handle(object_id: StringName) -> Dictionary:
	return {"location_id": String(location_id), "object_id": String(object_id)}


func diagnostics() -> Array[String]:
	return _diagnostics.duplicate()


func object_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for object_id in _records:
		ids.append(StringName(object_id))
	ids.sort()
	return ids


func records_owned_by(chunk: Vector2i) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for object_id in object_ids():
		if _owners[String(object_id)] == chunk:
			records.append(record(object_id))
	return records


func records_consumed_by(chunk: Vector2i) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var ids: Array = (_consumers.get(chunk, []) as Array).duplicate()
	ids.sort()
	for object_id in ids:
		records.append(record(StringName(object_id)))
	return records


func persistent_records() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for object_id in object_ids():
		var indexed := record(object_id)
		if indexed.get("residency", RESIDENCY_STREAMED) == RESIDENCY_PERSISTENT:
			records.append(indexed)
	return records


func chunk_for_global_cell(global_cell: Vector2i) -> Vector2i:
	return Vector2i(
		floori(float(global_cell.x) / float(chunk_size_cells)),
		floori(float(global_cell.y) / float(chunk_size_cells))
	)


func _index_definition(definition: MapDefinition) -> void:
	for building in definition.buildings:
		_add_area_record(&"building", building, building.get("footprint", Rect2()))
	for prop in definition.props:
		_add_point_record(&"prop", prop, prop.get("position", Vector2.ZERO))
	# Transitions and anchors drive gameplay and must remain available independent
	# of decorative residency. Their 3D view decorations can still be streamed by
	# a renderer without changing these authoritative records.
	for transition in definition.transitions:
		_add_area_record(&"transition", transition, transition.get("rect", Rect2()), RESIDENCY_PERSISTENT)
	for anchor in definition.interaction_anchors:
		_add_point_record(&"anchor", anchor, anchor.get("position", Vector2.ZERO), RESIDENCY_PERSISTENT)
	for landmark in definition.view_landmarks:
		_add_area_record(&"landmark", landmark, landmark.get("rect", Rect2()))
	for sign_index in definition.direction_signs.size():
		var sign: Dictionary = definition.direction_signs[sign_index].duplicate(true)
		if String(sign.get("id", "")).is_empty():
			sign["id"] = StringName("visual.direction_sign.%d" % sign_index)
		_add_point_record(&"direction_sign", sign, sign.get("position", Vector2.ZERO))


func _add_point_record(
	kind: StringName,
	source: Dictionary,
	position: Vector2,
	default_residency: StringName = RESIDENCY_STREAMED
) -> void:
	var object_id := StringName(String(source.get("id", "")))
	if object_id.is_empty():
		return
	var owner := chunk_for_global_cell(Vector2i(
		floori(position.x / float(cell_size)),
		floori(position.y / float(cell_size))
	))
	_add_record(kind, object_id, owner, [owner], source, Rect2(position, Vector2.ZERO), _residency(source, default_residency))


func _add_area_record(
	kind: StringName,
	source: Dictionary,
	bounds: Rect2,
	default_residency: StringName = RESIDENCY_STREAMED
) -> void:
	var object_id := StringName(String(source.get("id", "")))
	if object_id.is_empty():
		return
	var consumers := chunks_intersecting(bounds)
	if consumers.is_empty():
		consumers.append(chunk_for_global_cell(Vector2i(
			floori(bounds.position.x / float(cell_size)),
			floori(bounds.position.y / float(cell_size))
		)))
	consumers.sort_custom(_chunk_less)
	_add_record(kind, object_id, consumers[0], consumers, source, bounds, _residency(source, default_residency))


func _add_record(
	kind: StringName,
	object_id: StringName,
	owner: Vector2i,
	consumer_chunks: Array[Vector2i],
	source: Dictionary,
	bounds: Rect2,
	residency: StringName
) -> void:
	var key := String(object_id)
	if _records.has(key):
		_diagnostics.append("duplicate compiled stable id: %s" % key)
		return
	var consumers := consumer_chunks.duplicate()
	consumers.sort_custom(_chunk_less)
	_records[key] = {
		"id": object_id,
		"kind": kind,
		"handle": stable_handle(object_id),
		"owner_chunk": owner,
		"consumer_chunks": consumers,
		"bounds": bounds,
		"source": source.duplicate(true),
		"residency": residency,
	}
	_owners[key] = owner
	for chunk in consumers:
		if not _consumers.has(chunk):
			_consumers[chunk] = []
		(_consumers[chunk] as Array).append(key)


func chunks_intersecting(bounds: Rect2) -> Array[Vector2i]:
	var chunks: Array[Vector2i] = []
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return chunks
	var epsilon := minf(float(cell_size) * 0.0001, 0.001)
	var first_cell := Vector2i(
		floori(bounds.position.x / float(cell_size)),
		floori(bounds.position.y / float(cell_size))
	)
	var last_position := bounds.end - Vector2(epsilon, epsilon)
	var last_cell := Vector2i(
		floori(last_position.x / float(cell_size)),
		floori(last_position.y / float(cell_size))
	)
	var first := chunk_for_global_cell(first_cell)
	var last := chunk_for_global_cell(last_cell)
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			chunks.append(Vector2i(x, y))
	return chunks


func _residency(source: Dictionary, fallback: StringName) -> StringName:
	if bool(source.get("persistent", false)) or bool(source.get("gameplay_critical", false)):
		return RESIDENCY_PERSISTENT
	var declared := StringName(String(source.get("residency", source.get("streaming_policy", fallback))))
	return RESIDENCY_PERSISTENT if declared == RESIDENCY_PERSISTENT else RESIDENCY_STREAMED


func _chunk_less(left: Vector2i, right: Vector2i) -> bool:
	return left.y < right.y or (left.y == right.y and left.x < right.x)
