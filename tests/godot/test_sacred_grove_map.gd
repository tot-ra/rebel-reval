extends "res://tests/godot/test_case.gd"

const RRMAP_PATH := "res://content/maps/world_sacred_grove.rrmap"


func test_sacred_grove_expands_into_a_forest_boundary() -> void:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	var definition: MapDefinition = parsed.definition
	assert_eq(definition.size_cells, Vector2i(64, 36))
	for side in MapDefinition.WORLD_SIDES:
		assert_eq(
			definition.surroundings_sides.get(side),
			&"woodland",
			"the sacred grove should continue as forest beyond the %s boundary" % String(side)
		)

	var boundary_lines := 0
	for building in definition.buildings:
		if String(building.get("id", "")).begins_with("boundary_forest_"):
			boundary_lines += 1
			assert_eq(building.get("primitive"), &"tree_line")
	assert_true(boundary_lines >= 14, "expanded edges need layered, irregular forest rows")


func test_sacred_grove_keeps_road_openings_through_boundary_forest() -> void:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	var definition: MapDefinition = parsed.definition
	var west_road := _transition(definition, &"to_reval")
	var east_road := _transition(definition, &"road_to_harju")
	assert_eq(west_road.get("rect"), Rect2(0, 25 * 32, 4 * 32, 4 * 32))
	assert_eq(east_road.get("rect"), Rect2(60 * 32, 24 * 32, 4 * 32, 4 * 32))
	for building in definition.buildings:
		if not String(building.get("id", "")).begins_with("boundary_forest_"):
			continue
		var footprint: Rect2 = building["footprint"]
		assert_false(footprint.intersects(west_road["rect"]), "%s blocks the Reval road" % building["id"])
		assert_false(footprint.intersects(east_road["rect"]), "%s blocks the Harju road" % building["id"])


func _transition(definition: MapDefinition, transition_id: StringName) -> Dictionary:
	for transition in definition.transitions:
		if transition.get("id") == transition_id:
			return transition
	return {}
