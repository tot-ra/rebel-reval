extends "res://tests/godot/test_case.gd"

const LowerTownSliceDefinition := preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapVerification := preload("res://scripts/map/map_verification.gd")


func test_lower_town_slice_validates() -> void:
	var definition: MapDefinition = LowerTownSliceDefinition.create()
	assert_eq(definition.size_cells, Vector2i(88, 56))
	var errors: Array[String] = MapBuilder.validate(definition)
	assert_true(errors.is_empty(), str(errors))


func test_lower_town_required_route_endpoints_reachable() -> void:
	var definition: MapDefinition = LowerTownSliceDefinition.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	var start := MapVerification.anchor_position(definition, &"street_start")
	var checks: Array[StringName] = [
		&"smithy_door",
		&"brewery_door",
		&"checkpoint_west",
		&"checkpoint_east",
		&"katariina_kaik",
		&"monastery_gate",
		&"karja_gate_south",
		&"vene_street_north",
	]
	for anchor_id in checks:
		assert_true(
			MapVerification.route_exists(definition, grid, start, MapVerification.anchor_position(definition, anchor_id)),
			"Missing route to %s" % String(anchor_id)
		)


func test_city_wall_blocks_except_viru_gate() -> void:
	var definition: MapDefinition = LowerTownSliceDefinition.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	# Wall cells north of the gate and along the south-west bend must block.
	assert_true(not MapVerification.is_walkable_cell(definition, grid, Vector2i(64, 8)), "north wall must block")
	assert_true(not MapVerification.is_walkable_cell(definition, grid, Vector2i(52, 35)), "south-east bend must block")
	assert_true(not MapVerification.is_walkable_cell(definition, grid, Vector2i(42, 45)), "south-west bend must block")
	assert_true(not MapVerification.is_walkable_cell(definition, grid, Vector2i(20, 48)), "south wall must block")
	# The moat outside the wall blocks except at the gate causeway.
	assert_true(not MapVerification.is_walkable_cell(definition, grid, Vector2i(71, 8)), "moat must block")
	assert_true(MapVerification.is_walkable_cell(definition, grid, Vector2i(71, 20)), "causeway must stay open")
	# The gate passage itself stays open from Viru street to the east road.
	var inside := definition.cell_rect_center(Rect2i(60, 20, 1, 1))
	var outside := definition.cell_rect_center(Rect2i(80, 20, 1, 1))
	assert_true(
		MapVerification.route_exists_exact(definition, grid, inside, outside),
		"Viru street must pass through the gate to the east road"
	)


func test_karja_gate_passage_stays_open() -> void:
	var definition: MapDefinition = LowerTownSliceDefinition.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	# Gate towers flanking the passage must block movement.
	assert_true(not MapVerification.is_walkable_cell(definition, grid, Vector2i(34, 48)), "west gate tower must block")
	assert_true(not MapVerification.is_walkable_cell(definition, grid, Vector2i(40, 48)), "east gate tower must block")
	# The passage and the causeway over the south moat stay open to the edge.
	var inside := definition.cell_rect_center(Rect2i(37, 45, 1, 1))
	var outside := definition.cell_rect_center(Rect2i(37, 54, 1, 1))
	assert_true(
		MapVerification.route_exists_exact(definition, grid, inside, outside),
		"Suur-Karja must pass through Karja Gate to the south road"
	)


func test_navigation_region_builds_despite_overlapping_wall_footprints() -> void:
	var definition: MapDefinition = LowerTownSliceDefinition.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	var region := MapNavBuilder.create_navigation_region(definition, grid)
	assert_true(
		region.navigation_polygon.get_polygon_count() > 0,
		"nav region must produce polygons even with overlapping tower/wall footprints"
	)
	region.free()


func test_boundary_exits_are_marked_without_activating_prototype_scenes() -> void:
	var definition: MapDefinition = LowerTownSliceDefinition.create()
	var transition_by_id: Dictionary = {}
	for transition in definition.transitions:
		transition_by_id[transition["id"]] = transition
	for transition_id: StringName in [
		&"vana_turg_boundary",
		&"vene_district_boundary",
		&"viru_road_boundary",
		&"karja_road_boundary",
	]:
		assert_true(transition_by_id.has(transition_id), "missing boundary transition %s" % transition_id)
		var transition: Dictionary = transition_by_id[transition_id]
		assert_true(bool(transition.get("highlight_area", false)), "%s must be visibly marked" % transition_id)
		assert_true(
			String(transition.get("destination_scene_id", "")).is_empty(),
			"%s must not activate an unapproved destination" % transition_id
		)


func test_courtyard_anvil_does_not_cover_smithy_door() -> void:
	var definition: MapDefinition = LowerTownSliceDefinition.create()
	var anvil_position := Vector2.ZERO
	for prop in definition.props:
		if prop["id"] == &"courtyard_anvil":
			anvil_position = prop["position"]
	var door_position := MapVerification.anchor_position(definition, &"smithy_door")
	assert_true(
		anvil_position.distance_to(door_position) > float(definition.cell_size * 2),
		"courtyard anvil must remain visually separate from the smithy door"
	)
