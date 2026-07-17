extends "res://tests/godot/test_case.gd"

const KalevSmithyDefinition := preload("res://scripts/map/definitions/lower_town/kalev_smithy_definition.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapVerification := preload("res://scripts/map/map_verification.gd")


func test_kalev_smithy_definition_validates() -> void:
	var definition: MapDefinition = KalevSmithyDefinition.create()
	assert_eq(definition.size_cells, Vector2i(26, 14))
	assert_eq(definition.scope, &"production")
	assert_true(definition.active)
	assert_true(
		definition.suppresses_exterior_surroundings(),
		"Interior shell must not request countryside surroundings"
	)
	var errors: Array[String] = MapBuilder.validate(definition)
	assert_true(errors.is_empty(), str(errors))


func test_kalev_smithy_required_anchors_present() -> void:
	var definition: MapDefinition = KalevSmithyDefinition.create()
	for anchor_id in [&"anvil", &"ledger", &"bed_alcove"]:
		assert_true(MapVerification.has_anchor(definition, anchor_id), "Missing anchor %s" % String(anchor_id))
	assert_false(MapVerification.transition_rect(definition, &"door_courtyard") == Rect2())
	assert_false(MapVerification.transition_rect(definition, &"smithy_start_spawn") == Rect2())


func test_kalev_smithy_door_and_work_triangle_reachable() -> void:
	var definition: MapDefinition = KalevSmithyDefinition.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	var spawn := definition.player_spawn
	assert_true(
		MapVerification.route_exists(definition, grid, spawn, MapVerification.anchor_position(definition, &"anvil")),
		"Route to anvil missing"
	)
	assert_true(
		MapVerification.route_exists(definition, grid, spawn, MapVerification.anchor_position(definition, &"ledger")),
		"Route to ledger missing"
	)
	assert_true(
		MapVerification.route_exists(definition, grid, spawn, MapVerification.anchor_position(definition, &"bed_alcove")),
		"Route to bed alcove missing"
	)
	assert_true(
		MapVerification.route_exists(
			definition,
			grid,
			spawn,
			MapVerification.transition_rect(definition, &"door_courtyard").get_center()
		),
		"Route to courtyard door missing"
	)


func test_kalev_smithy_collision_parity() -> void:
	var definition: MapDefinition = KalevSmithyDefinition.create()
	assert_true(MapVerification.collision_parity(definition))


func test_kalev_smithy_full_terrain_coverage() -> void:
	var definition: MapDefinition = KalevSmithyDefinition.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	for y in grid.size_cells.y:
		for x in grid.size_cells.x:
			assert_false(String(grid.get_terrain(Vector2i(x, y))).is_empty())
