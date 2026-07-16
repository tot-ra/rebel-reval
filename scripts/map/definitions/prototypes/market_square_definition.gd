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
		"market_square_v1",
		Rect2i(24, 14, 2, 2)
	)

	definition.zones = [
		{"terrain": MapTypes.TERRAIN_DIRT, "rect": Rect2i(8, 10, 34, 10)},
		{"terrain": MapTypes.TERRAIN_DIRT, "rect": Rect2i(14, 18, 10, 4)},
		{"terrain": MapTypes.TERRAIN_STONE, "rect": Rect2i(22, 8, 6, 3)},
	]

	InteriorMapFactory.add_perimeter_walls(definition, Rect2i(4, 4, 42, 20), 1, 48.0, Color(0.48, 0.50, 0.54))
	InteriorMapFactory.add_prop_at_cell(definition, &"weigh_table_prop", MapTypes.PROP_KIND_TABLE, Rect2i(22, 10, 3, 2))
	InteriorMapFactory.add_prop_at_cell(definition, &"market_well", MapTypes.PROP_KIND_WELL, Rect2i(34, 12, 3, 3))
	InteriorMapFactory.add_prop_at_cell(definition, &"stall_a", MapTypes.PROP_KIND_STALL, Rect2i(10, 12, 3, 2))
	InteriorMapFactory.add_prop_at_cell(definition, &"stall_b", MapTypes.PROP_KIND_STALL, Rect2i(16, 12, 3, 2))
	InteriorMapFactory.add_prop_at_cell(definition, &"market_cart", MapTypes.PROP_KIND_CART, Rect2i(28, 16, 2, 2))
	InteriorMapFactory.add_prop_at_cell(definition, &"market_barrels", MapTypes.PROP_KIND_BARRELS, Rect2i(38, 16, 2, 2))

	InteriorMapFactory.add_interaction_anchor(definition, &"inspection_spawn", Rect2i(24, 14, 2, 2))
	InteriorMapFactory.add_interaction_anchor(definition, &"weigh_table", Rect2i(22, 10, 3, 2))
	InteriorMapFactory.add_source_references(
		definition,
		[
			"scenes/reval_center/market_civic_quarter/market.tscn",
			"scenes/reval_center/market_civic_quarter/market.md",
		]
	)
	return definition
