class_name MapBuilder
extends RefCounted

## Compiles MapDefinition terrain into deterministic fixed-size runtime chunks.

const DEFAULT_CHUNK_SIZE_CELLS := MapTerrainGrid.DEFAULT_CHUNK_SIZE_CELLS


static func build(definition: MapDefinition, chunk_size_cells: int = DEFAULT_CHUNK_SIZE_CELLS) -> MapTerrainGrid:
	var errors := definition.validate()
	if not errors.is_empty():
		push_error("Invalid map definition %s: %s" % [String(definition.map_id), ", ".join(errors)])
		return MapTerrainGrid.new()
	if chunk_size_cells <= 0:
		push_error("Terrain chunk size must be positive")
		return MapTerrainGrid.new()

	var grid := MapTerrainGrid.new()
	grid.initialize_chunks(definition.size_cells, definition.cell_size, definition.seed, chunk_size_cells)
	_fill_chunks(grid, definition.base_terrain)

	# Zone order is canonical MapDefinition semantics. Clip every overlay to each
	# affected chunk, but never reorder overlays by chunk or terrain.
	for zone in definition.zones:
		_apply_zone_to_chunks(grid, zone)

	return grid


## Test-only compatibility compiler used to prove chunked terrain parity.
static func build_legacy(definition: MapDefinition) -> MapTerrainGrid:
	var errors := definition.validate()
	if not errors.is_empty():
		push_error("Invalid map definition %s: %s" % [String(definition.map_id), ", ".join(errors)])
		return MapTerrainGrid.new()

	var grid := MapTerrainGrid.new()
	grid.cell_size = definition.cell_size
	grid.size_cells = definition.size_cells
	grid.seed = definition.seed
	grid.cells.resize(definition.size_cells.x * definition.size_cells.y)
	for y in definition.size_cells.y:
		for x in definition.size_cells.x:
			grid.set_terrain(Vector2i(x, y), definition.base_terrain)
	for zone in definition.zones:
		_apply_zone(grid, zone)
	return grid


static func validate(definition: MapDefinition) -> Array[String]:
	return definition.validate()


static func collect_building_bodies(root: Node) -> Array[StaticBody2D]:
	var bodies: Array[StaticBody2D] = []
	for child in root.get_children():
		if child is StaticBody2D and child.is_in_group("map_building_collision"):
			bodies.append(child)
		bodies.append_array(collect_building_bodies(child))
	return bodies


static func _fill_chunks(grid: MapTerrainGrid, terrain: StringName) -> void:
	for coordinates in grid.chunk_coordinates():
		var bounds := grid.chunk_bounds(coordinates)
		for y in range(bounds.position.y, bounds.end.y):
			for x in range(bounds.position.x, bounds.end.x):
				grid.set_terrain(Vector2i(x, y), terrain)


static func _apply_zone_to_chunks(grid: MapTerrainGrid, zone: Dictionary) -> void:
	var zone_rect: Rect2i = zone["rect"]
	var terrain: StringName = zone["terrain"]
	var style_variant: StringName = zone.get("style_variant", &"")
	var speed_multiplier := TerrainVegetation.resolved_zone_speed(
		style_variant,
		zone.get("movement_speed_multiplier", null)
	)
	for coordinates in grid.chunk_coordinates():
		var clipped := zone_rect.intersection(grid.chunk_bounds(coordinates))
		if not clipped.has_area():
			continue
		for y in range(clipped.position.y, clipped.end.y):
			for x in range(clipped.position.x, clipped.end.x):
				var cell := Vector2i(x, y)
				grid.set_terrain(cell, terrain)
				if not style_variant.is_empty() or speed_multiplier < 0.999:
					grid.apply_vegetation_overlay(cell, style_variant, speed_multiplier)


static func _apply_zone(grid: MapTerrainGrid, zone: Dictionary) -> void:
	var rect: Rect2i = zone["rect"]
	var terrain: StringName = zone["terrain"]
	var style_variant: StringName = zone.get("style_variant", &"")
	var speed_multiplier := TerrainVegetation.resolved_zone_speed(
		style_variant,
		zone.get("movement_speed_multiplier", null)
	)
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			grid.set_terrain(cell, terrain)
			if not style_variant.is_empty() or speed_multiplier < 0.999:
				grid.apply_vegetation_overlay(cell, style_variant, speed_multiplier)
