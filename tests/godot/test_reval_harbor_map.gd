extends "res://tests/godot/test_case.gd"

const NORTH_RRMAP_PATH := "res://content/maps/reval_harbor_north.rrmap"
const EAST_RRMAP_PATH := "res://content/maps/reval_harbor_east.rrmap"
const HarborNorthDefinition := preload("res://scripts/map/definitions/outdoor/reval_harbor_north_definition.gd")
const HarborEastDefinition := preload("res://scripts/map/definitions/outdoor/reval_harbor_east_definition.gd")


func test_split_harbor_rrmaps_parse_and_match_1343_geography() -> void:
	var north := MapRrmapParser.parse_file(NORTH_RRMAP_PATH)
	assert_true(north.is_ok(), str(north.formatted_diagnostics()))
	if north.is_ok():
		assert_eq(north.blueprint.map_id, &"reval_harbor_north")
		assert_eq(north.definition.size_cells, Vector2i(160, 88))
		assert_eq(north.definition.surroundings_sides.get(&"north"), &"water")
		assert_eq(north.definition.surroundings_sides.get(&"east"), &"water")
	var east := MapRrmapParser.parse_file(EAST_RRMAP_PATH)
	assert_true(east.is_ok(), str(east.formatted_diagnostics()))
	if east.is_ok():
		assert_eq(east.blueprint.map_id, &"reval_harbor_east")
		assert_eq(east.definition.location, &"loc.reval_harbor.kalamaja")
		assert_eq(east.definition.size_cells, Vector2i(144, 80))
		assert_eq(east.definition.surroundings_sides.get(&"north"), &"water")
		assert_eq(east.definition.surroundings_sides.get(&"west"), &"water")
		assert_eq(east.definition.surroundings_sides.get(&"east"), &"woodland")


func test_harbors_keep_open_water_and_shallow_working_shores() -> void:
	for definition: MapDefinition in [HarborNorthDefinition.create(), HarborEastDefinition.create()]:
		var grid := MapBuilder.build(definition)
		assert_eq(
			grid.get_terrain(Vector2i(definition.size_cells.x / 2, 12)),
			MapTypes.TERRAIN_DEEP_WATER,
			"%s must keep open Baltic water for roadstead vessels" % String(definition.map_id)
		)
		assert_eq(
			grid.get_terrain(Vector2i(definition.size_cells.x / 2, 27)),
			MapTypes.TERRAIN_SHALLOW_WATER,
			"%s must approach the beach through authored shallows" % String(definition.map_id)
		)
		var view := MapView3D.create(definition, grid)
		assert_true(
			view.has_node("Surroundings/Water_north"),
			"%s must continue the Baltic basin northward" % String(definition.map_id)
		)
		assert_false(view.has_node("Surroundings/Apron"), "%s must not paint a default meadow apron" % String(definition.map_id))
		assert_false(view.has_node("Surroundings/TownSilhouette"), "%s must not fake a town skyline past the shore" % String(definition.map_id))
		assert_true(view.has_node("Surroundings/WoodlandApron_south"), "%s must green its landward edges" % String(definition.map_id))
		# The authored forest-floor pockets mask the actual off-limits land. A
		# transition side may preview its neighbor instead of adding exterior trees,
		# so inspect full-map scatter rather than requiring Surroundings/Trunks.
		var scatter := MapViewMeshBuilder.build_scatter(definition, grid)
		var authored_trunks := scatter.get_node_or_null("TreeTrunks") as MultiMeshInstance3D
		assert_true(authored_trunks != null, "%s must mask off-limits land with authored trees" % String(definition.map_id))
		if authored_trunks != null:
			assert_true(authored_trunks.multimesh.instance_count > 40, "%s needs a substantial forest screen, not a sparse border row" % String(definition.map_id))
		scatter.free()
		view.free()


func test_harbor_shores_do_not_scatter_reeds_or_cattails() -> void:
	for definition: MapDefinition in [HarborNorthDefinition.create(), HarborEastDefinition.create()]:
		var grid := MapBuilder.build(definition)
		var scatter := MapViewMeshBuilder.build_scatter(definition, grid)
		var reeds := scatter.get_node_or_null("Reeds") as MultiMeshInstance3D
		var cattails := scatter.get_node_or_null("BankCattails") as MultiMeshInstance3D
		assert_true(reeds == null or reeds.multimesh.instance_count == 0, "%s must not grow reed beds on the Baltic shore" % String(definition.map_id))
		assert_true(cattails == null or cattails.multimesh.instance_count == 0, "%s must not grow cattails on the Baltic shore" % String(definition.map_id))
		scatter.free()


func test_trade_harbor_has_merchant_boats_moored_on_water() -> void:
	var definition: MapDefinition = HarborNorthDefinition.create()
	var boats := _props_of_kind(definition, MapTypes.PROP_KIND_MERCHANT_BOAT)
	assert_eq(boats.size(), 4, "Trade Harbour keeps roadstead cogs in open water")
	_assert_props_stay_on_water(definition, boats)
	var landing_boats := _props_of_kind(definition, MapTypes.PROP_KIND_FISHING_BOAT)
	assert_eq(landing_boats.size(), 2, "Merchant landing needs small boats at the timber jetty tips")
	_assert_props_stay_on_water(definition, landing_boats)


