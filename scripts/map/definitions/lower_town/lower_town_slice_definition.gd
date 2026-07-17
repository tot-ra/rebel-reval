class_name LowerTownSliceDefinition
extends RefCounted

## Viru Gate quarter of the eastern Lower Town (P2-019, historical layout pass).
##
## Layout follows the real street plan of eastern Old Town Tallinn as read from
## `scenes/revel-map.jpg` (Tallinna vanalinna muinsuskaitseala heritage map) and
## `scenes/reval_walls_towers/wall-map.png`:
## - The town wall runs north-south past the later Hellemann site down to Viru
##   Gate ("Lehmporte", the main eastern gate of the 1310s Danish wall program),
##   then bends SOUTH-WEST through the Hinke and Kuradi tower sites toward Karja
##   Gate at the southern edge - the eastern quarter is enclosed on two sides,
##   not walled on one side only. Towers at the post-1343 Hellemann and
##   Kuraditorn sites render as unnamed plausible composites.
## - A wet moat follows the wall outside, bulging around the Viru foregate neck;
##   causeways cross it at both gates. Everything past the moat is open glacis.
## - Viru street runs east-west from the gate toward Vana turg (Old Market).
## - Muurivahe is the service lane hugging the inside of the wall the whole way
##   around the bend, continuing west from Karja Gate below the south wall.
## - Vene street runs north-south and leaves the quarter toward Pikk street;
##   St. Catherine's Passage (Katariina kaik) links it to Muurivahe along the
##   south flank of the Dominican monastery of St. Catherine (founded 1246).
## - Suur-Karja street runs south from Viru street to Karja Gate, with Kuninga
##   and Vaike-Karja crossing the artisan quarter between them.
## - Smiths and fire-risk trades cluster against the wall south of Viru Gate,
##   which is where Kalev's smithy courtyard sits.
## - Streets that continue into neighbouring districts (west to Vana turg /
##   town centre, north along Vene street) end under district boundary arches
##   with buildings built flush to the map edge, so closed districts read as
##   more town rather than empty free-roam ground.


