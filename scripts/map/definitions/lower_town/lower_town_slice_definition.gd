class_name LowerTownSliceDefinition
extends RefCounted

## Viru Gate quarter of the eastern Lower Town (P2-019, historical layout pass).
##
## Layout follows the real street plan of eastern Old Town Tallinn as read from
## `scenes/revel-map.jpg` and `scenes/reval_walls_towers/wall-map.png`:
## - The town wall runs north-south along the east edge with Viru Gate as the
##   only opening; a wet moat lies outside it. Towers flanking the gate are
##   attested; the northern wall tower is a plausible composite (the named
##   Hellemann tower is post-1343).
## - Viru street runs east-west from the gate toward Vana turg (Old Market).
## - Müürivahe is the narrow service lane hugging the inside of the wall.
## - Vene street runs north-south; St. Catherine's Passage (Katariina käik)
##   links it to Müürivahe along the south flank of the Dominican monastery
##   of St. Catherine (founded 1246, firmly present in 1343).
## - Smiths and fire-risk trades cluster against the wall south of the gate,
##   which is where Kalev's smithy courtyard sits.


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
		MapTypes.TERRAIN_DIRT,
		"lower_town_slice_v4_viru_gate_quarter",
		Rect2i(47, 30, 2, 2)
	)

	definition.zones = [
		# Outside the wall: glacis, wet moat, and the eastern road causeway.
		{"terrain": MapTypes.TERRAIN_GRASS, "rect": Rect2i(55, 0, 9, 36)},
		{"terrain": MapTypes.TERRAIN_WATER, "rect": Rect2i(58, 0, 2, 36)},
		{"terrain": MapTypes.TERRAIN_DIRT, "rect": Rect2i(55, 15, 9, 3)},
		# Viru street: the paved main axis from Vana turg to Viru Gate.
		{"terrain": MapTypes.TERRAIN_COBBLESTONE, "rect": Rect2i(0, 15, 55, 3)},
		{"terrain": MapTypes.TERRAIN_STONE, "rect": Rect2i(52, 15, 3, 3)},
		# Vana turg widens where Viru street meets the market quarter.
		{"terrain": MapTypes.TERRAIN_COBBLESTONE, "rect": Rect2i(0, 12, 6, 9)},
		# Vene street north-south, and St. Catherine's Passage east-west.
		{"terrain": MapTypes.TERRAIN_COBBLESTONE, "rect": Rect2i(17, 0, 3, 15)},
		{"terrain": MapTypes.TERRAIN_STONE, "rect": Rect2i(20, 8, 30, 2)},
		# Müürivahe: unpaved lane between the houses and the town wall.
		{"terrain": MapTypes.TERRAIN_DIRT, "rect": Rect2i(50, 0, 3, 12)},
		{"terrain": MapTypes.TERRAIN_DIRT, "rect": Rect2i(49, 18, 3, 10)},
		{"terrain": MapTypes.TERRAIN_DIRT, "rect": Rect2i(47, 28, 3, 8)},
		# Lane toward Karja Gate leaving the slice to the south-west.
		{"terrain": MapTypes.TERRAIN_DIRT, "rect": Rect2i(8, 18, 3, 18)},
		{"terrain": MapTypes.TERRAIN_MUD, "rect": Rect2i(8, 24, 3, 3)},
		# Smithy work yard against the wall south of the gate.
		{"terrain": MapTypes.TERRAIN_DIRT, "rect": Rect2i(39, 21, 10, 7)},
		{"terrain": MapTypes.TERRAIN_HAY, "rect": Rect2i(39, 26, 2, 2)},
		# Backyard greens and the monastery garden.
		{"terrain": MapTypes.TERRAIN_GRASS, "rect": Rect2i(1, 0, 4, 6)},
		{"terrain": MapTypes.TERRAIN_GRASS, "rect": Rect2i(44, 1, 5, 6)},
		{"terrain": MapTypes.TERRAIN_GRASS, "rect": Rect2i(26, 30, 6, 4)},
	]

	definition.buildings = [
		# Town wall line, north of Viru Gate.
		{"id": &"city_wall_north", "kind": MapTypes.BUILDING_KIND_WALL, "footprint": definition.cell_rect_to_world_rect(Rect2i(53, 0, 2, 12)), "wall_height": 192.0, "wall_color": Color(0.58, 0.57, 0.52)},
		{"id": &"wall_tower_north", "kind": MapTypes.BUILDING_KIND_WALL, "footprint": definition.cell_rect_to_world_rect(Rect2i(52, 5, 3, 3)), "wall_height": 240.0, "wall_color": Color(0.55, 0.54, 0.50)},
		# Viru Gate: two flanking tower masses with the street passing between.
		{"id": &"viru_gate_north_tower", "kind": MapTypes.BUILDING_KIND_WALL, "footprint": definition.cell_rect_to_world_rect(Rect2i(52, 12, 4, 3)), "wall_height": 256.0, "wall_color": Color(0.56, 0.55, 0.50)},
		{"id": &"viru_gate_south_tower", "kind": MapTypes.BUILDING_KIND_WALL, "footprint": definition.cell_rect_to_world_rect(Rect2i(52, 18, 4, 3)), "wall_height": 256.0, "wall_color": Color(0.56, 0.55, 0.50)},
		# Town wall south of the gate, bending west at the Hinke tower spot.
		{"id": &"city_wall_south", "kind": MapTypes.BUILDING_KIND_WALL, "footprint": definition.cell_rect_to_world_rect(Rect2i(52, 21, 2, 8)), "wall_height": 192.0, "wall_color": Color(0.58, 0.57, 0.52)},
		{"id": &"hinke_tower", "kind": MapTypes.BUILDING_KIND_WALL, "footprint": definition.cell_rect_to_world_rect(Rect2i(50, 28, 3, 3)), "wall_height": 224.0, "wall_color": Color(0.55, 0.54, 0.50)},
		{"id": &"city_wall_south_lower", "kind": MapTypes.BUILDING_KIND_WALL, "footprint": definition.cell_rect_to_world_rect(Rect2i(50, 31, 2, 5)), "wall_height": 192.0, "wall_color": Color(0.58, 0.57, 0.52)},
		# Dominican monastery of St. Catherine north of the passage.
		{"id": &"st_catherines_church", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(22, 2, 12, 5)), "wall_height": 192.0, "wall_color": Color(0.66, 0.64, 0.58), "roof_color": Color(0.30, 0.16, 0.12)},
		{"id": &"monastery_cloister", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(34, 0, 9, 6)), "wall_height": 128.0, "wall_color": Color(0.62, 0.60, 0.55), "roof_color": Color(0.28, 0.16, 0.12)},
		{"id": &"monastery_precinct_wall", "kind": MapTypes.BUILDING_KIND_WALL, "footprint": definition.cell_rect_to_world_rect(Rect2i(21, 0, 1, 8)), "wall_height": 96.0, "wall_color": Color(0.60, 0.58, 0.53)},
		# Houses south of St. Catherine's Passage fronting Viru street; the
		# one-cell gaps between them are the passage-to-street alleys.
		{"id": &"kaik_house_west", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(21, 10, 4, 5)), "wall_height": 112.0, "wall_color": Color(0.42, 0.37, 0.31), "roof_color": Color(0.24, 0.20, 0.16)},
		{"id": &"kaik_house_mid", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(26, 10, 4, 5)), "wall_height": 120.0, "wall_color": Color(0.46, 0.40, 0.33), "roof_color": Color(0.26, 0.21, 0.16)},
		{"id": &"guild_storehouse", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(31, 10, 6, 5)), "wall_height": 136.0, "wall_color": Color(0.52, 0.48, 0.42), "roof_color": Color(0.26, 0.14, 0.11)},
		{"id": &"glovers_house", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(38, 10, 4, 5)), "wall_height": 112.0, "wall_color": Color(0.40, 0.36, 0.30), "roof_color": Color(0.22, 0.20, 0.18)},
		{"id": &"corner_house_muurivahe", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(43, 10, 6, 5)), "wall_height": 128.0, "wall_color": Color(0.50, 0.46, 0.40), "roof_color": Color(0.26, 0.15, 0.12)},
		# Blocks west of Vene street, toward the town centre.
		{"id": &"vene_row_house", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(6, 1, 6, 5)), "wall_height": 120.0, "wall_color": Color(0.44, 0.40, 0.34), "roof_color": Color(0.24, 0.20, 0.16)},
		{"id": &"market_row_house", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(1, 7, 5, 4)), "wall_height": 112.0, "wall_color": Color(0.41, 0.37, 0.31), "roof_color": Color(0.23, 0.20, 0.17)},
		{"id": &"apothecary_house", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(12, 8, 4, 6)), "wall_height": 128.0, "wall_color": Color(0.50, 0.45, 0.38), "roof_color": Color(0.26, 0.15, 0.12)},
		# South side of Viru street: brewery and the inn by the gate.
		{"id": &"foaming_mug_brewery", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(30, 18, 6, 4)), "wall_height": 120.0, "wall_color": Color(0.38, 0.32, 0.26), "roof_color": Color(0.24, 0.20, 0.16)},
		{"id": &"weary_traveler_inn", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(44, 18, 4, 3)), "wall_height": 120.0, "wall_color": Color(0.43, 0.38, 0.31), "roof_color": Color(0.25, 0.21, 0.16)},
		# Kalev's smithy and its walled work yard against the town wall.
		{"id": &"kalev_smithy", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(39, 22, 5, 4)), "wall_height": 128.0, "wall_color": Color(0.34, 0.30, 0.26), "roof_color": Color(0.22, 0.20, 0.18)},
		{"id": &"courtyard_wall_west", "kind": MapTypes.BUILDING_KIND_WALL, "footprint": definition.cell_rect_to_world_rect(Rect2i(38, 21, 1, 7)), "wall_height": 56.0, "wall_color": Color(0.48, 0.50, 0.54)},
		{"id": &"courtyard_wall_south", "kind": MapTypes.BUILDING_KIND_WALL, "footprint": definition.cell_rect_to_world_rect(Rect2i(39, 28, 2, 1)), "wall_height": 56.0, "wall_color": Color(0.48, 0.50, 0.54)},
		# Artisan quarter between Viru street and the Karja Gate lane.
		{"id": &"saddlers_house", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(13, 19, 5, 4)), "wall_height": 112.0, "wall_color": Color(0.40, 0.36, 0.30), "roof_color": Color(0.22, 0.20, 0.18)},
		{"id": &"coopers_house", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(20, 19, 5, 4)), "wall_height": 112.0, "wall_color": Color(0.42, 0.38, 0.31), "roof_color": Color(0.23, 0.20, 0.17)},
		{"id": &"public_bathhouse", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(13, 26, 5, 4)), "wall_height": 120.0, "wall_color": Color(0.46, 0.42, 0.36), "roof_color": Color(0.25, 0.21, 0.16)},
		{"id": &"tenement_row", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(1, 22, 5, 5)), "wall_height": 112.0, "wall_color": Color(0.40, 0.36, 0.30), "roof_color": Color(0.22, 0.20, 0.18)},
		{"id": &"potters_house", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(21, 26, 4, 4)), "wall_height": 104.0, "wall_color": Color(0.39, 0.35, 0.29), "roof_color": Color(0.22, 0.19, 0.16)},
		{"id": &"laundress_house", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(2, 30, 5, 4)), "wall_height": 104.0, "wall_color": Color(0.38, 0.34, 0.29), "roof_color": Color(0.22, 0.19, 0.16)},
		{"id": &"widows_house", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(28, 25, 4, 4)), "wall_height": 104.0, "wall_color": Color(0.39, 0.35, 0.30), "roof_color": Color(0.22, 0.20, 0.17)},
		{"id": &"artisan_shed", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(33, 30, 5, 4)), "wall_height": 96.0, "wall_color": Color(0.37, 0.33, 0.28), "roof_color": Color(0.21, 0.19, 0.16)},
	]

	definition.props = [
		# Smithy work yard.
		{"id": &"courtyard_anvil", "kind": MapTypes.PROP_KIND_ANVIL, "position": definition.cell_rect_center(Rect2i(46, 26, 2, 2))},
		{"id": &"courtyard_furnace", "kind": MapTypes.PROP_KIND_FURNACE, "position": definition.cell_rect_center(Rect2i(45, 21, 2, 2))},
		{"id": &"courtyard_quench", "kind": MapTypes.PROP_KIND_QUENCH, "position": definition.cell_rect_center(Rect2i(45, 25, 1, 1))},
		{"id": &"hay_store", "kind": MapTypes.PROP_KIND_HAY_STACK, "position": definition.cell_rect_center(Rect2i(39, 26, 2, 2))},
		# Public well on Müürivahe by the gate corner.
		{"id": &"cistern", "kind": MapTypes.PROP_KIND_WELL, "position": definition.cell_rect_center(Rect2i(50, 21, 2, 2))},
		# Street dressing: gate market and Viru street traffic.
		{"id": &"market_stall_gate", "kind": MapTypes.PROP_KIND_STALL, "position": definition.cell_rect_center(Rect2i(49, 13, 2, 2))},
		{"id": &"market_stall_viru", "kind": MapTypes.PROP_KIND_STALL, "position": definition.cell_rect_center(Rect2i(25, 13, 1, 2))},
		{"id": &"street_cart", "kind": MapTypes.PROP_KIND_CART, "position": definition.cell_rect_center(Rect2i(5, 18, 2, 2))},
		{"id": &"gate_cart", "kind": MapTypes.PROP_KIND_CART, "position": definition.cell_rect_center(Rect2i(56, 16, 2, 2))},
		# Brewery yard.
		{"id": &"brewery_barrels", "kind": MapTypes.PROP_KIND_BARRELS, "position": definition.cell_rect_center(Rect2i(36, 19, 2, 2))},
		{"id": &"evidence_barrels", "kind": MapTypes.PROP_KIND_BARRELS, "position": definition.cell_rect_center(Rect2i(33, 22, 2, 2))},
	]

	InteriorMapFactory.add_interaction_anchor(definition, &"street_start", Rect2i(47, 30, 2, 2))
	InteriorMapFactory.add_interaction_anchor(definition, &"smithy_door", Rect2i(41, 26, 2, 1))
	InteriorMapFactory.add_interaction_anchor(definition, &"brewery_door", Rect2i(32, 17, 2, 1))
	InteriorMapFactory.add_interaction_anchor(definition, &"checkpoint_west", Rect2i(3, 15, 2, 2))
	InteriorMapFactory.add_interaction_anchor(definition, &"checkpoint_east", Rect2i(53, 15, 2, 2))
	InteriorMapFactory.add_interaction_anchor(definition, &"katariina_kaik", Rect2i(34, 8, 2, 2))
	InteriorMapFactory.add_interaction_anchor(definition, &"monastery_gate", Rect2i(27, 7, 2, 1))
	InteriorMapFactory.add_interaction_anchor(definition, &"karja_lane_south", Rect2i(8, 33, 2, 2))

	InteriorMapFactory.add_transition(
		definition,
		&"smithy_door_transition",
		Rect2i(41, 26, 2, 1),
		&"forge",
		&"door_courtyard",
		&"forge",
		Vector2(0.0, 48.0)
	)
	InteriorMapFactory.add_transition(
		definition,
		&"street_start_spawn",
		Rect2i(47, 30, 2, 2),
		&"",
		&"",
		&"street_start"
	)

	# Viru Watch round: gate post, along Viru street, Vana turg, then the well.
	definition.patrols = [
		{
			"points": [
				definition.cell_rect_center(Rect2i(53, 15, 2, 2)),
				definition.cell_rect_center(Rect2i(28, 15, 2, 2)),
				definition.cell_rect_center(Rect2i(3, 15, 2, 2)),
				definition.cell_rect_center(Rect2i(49, 19, 2, 2)),
			]
		}
	]

	InteriorMapFactory.add_fade_volume(definition, Rect2i(20, 12, 32, 6))
	InteriorMapFactory.add_source_references(
		definition,
		[
			"scenes/reval_east/reval_east.tscn",
			"scenes/revel-map.jpg",
			"scenes/reval_walls_towers/wall-map.png",
			"scenes/reval_walls_towers/viru_gate.md",
			"docs/SCENES/the-makers-mark.md",
			"docs/SCENES/a-bitter-brew.md",
			"content/locations/loc.lower_town_slice.json",
		]
	)
	return definition
