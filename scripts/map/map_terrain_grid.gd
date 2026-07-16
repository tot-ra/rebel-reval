class_name MapTerrainGrid
extends RefCounted

## Built terrain grid with one terrain ID per cell.

var cell_size: int = MapTypes.DEFAULT_CELL_SIZE
var size_cells: Vector2i = Vector2i.ZERO
var seed: int = MapTypes.DEFAULT_SEED
var cells: PackedByteArray = PackedByteArray()
var terrain_to_index: Dictionary = {}
var index_to_terrain: Array[StringName] = []


func get_terrain(cell: Vector2i) -> StringName:
	if not _is_inside(cell):
		return &""
	var index := int(cells[_cell_index(cell)])
	if index < 0 or index >= index_to_terrain.size():
		return &""
	return index_to_terrain[index]


func set_terrain(cell: Vector2i, terrain_id: StringName) -> void:
	if not _is_inside(cell):
		return
	cells[_cell_index(cell)] = _terrain_index(terrain_id)


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