func test_fishing_harbor_has_boats_moored_on_water() -> void:
	var definition: MapDefinition = HarborEastDefinition.create()
	var boats := _props_of_kind(definition, MapTypes.PROP_KIND_FISHING_BOAT)
	assert_eq(boats.size(), 6, "Fishing Harbour needs working boats at its three piers")
	_assert_props_stay_on_water(definition, boats)


func test_harbor_timber_landings_are_walkable_to_moored_boats() -> void:
	# Pier walls used to block movement; timber decks must reach the boat tips.
	var east: MapDefinition = HarborEastDefinition.create()
	var east_grid := MapBuilder.build(east)
	for cell in [Vector2i(26, 43), Vector2i(26, 24), Vector2i(64, 26), Vector2i(111, 27)]:
		assert_eq(east_grid.get_terrain(cell), MapTypes.TERRAIN_TIMBER_FLOOR, "Kalamaja pier cell %s" % cell)
		assert_true(MapVerification.is_walkable_cell(east, east_grid, cell), "Kalamaja pier must be walkable at %s" % cell)
	assert_true(
		MapVerification.route_exists_exact(
			east,
			east_grid,
			MapVerification.cell_center(east, Vector2i(26, 43)),
			MapVerification.cell_center(east, Vector2i(26, 24))
		),
		"Player must walk the west Kalamaja pier from shore to tip"
	)

	var north: MapDefinition = HarborNorthDefinition.create()
	var north_grid := MapBuilder.build(north)
	for cell in [Vector2i(57, 44), Vector2i(57, 27), Vector2i(113, 29)]:
		assert_eq(north_grid.get_terrain(cell), MapTypes.TERRAIN_TIMBER_FLOOR, "Landing pier cell %s" % cell)
		assert_true(MapVerification.is_walkable_cell(north, north_grid, cell), "Landing pier must be walkable at %s" % cell)
	assert_true(
		MapVerification.route_exists_exact(
			north,
			north_grid,
			MapVerification.cell_center(north, Vector2i(57, 44)),
			MapVerification.cell_center(north, Vector2i(57, 27))
		),
		"Player must walk the west merchant landing from shore to tip"
	)


func _props_of_kind(definition: MapDefinition, kind: StringName) -> Array[Dictionary]:
	var props: Array[Dictionary] = []
	for prop in definition.props:
		if prop.get("kind") == kind:
			props.append(prop)
	return props


func _assert_props_stay_on_water(definition: MapDefinition, props: Array[Dictionary]) -> void:
	var grid := MapBuilder.build(definition)
	for prop in props:
		assert_true(prop.has("footprint"), "%s must reserve an authored water footprint" % prop["id"])
		var footprint: Rect2 = prop["footprint"]
		var cell_rect := Rect2i(
			Vector2i(footprint.position / float(definition.cell_size)),
			Vector2i(footprint.size / float(definition.cell_size))
		)
		for y in range(cell_rect.position.y, cell_rect.end.y):
			for x in range(cell_rect.position.x, cell_rect.end.x):
				assert_true(
					MapTypes.WATER_TERRAINS.has(grid.get_terrain(Vector2i(x, y))),
					"%s must stay in the harbour basin" % prop["id"]
				)


func test_kalamaja_has_no_direct_workers_district_link() -> void:
	var definition: MapDefinition = HarborEastDefinition.create()
	for transition in definition.transitions:
		assert_ne(transition["destination_scene_id"], &"reval_east", "Kalamaja must not connect directly to Viru road")
	assert_false(DoorNavigator.has_spawn(&"reval_harbor_east", &"from_reval_east"))
	assert_true(DoorNavigator.has_spawn(&"reval_east", &"viru_road_boundary"))


func test_split_harbor_maps_connect_to_each_other() -> void:
	var north: MapDefinition = HarborNorthDefinition.create()
	var east: MapDefinition = HarborEastDefinition.create()
	var north_transitions: Dictionary = {}
	for transition in north.transitions:
		north_transitions[transition["id"]] = transition
	var east_transitions: Dictionary = {}
	for transition in east.transitions:
		east_transitions[transition["id"]] = transition
	assert_eq(north_transitions[&"to_harbor_east"]["destination_scene_id"], &"reval_harbor_east")
	assert_eq(north_transitions[&"to_harbor_east"]["destination_spawn_id"], &"from_harbor_north")
	assert_eq(east_transitions[&"to_harbor_north"]["destination_scene_id"], &"reval_harbor_north")
	assert_eq(east_transitions[&"to_harbor_north"]["destination_spawn_id"], &"from_harbor_east")


func test_lower_town_routes_to_viru_foreland_not_kalamaja() -> void:
	var definition: MapDefinition = preload(
		"res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd"
	).create()
	for transition in definition.transitions:
		if transition["id"] == &"viru_road_boundary":
			assert_eq(transition["destination_scene_id"], &"viru_gate_foreland")
			return
	push_error("viru_road_boundary transition missing")
