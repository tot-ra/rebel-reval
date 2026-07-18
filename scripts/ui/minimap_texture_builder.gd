class_name MinimapTextureBuilder
extends RefCounted

## Builds a one-pixel-per-cell minimap image from compiled map data.


static func build_image(definition: MapDefinition, grid: MapTerrainGrid) -> Image:
	var image := Image.create(
		definition.size_cells.x,
		definition.size_cells.y,
		false,
		Image.FORMAT_RGBA8
	)
	var blocked := MapVerification.blocked_cells(definition)
	for y in range(definition.size_cells.y):
		for x in range(definition.size_cells.x):
			var cell := Vector2i(x, y)
			image.set_pixel(
				x,
				y,
				MinimapPalette.color_for_cell(definition, grid, cell, blocked)
			)
	_paint_transitions(definition, image)
	return image


static func world_to_normalized(definition: MapDefinition, world_pos: Vector2) -> Vector2:
	var world_size := definition.world_size()
	if world_size.x <= 0.0 or world_size.y <= 0.0:
		return Vector2.ZERO
	return Vector2(
		clampf(world_pos.x / world_size.x, 0.0, 1.0),
		clampf(world_pos.y / world_size.y, 0.0, 1.0)
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
