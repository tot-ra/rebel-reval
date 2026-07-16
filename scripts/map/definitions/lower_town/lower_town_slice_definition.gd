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
		"lower_town_slice_v1",
		Rect2i(8, 28, 2, 2)
	)

	definition.zones = [
		{"terrain": MapTypes.TERRAIN_DIRT, "rect": Rect2i(18, 16, 18, 10)},
		{"terrain": MapTypes.TERRAIN_STONE, "rect": Rect2i(40, 18, 8, 6)},
		{"terrain": MapTypes.TERRAIN_WATER, "rect": Rect2i(30, 24, 4, 3)},
		{"terrain": MapTypes.TERRAIN_HAY, "rect": Rect2i(20, 12, 6, 4)},
		{"terrain": MapTypes.TERRAIN_GRASS, "rect": Rect2i(2, 2, 60, 4)},
	]

	definition.buildings = [
		{"id": &"smithy_facade", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(20, 14, 8, 4)), "wall_height": 72.0, "wall_color": Color(0.34, 0.30, 0.26), "roof_color": Color(0.22, 0.20, 0.18)},
		{"id": &"brewery_facade", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(42, 14, 7, 5)), "wall_height": 68.0, "wall_color": Color(0.38, 0.32, 0.26), "roof_color": Color(0.24, 0.20, 0.16)},
		{"id": &"checkpoint_west_mass", "kind": MapTypes.BUILDING_KIND_WALL, "footprint": definition.cell_rect_to_world_rect(Rect2i(6, 20, 3, 8)), "wall_height": 56.0, "wall_color": Color(0.48, 0.50, 0.54)},
		{"id": &"checkpoint_east_mass", "kind": MapTypes.BUILDING_KIND_WALL, "footprint": definition.cell_rect_to_world_rect(Rect2i(55, 20, 3, 8)), "wall_height": 56.0, "wall_color": Color(0.48, 0.50, 0.54)},
		{"id": &"tenement_north", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(10, 8, 6, 4)), "wall_height": 64.0, "wall_color": Color(0.40, 0.36, 0.30), "roof_color": Color(0.22, 0.20, 0.18)},
		{"id": &"tenement_south", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(48, 8, 6, 4)), "wall_height": 64.0, "wall_color": Color(0.40, 0.36, 0.30), "roof_color": Color(0.22, 0.20, 0.18)},
	]

	definition.props = [
		{"id": &"street_cart", "kind": MapTypes.PROP_KIND_CART, "position": definition.cell_rect_center(Rect2i(12, 26, 2, 2))},
		{"id": &"cistern", "kind": MapTypes.PROP_KIND_WELL, "position": definition.cell_rect_center(Rect2i(30, 24, 4, 3))},
		{"id": &"evidence_barrels", "kind": MapTypes.PROP_KIND_BARRELS, "position": definition.cell_rect_center(Rect2i(36, 22, 2, 2))},
		{"id": &"courtyard_anvil", "kind": MapTypes.PROP_KIND_ANVIL, "position": definition.cell_rect_center(Rect2i(24, 18, 3, 2))},
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
