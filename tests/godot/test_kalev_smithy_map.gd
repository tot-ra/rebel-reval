extends "res://tests/godot/test_case.gd"

const KalevSmithyDefinition := preload("res://scripts/map/definitions/lower_town/kalev_smithy_definition.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapTypes := preload("res://scripts/map/map_types.gd")
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


func test_kalev_smithy_has_windows_furniture_and_local_lighting() -> void:
	var definition: MapDefinition = KalevSmithyDefinition.create()
	var window_count := 0
	for landmark in definition.view_landmarks:
		if landmark.get("kind", &"") == &"interior_window":
			window_count += 1
	assert_eq(window_count, 4, "smithy needs north, west, and east daylight windows")
	var prop_kinds: Dictionary = {}
	for prop in definition.props:
		prop_kinds[prop["kind"]] = true
	for required in [MapTypes.PROP_KIND_BED, MapTypes.PROP_KIND_TABLE, MapTypes.PROP_KIND_CHAIR, MapTypes.PROP_KIND_FURNACE, MapTypes.PROP_KIND_CANDLE]:
		assert_true(prop_kinds.has(required), "Missing prop kind %s" % String(required))
	var block_count := 0
	for building in definition.buildings:
		if building.get("kind", &"") == MapTypes.BUILDING_KIND_INTERIOR_BLOCK:
			block_count += 1
	assert_eq(block_count, 0, "interior blocks should be replaced by props and wall openings")


func test_kalev_smithy_door_aligns_with_south_wall_opening() -> void:
	var definition: MapDefinition = KalevSmithyDefinition.create()
	var door := MapVerification.transition_rect(definition, &"door_courtyard")
	assert_eq(door, Rect2(384, 416, 64, 32), "Courtyard door must match the south wall opening")


func test_kalev_smithy_has_work_living_partition_and_floors() -> void:
	var definition: MapDefinition = KalevSmithyDefinition.create()
	var has_divider := false
	for building in definition.buildings:
		if String(building.get("id", &"")).begins_with("wall.divider"):
			has_divider = true
			break
	assert_true(has_divider, "smithy needs a partition between forge and living quarters")
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	var living := grid.get_terrain(Vector2i(6, 8))
	var forge := grid.get_terrain(Vector2i(20, 8))
	assert_eq(living, MapTypes.TERRAIN_TIMBER_FLOOR, "living quarter should use timber flooring")
	assert_eq(forge, MapTypes.TERRAIN_STONE, "forge quarter should use stone flooring")


func test_kalev_smithy_full_terrain_coverage() -> void:
	var definition: MapDefinition = KalevSmithyDefinition.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	for y in grid.size_cells.y:
		for x in grid.size_cells.x:
			assert_false(String(grid.get_terrain(Vector2i(x, y))).is_empty())
