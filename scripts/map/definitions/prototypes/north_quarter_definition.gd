class_name NorthQuarterDefinition
extends RefCounted

## Inactive north quarter street prototype (P4-015).


static func create() -> MapDefinition:
	var definition := MapDefinition.new()
	InteriorMapFactory.init_definition(
		definition,
		&"north_quarter",
		&"loc.lower_town.north_quarter",
		&"prototype",
		false,
		&"clean_painted",
		Vector2i(64, 36),
		MapTypes.TERRAIN_COBBLESTONE,
		"north_quarter_v1",
		Rect2i(30, 28, 2, 2)
	)

	definition.zones = [
		{"terrain": MapTypes.TERRAIN_DIRT, "rect": Rect2i(28, 8, 8, 24)},
		{"terrain": MapTypes.TERRAIN_STONE, "rect": Rect2i(10, 12, 8, 6)},
		{"terrain": MapTypes.TERRAIN_GRASS, "rect": Rect2i(48, 26, 10, 6)},
	]

	definition.buildings = [
		{"id": &"st_olaf_silhouette", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(26, 4, 10, 8)), "wall_height": 104.0, "wall_color": Color(0.50, 0.48, 0.44), "roof_color": Color(0.28, 0.24, 0.20)},
		{"id": &"great_guild_front", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(8, 10, 8, 5)), "wall_height": 72.0, "wall_color": Color(0.38, 0.34, 0.28), "roof_color": Color(0.22, 0.20, 0.16)},
		{"id": &"workshop_row", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(44, 10, 10, 4)), "wall_height": 60.0, "wall_color": Color(0.36, 0.32, 0.28), "roof_color": Color(0.20, 0.18, 0.16)},
		{"id": &"perimeter_north", "kind": MapTypes.BUILDING_KIND_WALL, "footprint": definition.cell_rect_to_world_rect(Rect2i(4, 4, 56, 1)), "wall_height": 48.0, "wall_color": Color(0.48, 0.50, 0.54)},
		{"id": &"perimeter_south", "kind": MapTypes.BUILDING_KIND_WALL, "footprint": definition.cell_rect_to_world_rect(Rect2i(4, 31, 56, 1)), "wall_height": 48.0, "wall_color": Color(0.48, 0.50, 0.54)},
	]

	definition.props = [
		{"id": &"rope_props", "kind": MapTypes.PROP_KIND_BARRELS, "position": definition.cell_rect_center(Rect2i(40, 20, 2, 2))},
		{"id": &"street_cart", "kind": MapTypes.PROP_KIND_CART, "position": definition.cell_rect_center(Rect2i(32, 22, 2, 2))},
		{"id": &"dock_barrels", "kind": MapTypes.PROP_KIND_BARRELS, "position": definition.cell_rect_center(Rect2i(52, 24, 2, 2))},
	]

	InteriorMapFactory.add_interaction_anchor(definition, &"inspection_spawn", Rect2i(30, 28, 2, 2))
	InteriorMapFactory.add_interaction_anchor(definition, &"pikk_street_spine", Rect2i(30, 16, 2, 2))
	InteriorMapFactory.add_interaction_anchor(definition, &"guild_frontage", Rect2i(10, 12, 2, 2))
	InteriorMapFactory.add_transition(
		definition,
		&"to_reval_east",
		Rect2i(28, 34, 4, 2),
		&"reval_east",
		&"vene_district_boundary",
		&"from_reval_east",
		Vector2(0.0, 48.0),
		true
	)
	InteriorMapFactory.add_transition(
		definition,
		&"to_reval_center",
		Rect2i(0, 28, 2, 4),
		&"reval_center",
		&"to_reval_north",
		&"from_reval_center",
		Vector2(48.0, 0.0),
		true
	)
	InteriorMapFactory.add_fade_volume(definition, Rect2i(24, 6, 16, 4))
	InteriorMapFactory.add_source_references(
		definition,
		[
			"scenes/reval_north/reval_north.tscn",
			"scenes/reval_north/pikk_street.md",
			"scenes/reval_north/great_guild_hall.md",
		]
	)
	return definition