static func create() -> MapDefinition:
	var definition := MapDefinition.new()
	InteriorMapFactory.init_definition(
		definition,
		&"lower_town_slice",
		&"loc.lower_town_slice",
		&"production",
		true,
		&"clean_painted",
		Vector2i(88, 56),
		MapTypes.TERRAIN_DIRT,
		"lower_town_slice_v6_historical_east_quarter",
		Rect2i(48, 20, 2, 2)
	)

	definition.zones = [
		# Extramural ground: glacis east of the wall and south past Karja Gate.
		{"terrain": MapTypes.TERRAIN_GRASS, "rect": Rect2i(66, 0, 22, 50)},
		{"terrain": MapTypes.TERRAIN_GRASS, "rect": Rect2i(0, 50, 88, 6)},
		# Monastery precinct green and the gardens between it and the wall.
		{"terrain": MapTypes.TERRAIN_GRASS, "rect": Rect2i(18, 0, 26, 7)},
		{"terrain": MapTypes.TERRAIN_GRASS, "rect": Rect2i(44, 0, 16, 8)},
		# Rear gardens of the south-west artisan quarter and the west lane.
		{"terrain": MapTypes.TERRAIN_GRASS, "rect": Rect2i(9, 38, 26, 8)},
		{"terrain": MapTypes.TERRAIN_GRASS, "rect": Rect2i(4, 36, 5, 10)},
		{"terrain": MapTypes.TERRAIN_GRASS, "rect": Rect2i(44, 28, 6, 10)},
		# Glacis outside the wall bend; the moat zones below cut through it.
		{"terrain": MapTypes.TERRAIN_GRASS, "rect": Rect2i(54, 32, 12, 8)},
		{"terrain": MapTypes.TERRAIN_GRASS, "rect": Rect2i(44, 40, 22, 10)},
		# Wet moat following the wall: straight along the north-east stretch,
		# bulging around the Viru foregate, then stepping south-west with the
		# wall bend until it joins the southern ditch before Karja Gate.
		{"terrain": MapTypes.TERRAIN_WATER, "rect": Rect2i(70, 0, 3, 16)},
		{"terrain": MapTypes.TERRAIN_WATER, "rect": Rect2i(70, 14, 5, 2)},
		{"terrain": MapTypes.TERRAIN_WATER, "rect": Rect2i(73, 16, 3, 10)},
		{"terrain": MapTypes.TERRAIN_WATER, "rect": Rect2i(70, 25, 5, 2)},
		{"terrain": MapTypes.TERRAIN_WATER, "rect": Rect2i(70, 27, 3, 7)},
		{"terrain": MapTypes.TERRAIN_WATER, "rect": Rect2i(64, 32, 7, 3)},
		{"terrain": MapTypes.TERRAIN_WATER, "rect": Rect2i(58, 35, 7, 3)},
		{"terrain": MapTypes.TERRAIN_WATER, "rect": Rect2i(56, 38, 5, 3)},
		{"terrain": MapTypes.TERRAIN_WATER, "rect": Rect2i(52, 41, 6, 3)},
		{"terrain": MapTypes.TERRAIN_WATER, "rect": Rect2i(48, 44, 5, 3)},
		{"terrain": MapTypes.TERRAIN_WATER, "rect": Rect2i(46, 47, 4, 3)},
		{"terrain": MapTypes.TERRAIN_WATER, "rect": Rect2i(44, 50, 4, 3)},
		{"terrain": MapTypes.TERRAIN_WATER, "rect": Rect2i(0, 52, 88, 2)},
		# Causeways over the moat: the east road out of Viru Gate and the south
		# road out of Karja Gate.
		{"terrain": MapTypes.TERRAIN_DIRT, "rect": Rect2i(66, 19, 22, 3)},
		{"terrain": MapTypes.TERRAIN_DIRT, "rect": Rect2i(36, 50, 3, 6)},
		# Viru street: the paved main axis from Vana turg to Viru Gate, with
		# stone paving through the gate passage and foregate neck.
		{"terrain": MapTypes.TERRAIN_COBBLESTONE, "rect": Rect2i(0, 19, 58, 4)},
		{"terrain": MapTypes.TERRAIN_STONE, "rect": Rect2i(58, 19, 9, 3)},
		# Vana turg widens where Viru street meets the market quarter.
		{"terrain": MapTypes.TERRAIN_COBBLESTONE, "rect": Rect2i(0, 14, 9, 13)},
		# Vene street north-south, and St. Catherine's Passage east-west.
		{"terrain": MapTypes.TERRAIN_COBBLESTONE, "rect": Rect2i(14, 0, 3, 19)},
		{"terrain": MapTypes.TERRAIN_STONE, "rect": Rect2i(14, 8, 46, 2)},
		# Suur-Karja south to Karja Gate, with the gate square and stone passage.
		{"terrain": MapTypes.TERRAIN_COBBLESTONE, "rect": Rect2i(36, 23, 3, 24)},
		{"terrain": MapTypes.TERRAIN_COBBLESTONE, "rect": Rect2i(33, 44, 9, 3)},
		{"terrain": MapTypes.TERRAIN_STONE, "rect": Rect2i(36, 47, 3, 3)},
		# Kuninga and Vaike-Karja cross streets of the artisan quarter.
		{"terrain": MapTypes.TERRAIN_COBBLESTONE, "rect": Rect2i(9, 27, 17, 2)},
		{"terrain": MapTypes.TERRAIN_COBBLESTONE, "rect": Rect2i(8, 32, 28, 2)},
		# Smithy work yard hay store and a churned stretch of lower Muurivahe.
		{"terrain": MapTypes.TERRAIN_HAY, "rect": Rect2i(50, 28, 2, 2)},
		{"terrain": MapTypes.TERRAIN_MUD, "rect": Rect2i(18, 46, 4, 2)},
	]

	definition.buildings = [
		# Town wall north of Viru Gate with square towers (the pre-1355 wall
		# program silhouette); the tower at the later Hellemann site renders as
		# an unnamed composite.
		{"id": &"city_wall_north", "kind": MapTypes.BUILDING_KIND_WALL, "footprint": definition.cell_rect_to_world_rect(Rect2i(64, 0, 2, 15)), "wall_height": 192.0, "wall_color": Color(0.58, 0.57, 0.52)},
		{"id": &"wall_tower_northeast", "kind": MapTypes.BUILDING_KIND_WALL, "footprint": definition.cell_rect_to_world_rect(Rect2i(63, 2, 4, 3)), "wall_height": 240.0, "wall_color": Color(0.55, 0.54, 0.50)},
		{"id": &"wall_tower_north", "kind": MapTypes.BUILDING_KIND_WALL, "footprint": definition.cell_rect_to_world_rect(Rect2i(63, 9, 4, 3)), "wall_height": 240.0, "wall_color": Color(0.55, 0.54, 0.50)},
		# Viru Gate: flanking tower masses, the walled foregate neck funneling
		# the road to the moat bridge, and outer foregate towers.
		{"id": &"viru_gate_north_tower", "kind": MapTypes.BUILDING_KIND_WALL, "footprint": definition.cell_rect_to_world_rect(Rect2i(62, 15, 5, 4)), "wall_height": 256.0, "wall_color": Color(0.56, 0.55, 0.50)},
		{"id": &"viru_gate_south_tower", "kind": MapTypes.BUILDING_KIND_WALL, "footprint": definition.cell_rect_to_world_rect(Rect2i(62, 22, 5, 4)), "wall_height": 256.0, "wall_color": Color(0.56, 0.55, 0.50)},
		{"id": &"foregate_wall_north", "kind": MapTypes.BUILDING_KIND_WALL, "footprint": definition.cell_rect_to_world_rect(Rect2i(67, 18, 6, 1)), "wall_height": 128.0, "wall_color": Color(0.57, 0.56, 0.51)},
		{"id": &"foregate_wall_south", "kind": MapTypes.BUILDING_KIND_WALL, "footprint": definition.cell_rect_to_world_rect(Rect2i(67, 22, 6, 1)), "wall_height": 128.0, "wall_color": Color(0.57, 0.56, 0.51)},
		{"id": &"foregate_tower_north", "kind": MapTypes.BUILDING_KIND_WALL, "footprint": definition.cell_rect_to_world_rect(Rect2i(72, 16, 3, 3)), "wall_height": 176.0, "wall_color": Color(0.56, 0.55, 0.50)},
		{"id": &"foregate_tower_south", "kind": MapTypes.BUILDING_KIND_WALL, "footprint": definition.cell_rect_to_world_rect(Rect2i(72, 22, 3, 3)), "wall_height": 176.0, "wall_color": Color(0.56, 0.55, 0.50)},
		# South of the gate the wall bends south-west toward Karja Gate: straight
		# segments between towers, direction changing at each tower, exactly as
		# the wall map draws the Hinke torn / Kuraditorn stretch.
		{"id": &"city_wall_gate_south", "kind": MapTypes.BUILDING_KIND_WALL, "footprint": definition.cell_rect_to_world_rect(Rect2i(63, 26, 2, 4)), "wall_height": 192.0, "wall_color": Color(0.58, 0.57, 0.52)},
		{"id": &"hinke_tower", "kind": MapTypes.BUILDING_KIND_WALL, "footprint": definition.cell_rect_to_world_rect(Rect2i(60, 29, 4, 4)), "wall_height": 240.0, "wall_color": Color(0.55, 0.54, 0.50)},
		{"id": &"city_wall_bend_a", "kind": MapTypes.BUILDING_KIND_WALL, "footprint": definition.cell_rect_to_world_rect(Rect2i(55, 30, 5, 2)), "wall_height": 192.0, "wall_color": Color(0.58, 0.57, 0.52)},
		{"id": &"wall_tower_southeast", "kind": MapTypes.BUILDING_KIND_WALL, "footprint": definition.cell_rect_to_world_rect(Rect2i(52, 30, 3, 4)), "wall_height": 240.0, "wall_color": Color(0.55, 0.54, 0.50)},
		{"id": &"city_wall_bend_b", "kind": MapTypes.BUILDING_KIND_WALL, "footprint": definition.cell_rect_to_world_rect(Rect2i(52, 34, 2, 5)), "wall_height": 192.0, "wall_color": Color(0.58, 0.57, 0.52)},
		{"id": &"wall_tower_south", "kind": MapTypes.BUILDING_KIND_WALL, "footprint": definition.cell_rect_to_world_rect(Rect2i(50, 37, 4, 4)), "wall_height": 240.0, "wall_color": Color(0.55, 0.54, 0.50)},
		{"id": &"city_wall_bend_c", "kind": MapTypes.BUILDING_KIND_WALL, "footprint": definition.cell_rect_to_world_rect(Rect2i(44, 38, 6, 2)), "wall_height": 192.0, "wall_color": Color(0.58, 0.57, 0.52)},
		{"id": &"wall_tower_southwest", "kind": MapTypes.BUILDING_KIND_WALL, "footprint": definition.cell_rect_to_world_rect(Rect2i(42, 38, 3, 4)), "wall_height": 240.0, "wall_color": Color(0.55, 0.54, 0.50)},
		{"id": &"city_wall_bend_d", "kind": MapTypes.BUILDING_KIND_WALL, "footprint": definition.cell_rect_to_world_rect(Rect2i(42, 42, 2, 6)), "wall_height": 192.0, "wall_color": Color(0.58, 0.57, 0.52)},
		# Karja Gate: attested medieval south gate with its own suburb beyond
		# the moat; the wall continues west past the map edge toward Harju Gate.
		{"id": &"karja_gate_east_tower", "kind": MapTypes.BUILDING_KIND_WALL, "footprint": definition.cell_rect_to_world_rect(Rect2i(39, 47, 4, 4)), "wall_height": 256.0, "wall_color": Color(0.56, 0.55, 0.50)},
		{"id": &"karja_gate_west_tower", "kind": MapTypes.BUILDING_KIND_WALL, "footprint": definition.cell_rect_to_world_rect(Rect2i(32, 47, 4, 4)), "wall_height": 256.0, "wall_color": Color(0.56, 0.55, 0.50)},
		{"id": &"city_wall_southwest", "kind": MapTypes.BUILDING_KIND_WALL, "footprint": definition.cell_rect_to_world_rect(Rect2i(0, 48, 32, 2)), "wall_height": 192.0, "wall_color": Color(0.58, 0.57, 0.52)},
		# Dominican monastery of St. Catherine north of the passage.
		{"id": &"st_catherines_church", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(20, 1, 12, 5)), "wall_height": 192.0, "wall_color": Color(0.66, 0.64, 0.58), "roof_color": Color(0.30, 0.16, 0.12), "door_side": &"south"},
		{"id": &"monastery_cloister", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(33, 0, 9, 6)), "wall_height": 128.0, "wall_color": Color(0.62, 0.60, 0.55), "roof_color": Color(0.28, 0.16, 0.12), "door_side": &"south"},
		{"id": &"monastery_precinct_wall_west", "kind": MapTypes.BUILDING_KIND_WALL, "footprint": definition.cell_rect_to_world_rect(Rect2i(18, 0, 1, 7)), "wall_height": 96.0, "wall_color": Color(0.60, 0.58, 0.53)},
		{"id": &"monastery_precinct_wall_south_a", "kind": MapTypes.BUILDING_KIND_WALL, "footprint": definition.cell_rect_to_world_rect(Rect2i(18, 7, 9, 1)), "wall_height": 96.0, "wall_color": Color(0.60, 0.58, 0.53)},
		{"id": &"monastery_precinct_wall_south_b", "kind": MapTypes.BUILDING_KIND_WALL, "footprint": definition.cell_rect_to_world_rect(Rect2i(30, 7, 14, 1)), "wall_height": 96.0, "wall_color": Color(0.60, 0.58, 0.53)},
		{"id": &"monastery_barn", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(46, 2, 4, 3)), "wall_height": 96.0, "wall_color": Color(0.44, 0.40, 0.34), "roof_color": Color(0.24, 0.20, 0.16), "door_side": &"south"},
		# North-west block between the map edge and Vene street: the town keeps
		# going toward Pikk street, so the houses sit flush against both edges.
		{"id": &"pikk_corner_house", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(0, 0, 5, 4)), "wall_height": 120.0, "wall_color": Color(0.44, 0.40, 0.34), "roof_color": Color(0.24, 0.20, 0.16), "door_side": &"south"},
		{"id": &"vene_row_house", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(6, 0, 5, 4)), "wall_height": 120.0, "wall_color": Color(0.42, 0.38, 0.31), "roof_color": Color(0.23, 0.20, 0.17), "door_side": &"south"},
		{"id": &"vene_corner_house", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(11, 0, 3, 4)), "wall_height": 112.0, "wall_color": Color(0.40, 0.36, 0.30), "roof_color": Color(0.22, 0.20, 0.18), "door_side": &"east"},
		{"id": &"market_row_house", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(0, 5, 4, 5)), "wall_height": 112.0, "wall_color": Color(0.41, 0.37, 0.31), "roof_color": Color(0.23, 0.20, 0.17), "door_side": &"east"},
		{"id": &"saiakang_house", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(5, 5, 5, 5)), "wall_height": 120.0, "wall_color": Color(0.46, 0.40, 0.33), "roof_color": Color(0.26, 0.21, 0.16), "door_side": &"west"},
		{"id": &"vene_gate_house", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(11, 5, 3, 5)), "wall_height": 112.0, "wall_color": Color(0.40, 0.36, 0.30), "roof_color": Color(0.22, 0.19, 0.16), "door_side": &"east"},
		{"id": &"apothecary_house", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(0, 10, 4, 4)), "wall_height": 128.0, "wall_color": Color(0.50, 0.45, 0.38), "roof_color": Color(0.26, 0.15, 0.12), "door_side": &"south"},
		{"id": &"turg_house_north", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(5, 10, 4, 4)), "wall_height": 112.0, "wall_color": Color(0.42, 0.37, 0.31), "roof_color": Color(0.24, 0.20, 0.16), "door_side": &"south"},
		{"id": &"moneychangers_house", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(10, 10, 4, 4)), "wall_height": 120.0, "wall_color": Color(0.46, 0.42, 0.36), "roof_color": Color(0.25, 0.21, 0.16), "door_side": &"east"},
		{"id": &"vanaturu_kael_house", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(9, 15, 5, 4)), "wall_height": 120.0, "wall_color": Color(0.44, 0.39, 0.32), "roof_color": Color(0.24, 0.20, 0.16), "door_side": &"south"},
		# Row of narrow Hanseatic plots between St. Catherine's Passage and Viru
		# street, gable ends turned to the street, alley at the block's middle.
		{"id": &"kaik_house_west", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(18, 10, 6, 4)), "wall_height": 112.0, "wall_color": Color(0.42, 0.37, 0.31), "roof_color": Color(0.24, 0.20, 0.16), "door_side": &"north"},
		{"id": &"kaik_house_mid", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(25, 10, 6, 4)), "wall_height": 120.0, "wall_color": Color(0.46, 0.40, 0.33), "roof_color": Color(0.26, 0.21, 0.16), "door_side": &"north"},
		{"id": &"kaik_house_east", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(34, 10, 6, 4)), "wall_height": 112.0, "wall_color": Color(0.41, 0.37, 0.31), "roof_color": Color(0.23, 0.20, 0.17), "door_side": &"north"},
		{"id": &"guild_storehouse", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(41, 10, 6, 4)), "wall_height": 136.0, "wall_color": Color(0.52, 0.48, 0.42), "roof_color": Color(0.26, 0.14, 0.11), "door_side": &"north", "ridge_axis": &"z"},
		{"id": &"glovers_house", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(48, 10, 5, 4)), "wall_height": 112.0, "wall_color": Color(0.40, 0.36, 0.30), "roof_color": Color(0.22, 0.20, 0.18), "door_side": &"north"},
		{"id": &"corner_house_muurivahe", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(54, 10, 5, 4)), "wall_height": 128.0, "wall_color": Color(0.50, 0.46, 0.40), "roof_color": Color(0.26, 0.15, 0.12), "door_side": &"east"},
		{"id": &"viru_house_west", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(18, 15, 6, 4)), "wall_height": 120.0, "wall_color": Color(0.44, 0.40, 0.34), "roof_color": Color(0.24, 0.20, 0.16), "door_side": &"south", "ridge_axis": &"z"},
		{"id": &"viru_house_mid", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(25, 14, 7, 5)), "wall_height": 128.0, "wall_color": Color(0.48, 0.43, 0.36), "roof_color": Color(0.26, 0.15, 0.12), "door_side": &"south"},
		{"id": &"viru_house_stone", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(34, 15, 6, 4)), "wall_height": 128.0, "wall_color": Color(0.52, 0.50, 0.46), "roof_color": Color(0.26, 0.14, 0.11), "door_side": &"south", "ridge_axis": &"z"},
		{"id": &"merchants_house", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(41, 14, 6, 5)), "wall_height": 136.0, "wall_color": Color(0.50, 0.46, 0.40), "roof_color": Color(0.26, 0.15, 0.12), "door_side": &"south"},
		{"id": &"viru_house_east", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(48, 15, 5, 4)), "wall_height": 112.0, "wall_color": Color(0.41, 0.37, 0.31), "roof_color": Color(0.23, 0.20, 0.17), "door_side": &"south"},
		{"id": &"weary_traveler_inn", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(54, 15, 5, 4)), "wall_height": 120.0, "wall_color": Color(0.43, 0.38, 0.31), "roof_color": Color(0.25, 0.21, 0.16), "door_side": &"south"},
		# South side of Viru street west of Suur-Karja: artisan houses fronting
		# the street, Sauna lane cutting through the block.
		{"id": &"saddlers_house", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(9, 23, 5, 4)), "wall_height": 112.0, "wall_color": Color(0.40, 0.36, 0.30), "roof_color": Color(0.22, 0.20, 0.18), "door_side": &"north"},
		{"id": &"coopers_house", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(15, 23, 5, 4)), "wall_height": 112.0, "wall_color": Color(0.42, 0.38, 0.31), "roof_color": Color(0.23, 0.20, 0.17), "door_side": &"north"},
		{"id": &"sauna_corner_house", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(20, 23, 4, 4)), "wall_height": 104.0, "wall_color": Color(0.39, 0.35, 0.29), "roof_color": Color(0.22, 0.19, 0.16), "door_side": &"north"},
		{"id": &"rope_makers_house", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(26, 23, 5, 4)), "wall_height": 112.0, "wall_color": Color(0.41, 0.37, 0.31), "roof_color": Color(0.23, 0.20, 0.17), "door_side": &"north"},
		{"id": &"karja_corner_house", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(31, 23, 5, 4)), "wall_height": 120.0, "wall_color": Color(0.46, 0.42, 0.36), "roof_color": Color(0.25, 0.21, 0.16), "door_side": &"north"},
		{"id": &"kuninga_house_west", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(9, 29, 5, 3)), "wall_height": 104.0, "wall_color": Color(0.39, 0.35, 0.30), "roof_color": Color(0.22, 0.20, 0.17), "door_side": &"north"},
		{"id": &"kuninga_house_mid", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(15, 29, 5, 3)), "wall_height": 104.0, "wall_color": Color(0.38, 0.34, 0.29), "roof_color": Color(0.22, 0.19, 0.16), "door_side": &"north"},
		{"id": &"kuninga_house_east", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(20, 29, 4, 3)), "wall_height": 104.0, "wall_color": Color(0.40, 0.36, 0.30), "roof_color": Color(0.22, 0.20, 0.18), "door_side": &"north"},
		{"id": &"public_bathhouse", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(26, 29, 5, 3)), "wall_height": 120.0, "wall_color": Color(0.46, 0.42, 0.36), "roof_color": Color(0.25, 0.21, 0.16), "door_side": &"west"},
		{"id": &"vaike_karja_house", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(31, 29, 5, 3)), "wall_height": 112.0, "wall_color": Color(0.42, 0.38, 0.31), "roof_color": Color(0.23, 0.20, 0.17), "door_side": &"south"},
		# Tenement row south of Vaike-Karja with rear gardens running to the
		# Muurivahe lane below the south wall.
		{"id": &"tenement_row", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(9, 34, 5, 4)), "wall_height": 112.0, "wall_color": Color(0.40, 0.36, 0.30), "roof_color": Color(0.22, 0.20, 0.18), "door_side": &"north"},
		{"id": &"laundress_house", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(15, 34, 5, 4)), "wall_height": 104.0, "wall_color": Color(0.38, 0.34, 0.29), "roof_color": Color(0.22, 0.19, 0.16), "door_side": &"north"},
		{"id": &"widows_house", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(21, 34, 5, 4)), "wall_height": 104.0, "wall_color": Color(0.39, 0.35, 0.30), "roof_color": Color(0.22, 0.20, 0.17), "door_side": &"north"},
		{"id": &"dyers_house", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(27, 34, 5, 4)), "wall_height": 104.0, "wall_color": Color(0.40, 0.36, 0.30), "roof_color": Color(0.23, 0.20, 0.17), "door_side": &"north"},
		{"id": &"karja_gate_house", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(33, 34, 3, 4)), "wall_height": 104.0, "wall_color": Color(0.39, 0.35, 0.29), "roof_color": Color(0.22, 0.19, 0.16), "door_side": &"east"},
		# West-edge houses south of Vana turg: the town continues toward the
		# Vana-Posti quarter past the map boundary.
		{"id": &"turg_south_house", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(0, 27, 4, 4)), "wall_height": 112.0, "wall_color": Color(0.41, 0.37, 0.31), "roof_color": Color(0.23, 0.20, 0.17), "door_side": &"east"},
		{"id": &"west_lane_house", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(0, 32, 4, 4)), "wall_height": 104.0, "wall_color": Color(0.39, 0.35, 0.30), "roof_color": Color(0.22, 0.20, 0.17), "door_side": &"east"},
		{"id": &"hedge_house", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(0, 37, 4, 4)), "wall_height": 104.0, "wall_color": Color(0.38, 0.34, 0.29), "roof_color": Color(0.22, 0.19, 0.16), "door_side": &"east"},
		{"id": &"wall_side_house", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(0, 42, 4, 4)), "wall_height": 96.0, "wall_color": Color(0.37, 0.33, 0.28), "roof_color": Color(0.21, 0.19, 0.16), "door_side": &"east"},
		# Sheds in the garden pocket between Suur-Karja and the wall bend.
		{"id": &"artisan_shed", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(44, 29, 4, 3)), "wall_height": 96.0, "wall_color": Color(0.37, 0.33, 0.28), "roof_color": Color(0.21, 0.19, 0.16), "door_side": &"north"},
		{"id": &"potters_house", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(44, 33, 4, 3)), "wall_height": 104.0, "wall_color": Color(0.39, 0.35, 0.29), "roof_color": Color(0.22, 0.19, 0.16), "door_side": &"north"},
		# East of Suur-Karja fronting Viru street: the gate-quarter houses,
		# brewery, and Kalev's smithy with its walled work yard against the wall.
		{"id": &"glassblowers_house", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(39, 23, 4, 4)), "wall_height": 112.0, "wall_color": Color(0.40, 0.36, 0.30), "roof_color": Color(0.22, 0.20, 0.18), "door_side": &"north"},
		{"id": &"foaming_mug_brewery", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(44, 23, 6, 4)), "wall_height": 120.0, "wall_color": Color(0.38, 0.32, 0.26), "roof_color": Color(0.24, 0.20, 0.16), "door_side": &"north"},
		# The smithy's entry renders as the framed transition door, so the
		# facade generator only adds windows here.
		{"id": &"kalev_smithy", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(50, 23, 5, 4)), "wall_height": 128.0, "wall_color": Color(0.34, 0.30, 0.26), "roof_color": Color(0.22, 0.20, 0.18), "door_side": &"none"},
		{"id": &"smithy_yard_fence_north", "kind": MapTypes.BUILDING_KIND_WALL, "footprint": definition.cell_rect_to_world_rect(Rect2i(55, 23, 2, 1)), "wall_height": 56.0, "wall_color": Color(0.48, 0.50, 0.54)},
		{"id": &"smithy_yard_fence_east", "kind": MapTypes.BUILDING_KIND_WALL, "footprint": definition.cell_rect_to_world_rect(Rect2i(59, 23, 1, 5)), "wall_height": 56.0, "wall_color": Color(0.48, 0.50, 0.54)},
		# Houses sealing the Muurivahe lane where it leaves the quarter north.
		{"id": &"muurivahe_house_north", "kind": MapTypes.BUILDING_KIND_HOUSE, "footprint": definition.cell_rect_to_world_rect(Rect2i(58, 0, 5, 3)), "wall_height": 104.0, "wall_color": Color(0.40, 0.36, 0.30), "roof_color": Color(0.22, 0.20, 0.18), "door_side": &"south"},
	]

	definition.view_landmarks = [
		# Arches bridging the two real gate passages and the foregate mouth; the
		# roads beneath stay fully walkable.
		{"id": &"viru_gate_arch", "kind": &"gate_arch", "rect": definition.cell_rect_to_world_rect(Rect2i(62, 19, 5, 3)), "wall_color": Color(0.56, 0.55, 0.50), "top_px": 256.0},
		{"id": &"viru_foregate_arch", "kind": &"gate_arch", "rect": definition.cell_rect_to_world_rect(Rect2i(72, 19, 3, 3)), "wall_color": Color(0.56, 0.55, 0.50), "top_px": 176.0},
		{"id": &"karja_gate_arch", "kind": &"gate_arch", "rect": definition.cell_rect_to_world_rect(Rect2i(36, 47, 3, 4)), "wall_color": Color(0.56, 0.55, 0.50), "top_px": 256.0},
		# District boundary arches where streets continue into closed districts:
		# they mark the edge of the playable quarter instead of open ground.
		{"id": &"vanaturu_kael_arch", "kind": &"gate_arch", "rect": definition.cell_rect_to_world_rect(Rect2i(0, 19, 2, 4)), "wall_color": Color(0.52, 0.50, 0.46), "top_px": 160.0},
		{"id": &"vene_district_arch", "kind": &"gate_arch", "rect": definition.cell_rect_to_world_rect(Rect2i(14, 0, 3, 2)), "wall_color": Color(0.52, 0.50, 0.46), "top_px": 160.0},
	]

	# Reval continues north (Pikk street quarter) and west (town centre); east
	# and south lie beyond the wall and moat, so open glacis begins there.
	definition.surroundings_town_sides = [&"north", &"west"]

	definition.props = [
		# Smithy work yard.
		{"id": &"courtyard_anvil", "kind": MapTypes.PROP_KIND_ANVIL, "position": definition.cell_rect_center(Rect2i(56, 24, 2, 2))},
		{"id": &"courtyard_furnace", "kind": MapTypes.PROP_KIND_FURNACE, "position": definition.cell_rect_center(Rect2i(55, 27, 2, 2))},
		{"id": &"courtyard_quench", "kind": MapTypes.PROP_KIND_QUENCH, "position": definition.cell_rect_center(Rect2i(57, 28, 1, 1))},
		{"id": &"hay_store", "kind": MapTypes.PROP_KIND_HAY_STACK, "position": definition.cell_rect_center(Rect2i(50, 28, 2, 2))},
		# Public cistern on Muurivahe by the gate corner and the monastery well.
		{"id": &"cistern", "kind": MapTypes.PROP_KIND_WELL, "position": definition.cell_rect_center(Rect2i(60, 22, 2, 2))},
		{"id": &"monastery_well", "kind": MapTypes.PROP_KIND_WELL, "position": definition.cell_rect_center(Rect2i(42, 4, 2, 2))},
		# Street dressing: gate market, Vana turg market, and street traffic.
		{"id": &"market_stall_gate", "kind": MapTypes.PROP_KIND_STALL, "position": definition.cell_rect_center(Rect2i(59, 22, 2, 1))},
		{"id": &"market_stall_turg_north", "kind": MapTypes.PROP_KIND_STALL, "position": definition.cell_rect_center(Rect2i(3, 16, 2, 2))},
		{"id": &"market_stall_turg_south", "kind": MapTypes.PROP_KIND_STALL, "position": definition.cell_rect_center(Rect2i(6, 23, 2, 2))},
		{"id": &"street_cart", "kind": MapTypes.PROP_KIND_CART, "position": definition.cell_rect_center(Rect2i(28, 21, 2, 2))},
		{"id": &"gate_cart", "kind": MapTypes.PROP_KIND_CART, "position": definition.cell_rect_center(Rect2i(68, 20, 2, 2))},
		{"id": &"yard_cart", "kind": MapTypes.PROP_KIND_CART, "position": definition.cell_rect_center(Rect2i(46, 31, 2, 2))},
		# Brewery yard.
		{"id": &"brewery_barrels", "kind": MapTypes.PROP_KIND_BARRELS, "position": definition.cell_rect_center(Rect2i(44, 27, 2, 1))},
		{"id": &"evidence_barrels", "kind": MapTypes.PROP_KIND_BARRELS, "position": definition.cell_rect_center(Rect2i(46, 28, 2, 2))},
	]

	InteriorMapFactory.add_interaction_anchor(definition, &"street_start", Rect2i(48, 20, 2, 2))
	InteriorMapFactory.add_interaction_anchor(definition, &"smithy_door", Rect2i(51, 27, 2, 1))
	InteriorMapFactory.add_interaction_anchor(definition, &"brewery_door", Rect2i(45, 22, 2, 1))
	InteriorMapFactory.add_interaction_anchor(definition, &"checkpoint_west", Rect2i(2, 19, 2, 2))
	InteriorMapFactory.add_interaction_anchor(definition, &"checkpoint_east", Rect2i(63, 19, 2, 2))
	InteriorMapFactory.add_interaction_anchor(definition, &"katariina_kaik", Rect2i(34, 8, 2, 2))
	InteriorMapFactory.add_interaction_anchor(definition, &"monastery_gate", Rect2i(27, 6, 2, 2))
	InteriorMapFactory.add_interaction_anchor(definition, &"karja_gate_south", Rect2i(36, 49, 2, 2))
	InteriorMapFactory.add_interaction_anchor(definition, &"vene_street_north", Rect2i(14, 1, 2, 2))

	InteriorMapFactory.add_transition(
		definition,
		&"smithy_door_transition",
		Rect2i(51, 27, 2, 1),
		&"forge",
		&"door_courtyard",
		&"forge",
		Vector2(0.0, 48.0),
		true
	)
	# These marked boundary exits deliberately have no destination until their
	# inactive district prototypes pass the activation gate. They communicate the
	# intended level seams without making decorative surroundings traversable.
	InteriorMapFactory.add_transition(
		definition,
		&"vana_turg_boundary",
		Rect2i(0, 19, 2, 4),
		&"",
		&"",
		&"",
		Vector2.ZERO,
		true
	)
	InteriorMapFactory.add_transition(
		definition,
		&"vene_district_boundary",
		Rect2i(14, 0, 3, 2),
		&"",
		&"",
		&"",
		Vector2.ZERO,
		true
	)
	InteriorMapFactory.add_transition(
		definition,
		&"viru_road_boundary",
		Rect2i(84, 19, 4, 3),
		&"",
		&"",
		&"",
		Vector2.ZERO,
		true
	)
	InteriorMapFactory.add_transition(
		definition,
		&"karja_road_boundary",
		Rect2i(36, 53, 3, 3),
		&"",
		&"",
		&"",
		Vector2.ZERO,
		true
	)
	InteriorMapFactory.add_transition(
		definition,
		&"street_start_spawn",
		Rect2i(48, 20, 2, 2),
		&"",
		&"",
		&"street_start"
	)

	# Viru Watch round: gate post, along Viru street, Vana turg, then down
	# Suur-Karja to the Karja Gate post.
	definition.patrols = [
		{
			"points": [
				definition.cell_rect_center(Rect2i(63, 19, 2, 2)),
				definition.cell_rect_center(Rect2i(29, 19, 2, 2)),
				definition.cell_rect_center(Rect2i(3, 19, 2, 2)),
				definition.cell_rect_center(Rect2i(36, 29, 2, 2)),
				definition.cell_rect_center(Rect2i(36, 44, 2, 2)),
			]
		}
	]

	InteriorMapFactory.add_fade_volume(definition, Rect2i(10, 17, 44, 8))
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
