class_name MapTerrainChunk
extends RefCounted

## Disposable terrain data for one half-open chunk of global map cells.

var coordinates: Vector2i = Vector2i.ZERO
var bounds_cells: Rect2i = Rect2i()
var cells: PackedByteArray = PackedByteArray()


func configure(chunk_coordinates: Vector2i, global_bounds: Rect2i) -> void:
	coordinates = chunk_coordinates
	bounds_cells = global_bounds
	cells.resize(global_bounds.size.x * global_bounds.size.y)


func contains_global_cell(global_cell: Vector2i) -> bool:
	return bounds_cells.has_point(global_cell)


func get_terrain_index(global_cell: Vector2i) -> int:
	if not contains_global_cell(global_cell):
		return -1
	return int(cells[_cell_index(global_cell)])


func set_terrain_index(global_cell: Vector2i, terrain_index: int) -> void:
	if not contains_global_cell(global_cell):
		return
	cells[_cell_index(global_cell)] = terrain_index


func _cell_index(global_cell: Vector2i) -> int:
	var local := global_cell - bounds_cells.position
	return local.y * bounds_cells.size.x + local.x
