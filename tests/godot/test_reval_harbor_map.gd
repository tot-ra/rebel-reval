extends "res://tests/godot/test_case.gd"

const RRMAP_PATH := "res://content/maps/reval_harbor_surroundings.rrmap"
const HarborDefinition := preload("res://scripts/map/definitions/outdoor/reval_harbor_definition.gd")


func test_rrmap_parses_with_historical_street_spine() -> void:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	assert_eq(parsed.blueprint.map_id, &"reval_harbor")
	assert_eq(parsed.definition.size_cells, Vector2i(72, 48))


func test_harbor_connects_back_to_lower_town() -> void:
	var definition: MapDefinition = HarborDefinition.create()
	var transition_by_id: Dictionary = {}
	for transition in definition.transitions:
		transition_by_id[transition["id"]] = transition
	assert_true(transition_by_id.has(&"to_reval_east"))
	var to_town: Dictionary = transition_by_id[&"to_reval_east"]
	assert_eq(to_town["destination_scene_id"], &"reval_east")
	assert_eq(to_town["destination_spawn_id"], &"viru_road_boundary")
	assert_eq(to_town["spawn_id"], &"from_reval_east")
	assert_true(DoorNavigator.has_spawn(&"reval_harbor", &"from_reval_east"))
	assert_true(DoorNavigator.has_spawn(&"reval_east", &"viru_road_boundary"))


func test_lower_town_routes_to_harbor_not_warehouse() -> void:
	var definition: MapDefinition = preload(
		"res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd"
	).create()
	for transition in definition.transitions:
		if transition["id"] == &"viru_road_boundary":
			assert_eq(transition["destination_scene_id"], &"reval_harbor")
			return
	push_error("viru_road_boundary transition missing")
