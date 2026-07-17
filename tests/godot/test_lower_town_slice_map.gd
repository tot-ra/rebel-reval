extends "res://tests/godot/test_case.gd"

const LowerTownSliceDefinition := preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapVerification := preload("res://scripts/map/map_verification.gd")


func test_lower_town_slice_validates() -> void:
	var definition: MapDefinition = LowerTownSliceDefinition.create()
	assert_eq(definition.size_cells, Vector2i(64, 36))
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
		&"karja_lane_south",
	]
	for anchor_id in checks:
		assert_true(
			MapVerification.route_exists(definition, grid, start, MapVerification.anchor_position(definition, anchor_id)),
			"Missing route to %s" % String(anchor_id)
		)


func test_city_wall_blocks_except_viru_gate() -> void:
	var definition: MapDefinition = LowerTownSliceDefinition.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	# Wall cells north and south of the gate must block movement.
	assert_true(not MapVerification.is_walkable_cell(definition, grid, Vector2i(53, 8)), "north wall must block")
	assert_true(not MapVerification.is_walkable_cell(definition, grid, Vector2i(52, 24)), "south wall must block")
	# The moat outside the wall blocks except at the gate causeway.
	assert_true(not MapVerification.is_walkable_cell(definition, grid, Vector2i(58, 25)), "moat must block")
	assert_true(MapVerification.is_walkable_cell(definition, grid, Vector2i(58, 16)), "causeway must stay open")
	# The gate passage itself stays open from Viru street to the east road.
	var inside := definition.cell_rect_center(Rect2i(50, 16, 1, 1))
	var outside := definition.cell_rect_center(Rect2i(61, 16, 1, 1))
	assert_true(
		MapVerification.route_exists_exact(definition, grid, inside, outside),
		"Viru street must pass through the gate to the east road"
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
