class_name LowerTownSliceDefinition
extends RefCounted

## Bounded Lower Town exterior replacing legacy district canvas (P2-019).


static func create() -> MapDefinition:
	var definition := MapDefinition.new()
	InteriorMapFactory.init_definition(
		definition,
		&"lower_town_slice",
		&"loc.lower_town_slice",
		&"production",
		true,
		&"clean_painted",
		Vector2i(64, 36),
		MapTypes.TERRAIN_COBBLESTONE,
		"lower_town_slice_v3",
		Rect2i(8, 28, 2, 2)
	)

	definition.zones = [
		{"terrain": MapTypes.TERRAIN_DIRT, "rect": Rect2i(18, 16, 18, 10)},
		{"terrain": MapTypes.TERRAIN_STONE, "rect": Rect2i(40, 18, 8, 6)},
		{"terrain": MapTypes.TERRAIN_WATER, "rect": Rect2i(30, 24, 4, 3)},
		{"terrain": MapTypes.TERRAIN_HAY, "rect": Rect2i(20, 12, 6, 4)},
		{"terrain": MapTypes.TERRAIN_GRASS, "rect": Rect2i(2, 2, 60, 4)},
		# Ground wear that breaks up the large cobble and dirt fields.
		{"terrain": MapTypes.TERRAIN_MUD, "rect": Rect2i(29, 23, 6, 5)},
		{"terrain": MapTypes.TERRAIN_GRASS, "rect": Rect2i(2, 6, 6, 26)},
		{"terrain": MapTypes.TERRAIN_GRASS, "rect": Rect2i(58, 6, 4, 28)},
		{"terrain": MapTypes.TERRAIN_DIRT, "rect": Rect2i(10, 12, 6, 2)},
		{"terrain": MapTypes.TERRAIN_STONE, "rect": Rect2i(20, 18, 8, 1)},
	]

	definition.buildings = [
		{"id": &"smithy_facade", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(20, 14, 8, 4)), "wall_height": 128.0, "wall_color": Color(0.34, 0.30, 0.26), "roof_color": Color(0.22, 0.20, 0.18)},
		{"id": &"brewery_facade", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(42, 14, 7, 5)), "wall_height": 120.0, "wall_color": Color(0.38, 0.32, 0.26), "roof_color": Color(0.24, 0.20, 0.16)},
		{"id": &"checkpoint_west_mass", "kind": MapTypes.BUILDING_KIND_WALL, "footprint": definition.cell_rect_to_world_rect(Rect2i(6, 20, 3, 8)), "wall_height": 96.0, "wall_color": Color(0.40, 0.41, 0.44)},
		{"id": &"checkpoint_east_mass", "kind": MapTypes.BUILDING_KIND_WALL, "footprint": definition.cell_rect_to_world_rect(Rect2i(55, 20, 3, 8)), "wall_height": 96.0, "wall_color": Color(0.40, 0.41, 0.44)},
		{"id": &"tenement_north", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(10, 8, 6, 4)), "wall_height": 112.0, "wall_color": Color(0.40, 0.36, 0.30), "roof_color": Color(0.22, 0.20, 0.18)},
		{"id": &"tenement_south", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(48, 8, 6, 4)), "wall_height": 112.0, "wall_color": Color(0.40, 0.36, 0.30), "roof_color": Color(0.22, 0.20, 0.18)},
	]

	definition.props = [
		{"id": &"street_cart", "kind": MapTypes.PROP_KIND_CART, "position": definition.cell_rect_center(Rect2i(12, 26, 2, 2))},
		{"id": &"cistern", "kind": MapTypes.PROP_KIND_WELL, "position": definition.cell_rect_center(Rect2i(30, 24, 4, 3))},
		{"id": &"evidence_barrels", "kind": MapTypes.PROP_KIND_BARRELS, "position": definition.cell_rect_center(Rect2i(36, 22, 2, 2))},
		{"id": &"courtyard_anvil", "kind": MapTypes.PROP_KIND_ANVIL, "position": definition.cell_rect_center(Rect2i(19, 20, 3, 2))},
		# Street and courtyard dressing so the district reads inhabited.
		{"id": &"courtyard_furnace", "kind": MapTypes.PROP_KIND_FURNACE, "position": definition.cell_rect_center(Rect2i(28, 20, 2, 2))},
		{"id": &"courtyard_quench", "kind": MapTypes.PROP_KIND_QUENCH, "position": definition.cell_rect_center(Rect2i(22, 21, 1, 1))},
		{"id": &"hay_store", "kind": MapTypes.PROP_KIND_HAY_STACK, "position": definition.cell_rect_center(Rect2i(21, 12, 3, 3))},
		{"id": &"market_stall_west", "kind": MapTypes.PROP_KIND_STALL, "position": definition.cell_rect_center(Rect2i(16, 29, 3, 2))},
		{"id": &"market_stall_east", "kind": MapTypes.PROP_KIND_STALL, "position": definition.cell_rect_center(Rect2i(40, 29, 3, 2))},
		{"id": &"brewery_barrels", "kind": MapTypes.PROP_KIND_BARRELS, "position": definition.cell_rect_center(Rect2i(45, 20, 2, 2))},
		{"id": &"street_barrels", "kind": MapTypes.PROP_KIND_BARRELS, "position": definition.cell_rect_center(Rect2i(24, 31, 2, 2))},
		{"id": &"gate_cart", "kind": MapTypes.PROP_KIND_CART, "position": definition.cell_rect_center(Rect2i(50, 30, 2, 2))},
	]

	InteriorMapFactory.add_interaction_anchor(definition, &"street_start", Rect2i(8, 28, 2, 2))
	InteriorMapFactory.add_interaction_anchor(definition, &"smithy_door", Rect2i(21, 18, 6, 1))
	InteriorMapFactory.add_interaction_anchor(definition, &"brewery_door", Rect2i(44, 18, 2, 2))
	InteriorMapFactory.add_interaction_anchor(definition, &"checkpoint_west", Rect2i(10, 24, 2, 2))
	InteriorMapFactory.add_interaction_anchor(definition, &"checkpoint_east", Rect2i(52, 24, 2, 2))

	InteriorMapFactory.add_transition(
		definition,
		&"smithy_door_transition",
		Rect2i(21, 18, 6, 1),
		&"forge",
		&"door_courtyard",
		&"forge",
		Vector2(0.0, 48.0)
	)
	InteriorMapFactory.add_transition(
		definition,
		&"street_start_spawn",
		Rect2i(8, 28, 2, 2),
		&"",
		&"",
		&"street_start"
	)

	definition.patrols = [
		{
			"points": [
				definition.cell_rect_center(Rect2i(10, 24, 2, 2)),
				definition.cell_rect_center(Rect2i(20, 26, 2, 2)),
				definition.cell_rect_center(Rect2i(52, 24, 2, 2)),
			]
		}
	]

	InteriorMapFactory.add_fade_volume(definition, Rect2i(18, 12, 34, 4))
	InteriorMapFactory.add_source_references(
		definition,
		[
			"scenes/reval_east/reval_east.tscn",
			"docs/SCENES/the-makers-mark.md",
			"docs/SCENES/a-bitter-brew.md",
			"content/locations/loc.lower_town_slice.json",
		]
	)
	return definition
