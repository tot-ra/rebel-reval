class_name MinimapTextureBuilder
extends RefCounted

## Builds a one-pixel-per-cell minimap image from compiled map data.


static func create_image(definition: MapDefinition) -> Image:
	return Image.create(
		definition.size_cells.x, definition.size_cells.y, false, Image.FORMAT_RGBA8
	)


## R-1078: paint [y_start, y_end) so a 152x128 district can drain under 4 ms/tick.
static func fill_rows(
	image: Image,
	definition: MapDefinition,
	grid: MapTerrainGrid,
	blocked: Dictionary,
	y_start: int,
	y_end: int
) -> void:
	var width := definition.size_cells.x
	var last_row := mini(y_end, definition.size_cells.y)
	for y in range(maxi(y_start, 0), last_row):
		for x in range(width):
			var cell := Vector2i(x, y)
			image.set_pixel(x, y, MinimapPalette.color_for_cell(definition, grid, cell, blocked))


static func finish_image(definition: MapDefinition, image: Image) -> void:
	_paint_transitions(definition, image)


static func build_image(definition: MapDefinition, grid: MapTerrainGrid) -> Image:
	var image := create_image(definition)
	var blocked := MapVerification.blocked_cells(definition)
	fill_rows(image, definition, grid, blocked, 0, definition.size_cells.y)
	finish_image(definition, image)
	return image


static func world_to_normalized(definition: MapDefinition, world_pos: Vector2) -> Vector2:
	var world_size := definition.world_size()
	if world_size.x <= 0.0 or world_size.y <= 0.0:
		return Vector2.ZERO
	return Vector2(
		clampf(world_pos.x / world_size.x, 0.0, 1.0), clampf(world_pos.y / world_size.y, 0.0, 1.0)
	)


static func _paint_transitions(definition: MapDefinition, image: Image) -> void:
	var transition_color := MinimapPalette.transition_color()
	for transition in definition.transitions:
		if String(transition.get("destination_scene_id", "")).is_empty():
			continue
		var rect: Rect2 = transition["rect"]
		var start_cell := Vector2i(
			int(floor(rect.position.x / definition.cell_size)),
			int(floor(rect.position.y / definition.cell_size))
		)
		var end_cell := Vector2i(
			int(ceil(rect.end.x / definition.cell_size)),
			int(ceil(rect.end.y / definition.cell_size))
		)
		for y in range(start_cell.y, end_cell.y):
			for x in range(start_cell.x, end_cell.x):
				if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
					continue
				image.set_pixel(x, y, transition_color)
