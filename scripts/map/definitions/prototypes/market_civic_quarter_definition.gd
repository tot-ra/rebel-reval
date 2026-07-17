class_name MarketCivicQuarterDefinition
extends RefCounted

## Inactive market civic quarter prototype (P4-014).


static func create() -> MapDefinition:
	var definition := MapDefinition.new()
	InteriorMapFactory.init_definition(
		definition,
		&"market_civic_quarter",
		&"loc.lower_town.market_civic_quarter",
		&"prototype",
		false,
		&"clean_painted",
		Vector2i(64, 36),
		MapTypes.TERRAIN_COBBLESTONE,
		"market_civic_quarter_v2_street_entries",
		Rect2i(30, 24, 2, 2)
	)

	definition.zones = [
		{"terrain": MapTypes.TERRAIN_COBBLESTONE, "rect": Rect2i(0, 20, 64, 4)},
		{"terrain": MapTypes.TERRAIN_COBBLESTONE, "rect": Rect2i(28, 24, 4, 12)},
		{"terrain": MapTypes.TERRAIN_STONE, "rect": Rect2i(24, 10, 16, 8)},
		{"terrain": MapTypes.TERRAIN_DIRT, "rect": Rect2i(10, 20, 44, 8)},
		{"terrain": MapTypes.TERRAIN_WATER, "rect": Rect2i(46, 22, 4, 3)},
	]

	definition.buildings = [
		{"id": &"east_entry_house_north", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(0, 16, 4, 5)), "wall_height": 112.0, "wall_color": Color(0.42, 0.38, 0.32), "roof_color": Color(0.24, 0.20, 0.18), "door_side": &"east"},
		{"id": &"east_entry_house_south", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(0, 24, 4, 5)), "wall_height": 112.0, "wall_color": Color(0.41, 0.37, 0.31), "roof_color": Color(0.23, 0.20, 0.17), "door_side": &"east"},
		{"id": &"south_entry_house_west", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(24, 34, 4, 2)), "wall_height": 104.0, "wall_color": Color(0.40, 0.36, 0.30), "roof_color": Color(0.22, 0.20, 0.18), "door_side": &"north"},
		{"id": &"south_entry_house_east", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(32, 34, 4, 2)), "wall_height": 104.0, "wall_color": Color(0.39, 0.35, 0.30), "roof_color": Color(0.22, 0.19, 0.16), "door_side": &"north"},
		{"id": &"town_hall_mass", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(26, 8, 12, 6)), "wall_height": 88.0, "wall_color": Color(0.42, 0.38, 0.34), "roof_color": Color(0.24, 0.20, 0.18)},
		{"id": &"church_silhouette", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(8, 6, 8, 8)), "wall_height": 96.0, "wall_color": Color(0.50, 0.48, 0.44), "roof_color": Color(0.28, 0.24, 0.20)},
		{"id": &"apothecary_front", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(44, 10, 6, 4)), "wall_height": 64.0, "wall_color": Color(0.38, 0.34, 0.28), "roof_color": Color(0.22, 0.20, 0.16)},
		{"id": &"perimeter_west", "kind": MapTypes.BUILDING_KIND_WALL, "footprint": definition.cell_rect_to_world_rect(Rect2i(4, 4, 1, 28)), "wall_height": 48.0, "wall_color": Color(0.48, 0.50, 0.54)},
		{"id": &"perimeter_east", "kind": MapTypes.BUILDING_KIND_WALL, "footprint": definition.cell_rect_to_world_rect(Rect2i(59, 4, 1, 28)), "wall_height": 48.0, "wall_color": Color(0.48, 0.50, 0.54)},
	]

	definition.props = [
		{"id": &"civic_well", "kind": MapTypes.PROP_KIND_WELL, "position": definition.cell_rect_center(Rect2i(46, 22, 4, 3))},
		{"id": &"notice_cart", "kind": MapTypes.PROP_KIND_CART, "position": definition.cell_rect_center(Rect2i(18, 24, 2, 2))},
		{"id": &"guild_stall", "kind": MapTypes.PROP_KIND_STALL, "position": definition.cell_rect_center(Rect2i(40, 18, 3, 2))},
	]

	InteriorMapFactory.add_interaction_anchor(definition, &"inspection_spawn", Rect2i(30, 24, 2, 2))
	InteriorMapFactory.add_interaction_anchor(definition, &"town_hall_edge", Rect2i(30, 14, 2, 2))

	definition.view_landmarks = [
		{"id": &"viru_entry_arch", "kind": &"gate_arch", "rect": definition.cell_rect_to_world_rect(Rect2i(0, 20, 2, 4)), "wall_color": Color(0.52, 0.50, 0.46), "top_px": 160.0, "passage_axis": &"x", "door_material": &"wood"},
		{"id": &"karja_entry_arch", "kind": &"gate_arch", "rect": definition.cell_rect_to_world_rect(Rect2i(28, 34, 4, 2)), "wall_color": Color(0.52, 0.50, 0.46), "top_px": 160.0, "passage_axis": &"z", "door_material": &"wood"},
		{"id": &"pikk_entry_arch", "kind": &"gate_arch", "rect": definition.cell_rect_to_world_rect(Rect2i(28, 0, 4, 2)), "wall_color": Color(0.52, 0.50, 0.46), "top_px": 160.0, "passage_axis": &"z", "door_material": &"wood"},
	]
	definition.surroundings_town_sides = [&"west", &"south"]

	InteriorMapFactory.add_transition(
		definition,
		&"to_reval_east",
		Rect2i(0, 22, 2, 4),
		&"reval_east",
		&"vana_turg_boundary",
		&"from_reval_east",
		Vector2(48.0, 0.0),
		true,
		&"viru_entry_arch"
	)
	InteriorMapFactory.add_transition(
		definition,
		&"to_reval_east_south",
		Rect2i(28, 34, 4, 2),
		&"reval_east",
		&"karja_road_boundary",
		&"from_reval_east_south",
		Vector2(0.0, -48.0),
		true,
		&"karja_entry_arch"
	)
	InteriorMapFactory.add_transition(
		definition,
		&"to_reval_north",
		Rect2i(28, 0, 4, 2),
		&"reval_north",
		&"from_reval_center",
		&"to_reval_north",
		Vector2(0.0, 48.0),
		true,
		&"pikk_entry_arch"
	)
	InteriorMapFactory.add_transition(
		definition,
		&"to_market",
		Rect2i(40, 18, 2, 2),
		&"market_civic_quarter",
		&"from_reval_center",
		&"to_market"
	)
	InteriorMapFactory.add_transition(
		definition,
		&"to_guild_hall",
		Rect2i(12, 10, 2, 2),
		&"st_olafs_guild_hall",
		&"from_reval_center",
		&"to_guild_hall"
	)
	InteriorMapFactory.add_fade_volume(definition, Rect2i(20, 8, 24, 4))
	InteriorMapFactory.add_source_references(
		definition,
		[
			"scenes/reval_center/reval_center.tscn",
			"scenes/reval_center/market_civic_quarter/town_hall_square.md",
		]
	)
	return definition
