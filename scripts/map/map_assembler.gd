class_name MapAssembler
extends RefCounted

## Wires definition, terrain grid, buildings, and props into a scene subtree.


static func assemble(parent: Node2D, definition: MapDefinition, grid: MapTerrainGrid, y_sort_parent: Node2D = null) -> Dictionary:
	var terrain := MapTerrainRenderer.new(grid)
	terrain.name = "Terrain"
	parent.add_child(terrain)

	var entities := y_sort_parent if y_sort_parent != null else parent
	if entities != parent:
		entities.y_sort_enabled = true

	var building_bodies: Array[StaticBody2D] = []
	for building in definition.buildings:
		var body := MapBuildingRenderer.create_building(building)
		entities.add_child(body)
		building_bodies.append(body)

	for prop in definition.props:
		entities.add_child(MapPropRenderer.create_prop(prop))

	return {
		"terrain": terrain,
		"buildings": building_bodies,
		"grid": grid,
		"definition": definition,
	}
