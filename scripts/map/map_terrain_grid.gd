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
var variant_to_index: Dictionary = {}
var index_to_variant: Array[StringName] = [&""]
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


func get_style_variant(cell: Vector2i) -> StringName:
	var index := _variant_index_at(cell)
	if index <= 0 or index >= index_to_variant.size():
		return &""
	return index_to_variant[index]


func set_style_variant(cell: Vector2i, variant: StringName) -> void:
	if not _is_inside(cell):
		return
	var index := _variant_index(variant)
	var chunk := get_chunk(chunk_for_cell(cell))
	if chunk != null:
		chunk.set_variant_index(cell, index)


func get_movement_speed_multiplier(cell: Vector2i) -> float:
	var hundredths := _speed_hundredths_at(cell)
	if hundredths <= 0:
		return 1.0
	return float(hundredths) / 100.0


func set_movement_speed_multiplier(cell: Vector2i, multiplier: float) -> void:
	if not _is_inside(cell):
		return
	var clamped := TerrainVegetation.clamp_speed_multiplier(multiplier)
	var hundredths := 0
	if clamped < 0.999:
		hundredths = int(round(clamped * 100.0))
	var chunk := get_chunk(chunk_for_cell(cell))
	if chunk != null:
		chunk.set_speed_hundredths(cell, hundredths)


func apply_vegetation_overlay(cell: Vector2i, variant: StringName, speed_multiplier: float) -> void:
	if not variant.is_empty():
		set_style_variant(cell, variant)
	if speed_multiplier < 0.999:
		set_movement_speed_multiplier(cell, speed_multiplier)


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


func _variant_index(variant: StringName) -> int:
	if variant.is_empty():
		return 0
	if variant_to_index.has(variant):
		return int(variant_to_index[variant])
	var next := index_to_variant.size()
	variant_to_index[variant] = next
	index_to_variant.append(variant)
	return next


func _variant_index_at(cell: Vector2i) -> int:
	if not _is_inside(cell):
		return 0
	var chunk := get_chunk(chunk_for_cell(cell))
	if chunk != null:
		return chunk.get_variant_index(cell)
	return 0


func _speed_hundredths_at(cell: Vector2i) -> int:
	if not _is_inside(cell):
		return 0
	var chunk := get_chunk(chunk_for_cell(cell))
	if chunk != null:
		return chunk.get_speed_hundredths(cell)
	return 0


func _cell_index(cell: Vector2i) -> int:
	return cell.y * size_cells.x + cell.x


func _is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size_cells.x and cell.y < size_cells.y
