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
		"market_civic_quarter_v1",
		Rect2i(30, 24, 2, 2)
	)

	definition.zones = [
		{"terrain": MapTypes.TERRAIN_STONE, "rect": Rect2i(24, 10, 16, 8)},
		{"terrain": MapTypes.TERRAIN_DIRT, "rect": Rect2i(10, 20, 44, 8)},
		{"terrain": MapTypes.TERRAIN_WATER, "rect": Rect2i(46, 22, 4, 3)},
	]

	definition.buildings = [
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
	InteriorMapFactory.add_fade_volume(definition, Rect2i(20, 8, 24, 4))
	InteriorMapFactory.add_source_references(
		definition,
		[
			"scenes/reval_center/reval_center.tscn",
			"scenes/reval_center/market_civic_quarter/town_hall_square.md",
		]
	)
	return definition
