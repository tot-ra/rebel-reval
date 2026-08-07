extends "res://tests/godot/test_case.gd"

const KalevSmithyDefinition := preload("res://scripts/map/definitions/lower_town/kalev_smithy_definition.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapTypes := preload("res://scripts/map/map_types.gd")
const MapVerification := preload("res://scripts/map/map_verification.gd")
const RoutineDefinition := preload("res://scripts/world/smithy_routine_definition.gd")

const DOMESTIC_FIXTURE_PATH := "res://tests/fixtures/maps/kalev_smithy_domestic_life.json"
const ROUTINE_PATH := "res://content/routines/kalev_smithy.json"
const LIVING_BAY_X_MAX_CELL := 13


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


func test_kalev_smithy_new_game_spawn_stands_beside_bed_with_camera_clearance() -> void:
	# Start uses DoorNavigator spawn smithy_start. Keep the opening position beside
	# the bed while moving it toward the room centre to avoid a wall-bump oscillation.
	var definition: MapDefinition = KalevSmithyDefinition.create()
	var routine: SmithyRoutineDefinition = RoutineDefinition.load_from_file(ROUTINE_PATH)
	var wake: SmithyActivityPoint = routine.get_activity_point(&"ap.sleep.wake")
	assert_true(wake != null, "Wake activity point must exist")
	if wake == null:
		return
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	var expected_start := Vector2(240, 368)
	var bed_approach := Vector2(144, 368)
	assert_eq(wake.approach_position, bed_approach, "Wake must remain at the bed foot")
	assert_true(MapVerification.is_walkable_point(definition, grid, wake.approach_position))
	assert_true(MapVerification.is_walkable_point(definition, grid, definition.player_spawn))
	assert_eq(definition.player_spawn, expected_start, "New-game spawn must sit beside the bed toward the room centre")
	var bed_rect := Rect2(3 * definition.cell_size, 9 * definition.cell_size, 4 * definition.cell_size, 2 * definition.cell_size)
	assert_false(
		MapVerification.is_walkable_point(definition, grid, bed_rect.get_center()),
		"Bed footprint must stay blocked"
	)
	assert_true(
		definition.player_spawn.y > bed_rect.end.y - 0.01,
		"New-game spawn must be outside the bed footprint"
	)
	assert_true(
		definition.player_spawn.distance_to(wake.approach_position) <= float(definition.cell_size) * 3.25,
		"New-game spawn must remain beside the wake bed"
	)
	var bed := MapVerification.anchor_position(definition, &"bed_alcove")
	assert_eq(bed, bed_approach, "Bed approach anchor must stay outside the bed")
	assert_true(
		definition.player_spawn.distance_to(bed) < definition.player_spawn.distance_to(MapVerification.anchor_position(definition, &"anvil")),
		"New-game spawn must be closer to the bed than to the anvil"
	)


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


func test_kalev_smithy_decals_do_not_change_gameplay_fingerprint() -> void:
	var definition: MapDefinition = KalevSmithyDefinition.create()
	assert_true(definition.decals.size() > 0, "Smithy interior should ship authored wear decals")
	var grid := MapBuilder.build(definition)
	var fingerprint_with_decals := grid.fingerprint()
	definition.decals.clear()
	var grid_without := MapBuilder.build(definition)
	assert_eq(
		fingerprint_with_decals,
		grid_without.fingerprint(),
		"Wear decals must stay view-only"
	)


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
	assert_true(prop_kinds.has(MapTypes.PROP_KIND_BELLOWS), "Forge bay needs bellows for the fire")
	assert_true(prop_kinds.has(MapTypes.PROP_KIND_BLACKSMITH_TONGS), "Forge bay needs tongs to hold hot stock")
	assert_true(prop_kinds.has(MapTypes.PROP_KIND_BLACKSMITH_HAMMER), "Anvil apron needs a one-handed forging hammer")
	assert_true(prop_kinds.has(MapTypes.PROP_KIND_BLACKSMITH_PUNCH), "Anvil apron needs an independently placeable punch")
	assert_true(prop_kinds.has(MapTypes.PROP_KIND_CHARCOAL_PILE), "Forge bay needs a charcoal pile")
	assert_true(prop_kinds.has(MapTypes.PROP_KIND_IRON_SCRAP_PILE), "Forge bay needs an iron scrap pile")
	assert_false(prop_kinds.has(MapTypes.PROP_KIND_BARRELS), "Smithy coal store must not use barrel placeholder")
	var block_count := 0
	for building in definition.buildings:
		if building.get("kind", &"") == MapTypes.BUILDING_KIND_INTERIOR_BLOCK:
			block_count += 1
	assert_eq(block_count, 0, "interior blocks should be replaced by props and wall openings")




func test_kalev_smithy_uses_tall_period_wall_finishes() -> void:
	var definition: MapDefinition = KalevSmithyDefinition.create()
	var living_count := 0
	var forge_count := 0
	for building in definition.buildings:
		if building.get("kind", &"") != MapTypes.BUILDING_KIND_INTERIOR_WALL:
			continue
		assert_eq(float(building.get("wall_height", 0.0)), 120.0, "smithy walls need full-storey height")
		var material: StringName = building.get("wall_material", &"")
		if material == &"plaster":
			living_count += 1
		elif material == &"smoked_plaster":
			forge_count += 1
	assert_true(living_count > 0, "living bay needs warm lime plaster")
	assert_true(forge_count > 0, "working bay needs smoke-darkened plaster")
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


func test_kalev_smithy_domestic_life_props_match_fixture() -> void:
	var fixture := _load_domestic_fixture()
	var definition: MapDefinition = KalevSmithyDefinition.create()
	for entry: Dictionary in fixture.get("required_domestic_props", []):
		var prop_id: StringName = StringName(str(entry.get("id", "")))
		var prop := _prop_by_id(definition, prop_id)
		assert_false(prop.is_empty(), "Missing domestic prop %s" % String(prop_id))
		assert_eq(prop.get("kind"), StringName(str(entry.get("kind", ""))))
		if entry.has("style_variant"):
			assert_eq(prop.get("style_variant"), StringName(str(entry.get("style_variant"))))
		var cell := _prop_origin_cell(definition, prop)
		assert_true(cell.x <= LIVING_BAY_X_MAX_CELL, "%s must stay in the living bay" % String(prop_id))


func test_kalev_smithy_routine_props_exist_on_map() -> void:
	var fixture := _load_domestic_fixture()
	var definition: MapDefinition = KalevSmithyDefinition.create()
	for prop_id_text: String in fixture.get("routine_prop_ids", []):
		var prop_id := StringName(prop_id_text)
		if prop_id == &"door_courtyard":
			assert_false(MapVerification.transition_rect(definition, prop_id) == Rect2())
			continue
		assert_ne(MapVerification.prop_position(definition, prop_id), Vector2.ZERO, "Routine prop %s missing" % prop_id_text)


func test_kalev_smithy_domestic_and_forge_hearths_are_separated() -> void:
	var fixture := _load_domestic_fixture()
	var definition: MapDefinition = KalevSmithyDefinition.create()
	var domestic := _prop_by_id(definition, &"domestic_hearth")
	var furnace := _prop_by_id(definition, &"forge_furnace")
	assert_false(domestic.is_empty())
	assert_false(furnace.is_empty())
	var domestic_cell := _prop_origin_cell(definition, domestic)
	var furnace_cell := _prop_origin_cell(definition, furnace)
	assert_true(domestic_cell.x <= LIVING_BAY_X_MAX_CELL)
	assert_true(furnace_cell.x > LIVING_BAY_X_MAX_CELL)
	var clearance: Dictionary = fixture.get("hearth_clearance_cells", {})
	var domestic_box: Dictionary = clearance.get("domestic_hearth", {})
	var furnace_box: Dictionary = clearance.get("forge_furnace", {})
	assert_true(domestic_cell.x >= int(domestic_box.get("x_min", 0)))
	assert_true(domestic_cell.x <= int(domestic_box.get("x_max", 99)))
	assert_true(furnace_cell.x >= int(furnace_box.get("x_min", 0)))


func test_kalev_smithy_forge_props_stay_in_work_bay() -> void:
	var fixture := _load_domestic_fixture()
	var definition: MapDefinition = KalevSmithyDefinition.create()
	for prop_id_text: String in fixture.get("forge_only_props", []):
		var prop := _prop_by_id(definition, StringName(prop_id_text))
		assert_false(prop.is_empty(), "Forge prop %s missing" % prop_id_text)
		var cell := _prop_origin_cell(definition, prop)
		assert_true(cell.x > LIVING_BAY_X_MAX_CELL, "%s must remain in the forge bay" % prop_id_text)


func test_kalev_smithy_domestic_props_do_not_block_protected_routes() -> void:
	var definition: MapDefinition = KalevSmithyDefinition.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	var spawn := definition.player_spawn
	for anchor_id: StringName in [&"anvil", &"ledger", &"bed_alcove"]:
		assert_true(
			MapVerification.route_exists(definition, grid, spawn, MapVerification.anchor_position(definition, anchor_id)),
			"Route to %s blocked after domestic dressing" % String(anchor_id)
		)
	assert_true(
		MapVerification.route_exists(
			definition,
			grid,
			spawn,
			MapVerification.transition_rect(definition, &"door_courtyard").get_center()
		),
		"Route to courtyard door blocked after domestic dressing"
	)
	var routine := RoutineDefinition.load_from_file(ROUTINE_PATH)
	for activity_id: StringName in routine.all_activity_ids():
		var point := routine.get_activity_point(activity_id)
		if point == null or point.prop_id.is_empty() or point.prop_id == &"door_courtyard":
			continue
		assert_ne(
			MapVerification.prop_position(definition, point.prop_id),
			Vector2.ZERO,
			"Activity %s references missing prop %s" % [String(activity_id), String(point.prop_id)]
		)


func _load_domestic_fixture() -> Dictionary:
	var file := FileAccess.open(DOMESTIC_FIXTURE_PATH, FileAccess.READ)
	assert_true(file != null, "Domestic-life fixture must exist")
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	assert_true(parsed is Dictionary, "Domestic-life fixture must be JSON object")
	return parsed


func _prop_by_id(definition: MapDefinition, prop_id: StringName) -> Dictionary:
	for prop in definition.props:
		if prop.get("id", &"") == prop_id:
			return prop
	return {}


func _prop_origin_cell(definition: MapDefinition, prop: Dictionary) -> Vector2i:
	var position: Vector2 = prop.get("position", Vector2.ZERO)
	return Vector2i(
		int(floor(position.x / definition.cell_size)),
		int(floor(position.y / definition.cell_size))
	)
