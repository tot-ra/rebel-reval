class_name MapBuilder
extends RefCounted

## Fills world bounds from a MapDefinition and exposes validation helpers.


static func build(definition: MapDefinition) -> MapTerrainGrid:
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


static func _apply_zone(grid: MapTerrainGrid, zone: Dictionary) -> void:
	var rect: Rect2i = zone["rect"]
	var terrain: StringName = zone["terrain"]
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			grid.set_terrain(Vector2i(x, y), terrain)
