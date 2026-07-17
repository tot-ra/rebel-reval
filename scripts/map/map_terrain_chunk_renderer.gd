class_name MapTerrainChunkRenderer
extends Node2D

## Draws one disposable terrain chunk while preserving global-cell visual hashes.

var grid: MapTerrainGrid
var chunk_coordinates: Vector2i = Vector2i.ZERO
var visual_target: StringName
var time_of_day: StringName
var debug_bounds_enabled := false


func configure(
	terrain_grid: MapTerrainGrid,
	coordinates: Vector2i,
	target: StringName,
	day_phase: StringName,
	show_debug_bounds: bool
) -> void:
	grid = terrain_grid
	chunk_coordinates = coordinates
	visual_target = target
	time_of_day = day_phase
	debug_bounds_enabled = show_debug_bounds
	var bounds := grid.chunk_bounds(chunk_coordinates)
	position = Vector2(bounds.position * grid.cell_size)
	set_meta(&"chunk_coordinates", chunk_coordinates)
	set_meta(&"chunk_bounds_cells", bounds)
	set_meta(&"chunk_cache_key", grid.chunk_cache_key(chunk_coordinates))
	queue_redraw()


func set_debug_bounds_enabled(enabled: bool) -> void:
	debug_bounds_enabled = enabled
	queue_redraw()


func _draw() -> void:
	if grid == null:
		return
	var bounds := grid.chunk_bounds(chunk_coordinates)
	var cell_size := float(grid.cell_size)
	for global_y in range(bounds.position.y, bounds.end.y):
		for global_x in range(bounds.position.x, bounds.end.x):
			var global_cell := Vector2i(global_x, global_y)
			var local_cell := global_cell - bounds.position
			var origin := Vector2(local_cell) * cell_size
			_draw_cell(origin, cell_size, grid.get_terrain(global_cell), global_cell)
	if debug_bounds_enabled:
		var local_size := Vector2(bounds.size * grid.cell_size)
		draw_rect(Rect2(Vector2.ZERO, local_size), Color(1.0, 0.25, 0.1, 0.9), false, 2.0)


func _draw_cell(origin: Vector2, cell_size: float, terrain_id: StringName, global_cell: Vector2i) -> void:
	var base := TerrainPalette.base_color(terrain_id, visual_target, time_of_day)
	draw_rect(Rect2(origin, Vector2(cell_size, cell_size)), base)

	var patch_size := MapVisualStyle.terrain_patch_size(visual_target)
	var patches_x := int(cell_size / patch_size)
	var patches_y := int(cell_size / patch_size)
	for py in patches_y:
		for px in patches_x:
			var local := Vector2(float(px), float(py)) * patch_size
			var color := TerrainPalette.pattern_color(
				terrain_id, global_cell, local, grid.seed, visual_target, time_of_day
			)
			draw_rect(Rect2(origin + local, Vector2(patch_size, patch_size)), color)

	_draw_style_marks(origin, cell_size, terrain_id, global_cell)


func _draw_style_marks(origin: Vector2, cell_size: float, terrain_id: StringName, global_cell: Vector2i) -> void:
	var hash := TerrainPalette.cell_hash(global_cell, grid.seed, terrain_id)
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
