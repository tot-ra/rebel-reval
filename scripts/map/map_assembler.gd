class_name MapAssembler
extends RefCounted

## Wires one immutable definition through a selectable rendering-only profile.


static func assemble(
	parent: Node2D,
	definition: MapDefinition,
	grid: MapTerrainGrid,
	y_sort_parent: Node2D = null,
	visual_target: StringName = MapVisualStyle.TARGET_CLEAN_PAINTED,
	time_of_day: StringName = MapVisualStyle.TIME_DAY
) -> Dictionary:
	assert(MapVisualStyle.is_valid_target(visual_target))
	assert(MapVisualStyle.is_valid_time(time_of_day))

	var terrain := MapTerrainRenderer.new(grid, visual_target, time_of_day)
	terrain.name = "Terrain"
	# Terrain is the first chunked runtime layer. Buildings and navigation remain
	# monolithic until their dedicated milestones.
	terrain.update_active_chunks(definition.player_spawn)
	parent.add_child(terrain)

	var entities := y_sort_parent if y_sort_parent != null else parent
	if entities != parent:
		entities.y_sort_enabled = true

	var building_bodies: Array[StaticBody2D] = []
	for building in definition.buildings:
		var body := MapBuildingRenderer.create_building(building, visual_target, time_of_day)
		entities.add_child(body)
		building_bodies.append(body)

	var prop_nodes: Array[Node2D] = []
	for prop in definition.props:
		var prop_node := MapPropRenderer.create_prop(prop, visual_target, time_of_day)
		entities.add_child(prop_node)
		prop_nodes.append(prop_node)

	return {
		"terrain": terrain,
		"buildings": building_bodies,
		"props": prop_nodes,
		"grid": grid,
		"definition": definition,
		"visual_target": visual_target,
		"time_of_day": time_of_day,
	}
