class_name LargeMapChunkPrototype
extends RefCounted

## Non-production executable model for ADR 0010. It intentionally owns no scene
## lifecycle: the benchmark can validate coordinate and routing rules before the
## production runtime adopts streaming.

const CONFIG_PATH := "res://tools/benchmarks/large_map_benchmark_config.json"


static func load_config(path: String = CONFIG_PATH) -> Dictionary:
	var source := FileAccess.get_file_as_string(path)
	if source.is_empty():
		push_error("Large-map benchmark config is missing: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(source)
	if not parsed is Dictionary:
		push_error("Large-map benchmark config must contain a JSON object: %s" % path)
		return {}
	return parsed


static func chunk_for_global_cell(global_cell: Vector2i, chunk_size_cells: int) -> Vector2i:
	assert(chunk_size_cells > 0)
	return Vector2i(
		_floor_div(global_cell.x, chunk_size_cells),
		_floor_div(global_cell.y, chunk_size_cells)
	)


static func chunk_origin_cell(chunk: Vector2i, chunk_size_cells: int) -> Vector2i:
	assert(chunk_size_cells > 0)
	return chunk * chunk_size_cells


static func local_cell(global_cell: Vector2i, chunk_size_cells: int) -> Vector2i:
	return global_cell - chunk_origin_cell(chunk_for_global_cell(global_cell, chunk_size_cells), chunk_size_cells)


static func owner_for_point(global_position: Vector2, cell_size: int, chunk_size_cells: int) -> Vector2i:
	assert(cell_size > 0)
	return chunk_for_global_cell(
		Vector2i(floori(global_position.x / float(cell_size)), floori(global_position.y / float(cell_size))),
		chunk_size_cells
	)


static func owner_for_rect(global_rect: Rect2, stable_id: StringName, cell_size: int, chunk_size_cells: int) -> Vector2i:
	assert(global_rect.size.x >= 0.0 and global_rect.size.y >= 0.0)
	if global_rect.size == Vector2.ZERO:
		return owner_for_point(global_rect.position, cell_size, chunk_size_cells)

	# Half-open extents make a rect ending exactly on a border belong only to the
	# chunks containing its area. Multi-chunk objects use lexicographic minimum,
	# while stable_id remains the deterministic registry key and tie-break input.
	var epsilon := minf(float(cell_size) * 0.0001, 0.001)
	var first := owner_for_point(global_rect.position, cell_size, chunk_size_cells)
	var last := owner_for_point(global_rect.end - Vector2(epsilon, epsilon), cell_size, chunk_size_cells)
	var candidates: Array[Vector2i] = []
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			candidates.append(Vector2i(x, y))
	return choose_owner(candidates, stable_id)


static func choose_owner(candidates: Array[Vector2i], stable_id: StringName) -> Vector2i:
	assert(not candidates.is_empty())
	assert(not stable_id.is_empty())
	var unique: Dictionary = {}
	for candidate in candidates:
		unique[candidate] = true
	var ordered: Array[Vector2i] = []
	ordered.assign(unique.keys())
	ordered.sort_custom(func(left: Vector2i, right: Vector2i) -> bool:
		return left.y < right.y or (left.y == right.y and left.x < right.x)
	)
	return ordered[0]


static func chunks_in_radius(center: Vector2i, radius: int) -> Array[Vector2i]:
	assert(radius >= 0)
	var chunks: Array[Vector2i] = []
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			chunks.append(Vector2i(x, y))
	return chunks


static func route_chunks(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	# Deterministic Manhattan routing is only a coarse world route. Chunk-local
	# NavigationServer paths remain authoritative for movement.
	var route: Array[Vector2i] = [start]
	var cursor := start
	while cursor.x != goal.x:
		cursor.x += 1 if goal.x > cursor.x else -1
		route.append(cursor)
	while cursor.y != goal.y:
		cursor.y += 1 if goal.y > cursor.y else -1
		route.append(cursor)
	return route


static func navigation_bake_rect(chunk: Vector2i, chunk_size_cells: int, border_cells: int) -> Rect2i:
	assert(border_cells >= 0)
	return Rect2i(
		chunk_origin_cell(chunk, chunk_size_cells) - Vector2i.ONE * border_cells,
		Vector2i.ONE * (chunk_size_cells + border_cells * 2)
	)


static func visual_lod(chunk: Vector2i, focus: Vector2i, config: Dictionary) -> int:
	var distance := maxi(absi(chunk.x - focus.x), absi(chunk.y - focus.y))
	var lod := config.get("visual_lod", {}) as Dictionary
	if distance <= int(lod.get("lod0_max_distance_chunks", 1)):
		return 0
	if distance <= int(lod.get("lod1_max_distance_chunks", 2)):
		return 1
	return 2


static func _floor_div(value: int, divisor: int) -> int:
	return floori(float(value) / float(divisor))


static func stable_handle(location_id: StringName, object_id: StringName) -> Dictionary:
	assert(not location_id.is_empty())
	assert(not object_id.is_empty())
	return {"location_id": String(location_id), "object_id": String(object_id)}


static func persistent_position(global_position: Vector2, cell_size: int) -> Dictionary:
	assert(cell_size > 0)
	var global_cell := Vector2i(
		floori(global_position.x / float(cell_size)),
		floori(global_position.y / float(cell_size))
	)
	var sub_cell := global_position / float(cell_size) - Vector2(global_cell)
	return {
		"global_cell": [global_cell.x, global_cell.y],
		"sub_cell": [sub_cell.x, sub_cell.y],
	}


static func restore_persistent_position(payload: Dictionary, cell_size: int) -> Vector2:
	assert(cell_size > 0)
	var global_cell: Array = payload.get("global_cell", [0, 0])
	var sub_cell: Array = payload.get("sub_cell", [0.0, 0.0])
	return (Vector2(float(global_cell[0]), float(global_cell[1])) + Vector2(float(sub_cell[0]), float(sub_cell[1]))) * float(cell_size)
