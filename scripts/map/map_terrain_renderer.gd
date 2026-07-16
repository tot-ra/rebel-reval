class_name MapTerrainRenderer
extends Node2D

## Draws one immutable terrain grid through a selectable P0-036 visual profile.

var grid: MapTerrainGrid
var visual_target: StringName
var time_of_day: StringName


func _init(
	terrain_grid: MapTerrainGrid,
	target: StringName = MapVisualStyle.TARGET_CLEAN_PAINTED,
	day_phase: StringName = MapVisualStyle.TIME_DAY
) -> void:
	grid = terrain_grid
	visual_target = target
	time_of_day = day_phase
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
	var base := TerrainPalette.base_color(terrain_id, visual_target, time_of_day)
	draw_rect(Rect2(origin, Vector2(cell_size, cell_size)), base)

	var patch_size := MapVisualStyle.terrain_patch_size(visual_target)
	var patches_x := int(cell_size / patch_size)
	var patches_y := int(cell_size / patch_size)
	for py in patches_y:
		for px in patches_x:
			var local := Vector2(float(px), float(py)) * patch_size
			var color := TerrainPalette.pattern_color(
				terrain_id, cell, local, grid.seed, visual_target, time_of_day
			)
			draw_rect(Rect2(origin + local, Vector2(patch_size, patch_size)), color)

	_draw_style_marks(origin, cell_size, terrain_id, cell)


func _draw_style_marks(origin: Vector2, cell_size: float, terrain_id: StringName, cell: Vector2i) -> void:
	var hash := TerrainPalette.cell_hash(cell, grid.seed, terrain_id)
	var ink := MapVisualStyle.role_color(&"ink", visual_target, time_of_day)
	match visual_target:
		MapVisualStyle.TARGET_PIXEL:
			if hash % 3 == 0:
				draw_rect(Rect2(origin + Vector2(float(hash % 23), float((hash >> 5) % 23)), Vector2(3, 3)), ink, true)
		MapVisualStyle.TARGET_WOODCUT:
			# Sparse directional hatching provides a printmaking cue without changing terrain boundaries.
			var line_color := Color(ink, 0.23)
			for index in 3:
				var y := 5.0 + float((hash + index * 9) % 23)
				draw_line(origin + Vector2(3.0, y), origin + Vector2(cell_size - 3.0, y - 6.0), line_color, 1.0)
		MapVisualStyle.TARGET_CLEAN_PAINTED:
			if hash % 4 == 0:
				var highlight := TerrainPalette.base_color(terrain_id, visual_target, time_of_day).lightened(0.08)
				draw_circle(origin + Vector2(float(7 + hash % 18), float(7 + (hash >> 4) % 18)), 2.5, Color(highlight, 0.45))
