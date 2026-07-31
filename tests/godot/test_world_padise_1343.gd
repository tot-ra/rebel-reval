extends "res://tests/godot/test_case.gd"

const MAP_PATH := "res://content/maps/world_padise.rrmap"
const LATE_PRIMITIVES: Array[StringName] = [&"stone_church", &"monastic_range", &"gatehouse"]


func test_world_padise_represents_the_immediate_post_attack_1343_phase() -> void:
	var parsed := MapRrmapParser.parse_file(MAP_PATH)
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	var definition: MapDefinition = parsed.definition
	var buildings := _buildings_by_id(definition)
	assert_true(buildings.has(&"early_west_stone_house"), "1343 Padise needs the archaeologically attested western stone building")
	assert_eq(buildings[&"early_west_stone_house"].get("primitive"), &"stone_hall")
	assert_true(_primitive_count(definition, &"timber_hall") >= 2, "uncertain pre-uprising accommodation should remain dispersed timber buildings")
	assert_true(_primitive_count(definition, &"work_shed") >= 2, "service buildings should not become a completed stone claustrum")
	for primitive in LATE_PRIMITIVES:
		assert_eq(_primitive_count(definition, primitive), 0, "late fortified primitive must not appear in the 1343 phase: %s" % primitive)
	assert_array_contains(MapBuilder.build(definition).used_terrain_ids(), MapTypes.TERRAIN_ASH)
	assert_true(definition.decals.any(func(decal): return decal.get("kind") == MapTypes.DECAL_KIND_SCORCH), "the 1 May phase needs restrained evidence of the 23 April fire")


func test_world_padise_historical_landmarks_and_travel_route_are_reachable() -> void:
	var parsed := MapRrmapParser.parse_file(MAP_PATH)
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	var definition: MapDefinition = parsed.definition
	var grid := MapBuilder.build(definition)
	for anchor_id in [
		&"landmark_early_stone_house",
		&"landmark_timber_oratory",
		&"landmark_fire_damage",
		&"landmark_work_yard",
		&"landmark_monastery_well",
	]:
		assert_true(MapVerification.has_anchor(definition, anchor_id), "missing 1343 Padise anchor %s" % anchor_id)
		assert_true(
			MapVerification.route_exists(definition, grid, definition.player_spawn, MapVerification.anchor_position(definition, anchor_id)),
			"1343 Padise anchor is unreachable: %s" % anchor_id,
		)
	assert_true(MapVerification.collision_parity(definition))


func _buildings_by_id(definition: MapDefinition) -> Dictionary:
	var result: Dictionary = {}
	for building in definition.buildings:
		result[building.get("id")] = building
	return result


func _primitive_count(definition: MapDefinition, primitive: StringName) -> int:
	return definition.buildings.filter(func(building): return building.get("primitive") == primitive).size()
