extends "res://tests/godot/test_case.gd"

const MAP_PATH := "res://content/maps/world_padise.rrmap"
const LATE_PRIMITIVES: Array[StringName] = [&"stone_church", &"monastic_range", &"gatehouse"]
const ROOM_ANCHORS: Array[StringName] = [
	&"room_oratory",
	&"room_scriptorium",
	&"room_abbot_guest",
	&"room_chapter_hall",
	&"room_infirmary",
	&"room_parlour",
	&"room_brewery_kitchen",
	&"room_refectory",
	&"room_dormitory",
]


func test_world_padise_uses_a_large_timber_monastery_range_with_rooms() -> void:
	var parsed := MapRrmapParser.parse_file(MAP_PATH)
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	var definition: MapDefinition = parsed.definition
	var buildings := _buildings_by_id(definition)
	assert_true(buildings.has(&"early_west_stone_house"), "Padise needs the archaeologically attested western stone trace")
	assert_eq(buildings[&"early_west_stone_house"].get("primitive"), &"stone_hall")
	assert_true(_interior_wall_count(definition) >= 12, "the monastery must read as one divided building, not a hut cluster")
	assert_true(_has_monastery_shell_span(definition, 20, 14), "the timber range must have a large continuous footprint")
	assert_true(_prop_count(definition, MapTypes.PROP_KIND_BED) >= 2, "dormitory and infirmary need distinct beds")
	assert_true(_prop_count(definition, MapTypes.PROP_KIND_TABLE) >= 4, "rooms need readable tables instead of empty shells")
	for primitive in LATE_PRIMITIVES:
		assert_eq(_primitive_count(definition, primitive), 0, "late fortified primitive must not appear in the 1343 phase: %s" % primitive)
	assert_array_contains(MapBuilder.build(definition).used_terrain_ids(), MapTypes.TERRAIN_ASH)
	assert_true(definition.decals.any(func(decal): return decal.get("kind") == MapTypes.DECAL_KIND_SCORCH), "the 1 May phase needs restrained evidence of the 23 April fire")


func test_world_padise_rooms_and_historical_landmarks_are_reachable() -> void:
	var parsed := MapRrmapParser.parse_file(MAP_PATH)
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	var definition: MapDefinition = parsed.definition
	var grid := MapBuilder.build(definition)
	var required_anchors := [
		&"landmark_early_stone_house",
		&"landmark_timber_oratory",
		&"landmark_fire_damage",
		&"landmark_work_yard",
		&"landmark_monastery_well",
	]
	required_anchors.append_array(ROOM_ANCHORS)
	for anchor_id in required_anchors:
		assert_true(MapVerification.has_anchor(definition, anchor_id), "missing Padise anchor %s" % anchor_id)
		assert_true(
			MapVerification.route_exists(definition, grid, definition.player_spawn, MapVerification.anchor_position(definition, anchor_id)),
			"Padise anchor is unreachable: %s" % anchor_id,
		)
	assert_true(MapVerification.collision_parity(definition))


func _buildings_by_id(definition: MapDefinition) -> Dictionary:
	var result: Dictionary = {}
	for building in definition.buildings:
		result[building.get("id")] = building
	return result


func _interior_wall_count(definition: MapDefinition) -> int:
	return definition.buildings.filter(func(building): return building.get("kind") == MapTypes.BUILDING_KIND_INTERIOR_WALL).size()


func _has_monastery_shell_span(definition: MapDefinition, minimum_width_cells: int, minimum_height_cells: int) -> bool:
	var found := false
	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	for building in definition.buildings:
		if not String(building.get("id", "")).begins_with("monastery.outer."):
			continue
		found = true
		var footprint: Rect2 = building.get("footprint", Rect2())
		min_x = minf(min_x, footprint.position.x)
		min_y = minf(min_y, footprint.position.y)
		max_x = maxf(max_x, footprint.end.x)
		max_y = maxf(max_y, footprint.end.y)
	if not found:
		return false
	return (
		int(round((max_x - min_x) / definition.cell_size)) >= minimum_width_cells
		and int(round((max_y - min_y) / definition.cell_size)) >= minimum_height_cells
	)


func _prop_count(definition: MapDefinition, kind: StringName) -> int:
	return definition.props.filter(func(prop): return prop.get("kind") == kind).size()


func _primitive_count(definition: MapDefinition, primitive: StringName) -> int:
	return definition.buildings.filter(func(building): return building.get("primitive") == primitive).size()
