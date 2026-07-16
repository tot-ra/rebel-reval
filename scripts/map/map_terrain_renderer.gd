class_name MapTerrainRenderer
extends Node2D

## Draws a full terrain grid with deterministic procedural accents.

var grid: MapTerrainGrid


func _init(terrain_grid: MapTerrainGrid) -> void:
	grid = terrain_grid
	z_index = 0


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	if grid == null:
		return

	var cell_size := float(grid.cell_size)
	for y in grid.size_cells.y:
		for x in grid.size_cells.x:
			var cell := Vector2i(x, y)
			var terrain_id := grid.get_terrain(cell)
			var origin := Vector2(float(x), float(y)) * cell_size
			_draw_cell(origin, cell_size, terrain_id, cell)


func _draw_cell(origin: Vector2, cell_size: float, terrain_id: StringName, cell: Vector2i) -> void:
	var base := TerrainPalette.base_color(terrain_id)
	draw_rect(Rect2(origin, Vector2(cell_size, cell_size)), base)

	var patch_size := 4.0
	var patches_x := int(cell_size / patch_size)
	var patches_y := int(cell_size / patch_size)
	for py in patches_y:
		for px in patches_x:
			var local := Vector2(float(px), float(py)) * patch_size
			var color := TerrainPalette.pattern_color(terrain_id, cell, local, grid.seed)
			draw_rect(Rect2(origin + local, Vector2(patch_size, patch_size)), color)

	_draw_organic_marks(origin, cell_size, terrain_id, cell)


func _draw_organic_marks(origin: Vector2, cell_size: float, terrain_id: StringName, cell: Vector2i) -> void:
	if terrain_id == MapTypes.TERRAIN_WATER:
		return

	var mark_count := 2 + TerrainPalette.cell_hash(cell, grid.seed, terrain_id) % 3
	for index in mark_count:
		var hash := TerrainPalette.cell_hash(cell + Vector2i(index, index * 3), grid.seed, terrain_id)
		var mark_origin := origin + Vector2(
			float(hash % int(cell_size - 3.0)),
			float((hash >> 4) % int(cell_size - 3.0))
		)
		var mark_size := Vector2(2.0 + float(hash % 2), 2.0 + float((hash >> 2) % 2))
		var mark_color := TerrainPalette.pattern_color(terrain_id, cell, mark_origin - origin, grid.seed)
		match terrain_id:
			MapTypes.TERRAIN_SAND, MapTypes.TERRAIN_HAY:
				mark_color = mark_color.lightened(0.08 if hash % 2 == 0 else -0.06)
			MapTypes.TERRAIN_STONE, MapTypes.TERRAIN_COBBLESTONE:
				mark_color = mark_color.darkened(0.06 if hash % 2 == 0 else -0.04)
			_:
				mark_color = mark_color.darkened(0.04)
		draw_rect(Rect2(mark_origin, mark_size), mark_color)
