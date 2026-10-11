extends "res://tests/godot/test_case.gd"


func test_build_emits_deterministic_global_origins_and_physical_seam() -> void:
	var definitions: Array[MapDefinition] = [_map_a(), _map_b()]
	var result := MapWorldLayout.build(definitions, &"map_a", &"test_outdoor")
	assert_true(result["valid"], str(result["errors"]))
	assert_eq(result["world_group_id"], &"test_outdoor")
	assert_eq(result["unplaced"], [])
	assert_eq(MapWorldLayout.location(result, &"map_a")["origin_cell"], Vector2i.ZERO)
	assert_eq(MapWorldLayout.location(result, &"map_b")["origin_cell"], Vector2i(4, 0))
	assert_eq(MapWorldLayout.global_cell(result, &"map_b", Vector2i(1, 2)), Vector2i(5, 2))
	assert_eq(MapWorldLayout.location_at_global_cell(result, Vector2i(3, 3)), &"map_a")
	assert_eq(MapWorldLayout.location_at_global_cell(result, Vector2i(4, 3)), &"map_b")
	assert_eq(MapWorldLayout.location_at_global_cell(result, Vector2i(8, 3)), &"")

	var seams: Array = result["seams"]
	assert_eq(seams.size(), 1)
	assert_eq(seams[0]["world_group_id"], &"test_outdoor")
	assert_eq(seams[0]["base_side"], &"east")
	assert_eq(seams[0]["neighbor_side"], &"west")
	assert_eq(seams[0]["span_cells"], 2.0)


func test_travel_transitions_are_not_physical_seams() -> void:
	var travel_map := _map_b()
	travel_map.transitions[0]["alignment"] = &"travel"
	var result := MapWorldLayout.build([_map_a(), travel_map], &"map_a")
	assert_false(result["valid"])
	assert_true(result["seams"].is_empty())
	assert_array_contains(result["unplaced"], &"map_b")
	assert_true("no deterministic global origin" in "\n".join(result["errors"]))


func test_invalid_seam_reports_side_span_and_overlap_errors() -> void:
	var same_side := _map_b()
	same_side.transitions[0]["rect"] = Rect2(96, 32, 32, 96)
	var result := MapWorldLayout.build([_map_a(), same_side], &"map_a")
	assert_false(result["valid"])
	var errors := "\n".join(result["errors"])
	assert_true("must use opposite boundary sides" in errors)
	assert_true("has mismatched transition spans" in errors)
	assert_true("overlap in global bounds" in errors)


func test_mismatched_cell_size_is_rejected_before_streaming() -> void:
	var mismatched := _map_b()
	mismatched.cell_size = 16
	var result := MapWorldLayout.build([_map_a(), mismatched], &"map_a")
	assert_false(result["valid"])
	assert_true("contiguous groups require the default cell_size" in "\n".join(result["errors"]))
	assert_true("has mismatched cell sizes" in "\n".join(result["errors"]))


func _map_a() -> MapDefinition:
	var definition := _base_map(&"map_a")
	definition.transitions = [{
		"id": &"to_map_b",
		"rect": Rect2(96, 32, 32, 64),
		"spawn_id": &"from_map_b",
		"destination_spawn_id": &"from_map_a",
	}]
	return definition


func _map_b() -> MapDefinition:
	var definition := _base_map(&"map_b")
	definition.transitions = [{
		"id": &"to_map_a",
		"rect": Rect2(0, 32, 32, 64),
		"spawn_id": &"from_map_a",
		"destination_spawn_id": &"from_map_b",
	}]
	return definition


func _base_map(map_id: StringName) -> MapDefinition:
	var definition := MapDefinition.new()
	definition.map_id = map_id
	definition.location = StringName("loc.%s" % map_id)
	definition.cell_size = MapTypes.DEFAULT_CELL_SIZE
	definition.size_cells = Vector2i(4, 4)
	definition.base_terrain = MapTypes.TERRAIN_GRASS
	definition.player_spawn = Vector2(32, 32)
	definition.scope = &"production"
	definition.active = true
	definition.palette = &"clean_painted"
	definition.fingerprint = "%s-fingerprint" % map_id
	return definition
