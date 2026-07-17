class_name MarketSquareDefinition
extends RefCounted

## Inactive market square prototype (P4-014).


static func create() -> MapDefinition:
	var definition := MapDefinition.new()
	InteriorMapFactory.init_definition(
		definition,
		&"market_square",
		&"loc.lower_town.market_square",
		&"prototype",
		false,
		&"clean_painted",
		Vector2i(50, 28),
		MapTypes.TERRAIN_COBBLESTONE,
		"market_square_v2_street_entries",
		Rect2i(24, 14, 2, 2)
	)

	definition.zones = [
		{"terrain": MapTypes.TERRAIN_COBBLESTONE, "rect": Rect2i(20, 10, 10, 18)},
		{"terrain": MapTypes.TERRAIN_DIRT, "rect": Rect2i(8, 10, 34, 10)},
		{"terrain": MapTypes.TERRAIN_DIRT, "rect": Rect2i(14, 18, 10, 4)},
		{"terrain": MapTypes.TERRAIN_STONE, "rect": Rect2i(22, 8, 6, 3)},
	]

	InteriorMapFactory.add_perimeter_walls(definition, Rect2i(4, 4, 42, 20), 1, 48.0, Color(0.48, 0.50, 0.54))
	definition.view_landmarks = [
		{"id": &"karja_entry_arch", "kind": &"gate_arch", "rect": definition.cell_rect_to_world_rect(Rect2i(22, 26, 4, 2)), "wall_color": Color(0.52, 0.50, 0.46), "top_px": 140.0, "passage_axis": &"z", "door_material": &"wood"},
		{"id": &"center_entry_arch", "kind": &"gate_arch", "rect": definition.cell_rect_to_world_rect(Rect2i(0, 12, 2, 4)), "wall_color": Color(0.52, 0.50, 0.46), "top_px": 140.0, "passage_axis": &"x", "door_material": &"wood"},
	]
	definition.surroundings_town_sides = [&"south", &"west"]
	InteriorMapFactory.add_prop_at_cell(definition, &"weigh_table_prop", MapTypes.PROP_KIND_TABLE, Rect2i(22, 10, 3, 2))
	InteriorMapFactory.add_prop_at_cell(definition, &"market_well", MapTypes.PROP_KIND_WELL, Rect2i(34, 12, 3, 3))
	InteriorMapFactory.add_prop_at_cell(definition, &"stall_a", MapTypes.PROP_KIND_STALL, Rect2i(10, 12, 3, 2))
	InteriorMapFactory.add_prop_at_cell(definition, &"stall_b", MapTypes.PROP_KIND_STALL, Rect2i(16, 12, 3, 2))
	InteriorMapFactory.add_prop_at_cell(definition, &"market_cart", MapTypes.PROP_KIND_CART, Rect2i(28, 16, 2, 2))
	InteriorMapFactory.add_prop_at_cell(definition, &"market_barrels", MapTypes.PROP_KIND_BARRELS, Rect2i(38, 16, 2, 2))

	InteriorMapFactory.add_interaction_anchor(definition, &"inspection_spawn", Rect2i(24, 14, 2, 2))
	InteriorMapFactory.add_interaction_anchor(definition, &"weigh_table", Rect2i(22, 10, 3, 2))
	InteriorMapFactory.add_transition(
		definition,
		&"to_reval_east",
		Rect2i(22, 26, 4, 2),
		&"reval_east",
		&"karja_road_boundary",
		&"from_reval_east",
		Vector2(0.0, -48.0),
		true,
		&"karja_entry_arch"
	)
	InteriorMapFactory.add_transition(
		definition,
		&"to_reval_center",
		Rect2i(0, 12, 2, 4),
		&"reval_center",
		&"to_market",
		&"from_reval_center",
		Vector2(48.0, 0.0),
		true,
		&"center_entry_arch"
	)
	InteriorMapFactory.add_source_references(
		definition,
		[
			"scenes/reval_center/market_civic_quarter/market.tscn",
			"scenes/reval_center/market_civic_quarter/market.md",
		]
	)
	return definition
