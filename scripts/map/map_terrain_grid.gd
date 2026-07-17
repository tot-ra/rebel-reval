class_name MapTerrainGrid
extends RefCounted

## Built terrain grid with global cell access and deterministic fixed-size chunks.

const DEFAULT_CHUNK_SIZE_CELLS := 32

var cell_size: int = MapTypes.DEFAULT_CELL_SIZE
var size_cells: Vector2i = Vector2i.ZERO
var seed: int = MapTypes.DEFAULT_SEED
## Retained as a compatibility snapshot for consumers that inspect monolithic cell count.
var cells: PackedByteArray = PackedByteArray()
var terrain_to_index: Dictionary = {}
var index_to_terrain: Array[StringName] = []
var chunk_size_cells: int = DEFAULT_CHUNK_SIZE_CELLS
var chunks: Dictionary = {}


func initialize_chunks(size: Vector2i, terrain_cell_size: int, terrain_seed: int, size_per_chunk: int = DEFAULT_CHUNK_SIZE_CELLS) -> void:
	assert(size_per_chunk > 0)
	size_cells = size
	cell_size = terrain_cell_size
	seed = terrain_seed
	chunk_size_cells = size_per_chunk
	cells.resize(size_cells.x * size_cells.y)
	chunks.clear()
	for chunk_y in chunk_count().y:
		for chunk_x in chunk_count().x:
			var coordinates := Vector2i(chunk_x, chunk_y)
			var chunk := MapTerrainChunk.new()
			chunk.configure(coordinates, chunk_bounds(coordinates))
			chunks[coordinates] = chunk


func get_terrain(cell: Vector2i) -> StringName:
	if not _is_inside(cell):
		return &""
	var index := -1
	var chunk := get_chunk(chunk_for_cell(cell))
	if chunk != null:
		index = chunk.get_terrain_index(cell)
	elif not cells.is_empty():
		index = int(cells[_cell_index(cell)])
	if index < 0 or index >= index_to_terrain.size():
		return &""
	return index_to_terrain[index]


func set_terrain(cell: Vector2i, terrain_id: StringName) -> void:
	if not _is_inside(cell):
		return
	var index := _terrain_index(terrain_id)
	cells[_cell_index(cell)] = index
	var chunk := get_chunk(chunk_for_cell(cell))
	if chunk != null:
		chunk.set_terrain_index(cell, index)


func chunk_count() -> Vector2i:
	if chunk_size_cells <= 0:
		return Vector2i.ZERO
	return Vector2i(
		ceili(float(size_cells.x) / float(chunk_size_cells)),
		ceili(float(size_cells.y) / float(chunk_size_cells))
	)


func chunk_for_cell(global_cell: Vector2i) -> Vector2i:
	assert(chunk_size_cells > 0)
	return Vector2i(
		floori(float(global_cell.x) / float(chunk_size_cells)),
		floori(float(global_cell.y) / float(chunk_size_cells))
	)


func chunk_bounds(coordinates: Vector2i) -> Rect2i:
	var origin := coordinates * chunk_size_cells
	if origin.x < 0 or origin.y < 0 or origin.x >= size_cells.x or origin.y >= size_cells.y:
		return Rect2i(origin, Vector2i.ZERO)
	return Rect2i(origin, Vector2i(
		mini(chunk_size_cells, size_cells.x - origin.x),
		mini(chunk_size_cells, size_cells.y - origin.y)
	))


func chunk_world_bounds(coordinates: Vector2i) -> Rect2:
	var bounds := chunk_bounds(coordinates)
	return Rect2(Vector2(bounds.position * cell_size), Vector2(bounds.size * cell_size))


func get_chunk(coordinates: Vector2i) -> MapTerrainChunk:
	return chunks.get(coordinates) as MapTerrainChunk


func chunk_coordinates() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	result.assign(chunks.keys())
	result.sort_custom(func(left: Vector2i, right: Vector2i) -> bool:
		return left.y < right.y or (left.y == right.y and left.x < right.x)
	)
	return result


func chunk_cache_key(coordinates: Vector2i) -> String:
	var chunk := get_chunk(coordinates)
	if chunk == null:
		return ""
	# The key is content-derived and independent of runtime load order or node identity.
	return "terrain-v1:%d:%d:%d:%d:%d:%d:%s:%s" % [
		seed,
		chunk_size_cells,
		coordinates.x,
		coordinates.y,
		chunk.bounds_cells.size.x,
		chunk.bounds_cells.size.y,
		"|".join(PackedStringArray(index_to_terrain)),
		chunk.cells.hex_encode(),
	]


func fingerprint() -> String:
	return "%d:%s" % [seed, cells.hex_encode()]


func used_terrain_ids() -> Array[StringName]:
	var seen: Dictionary = {}
	for index in cells.size():
		var terrain := index_to_terrain[int(cells[index])]
		seen[terrain] = true
	var result: Array[StringName] = []
	for terrain in MapTypes.ALL_TERRAINS:
		if seen.has(terrain):
			result.append(terrain)
	return result


func _terrain_index(terrain_id: StringName) -> int:
	if terrain_to_index.has(terrain_id):
		return int(terrain_to_index[terrain_id])
	var next := terrain_to_index.size()
	terrain_to_index[terrain_id] = next
	index_to_terrain.append(terrain_id)
	return next


func _cell_index(cell: Vector2i) -> int:
	return cell.y * size_cells.x + cell.x


func _is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size_cells.x and cell.y < size_cells.y
