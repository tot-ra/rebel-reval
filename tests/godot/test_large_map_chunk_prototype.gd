extends "res://tests/godot/test_case.gd"

const ChunkPrototype := preload("res://tools/benchmarks/large_map_chunk_prototype.gd")


func test_chunk_coordinates_use_floor_division_in_all_quadrants() -> void:
	assert_eq(ChunkPrototype.chunk_for_global_cell(Vector2i(0, 0), 32), Vector2i(0, 0))
	assert_eq(ChunkPrototype.chunk_for_global_cell(Vector2i(31, 31), 32), Vector2i(0, 0))
	assert_eq(ChunkPrototype.chunk_for_global_cell(Vector2i(32, 32), 32), Vector2i(1, 1))
	assert_eq(ChunkPrototype.chunk_for_global_cell(Vector2i(-1, -1), 32), Vector2i(-1, -1))
	assert_eq(ChunkPrototype.chunk_for_global_cell(Vector2i(-32, -32), 32), Vector2i(-1, -1))
	assert_eq(ChunkPrototype.chunk_for_global_cell(Vector2i(-33, -33), 32), Vector2i(-2, -2))
	assert_eq(ChunkPrototype.local_cell(Vector2i(-1, -1), 32), Vector2i(31, 31))


func test_point_on_boundary_is_owned_by_positive_half_open_chunk() -> void:
	assert_eq(ChunkPrototype.owner_for_point(Vector2(1024.0, 64.0), 32, 32), Vector2i(1, 0))
	assert_eq(ChunkPrototype.owner_for_point(Vector2(-0.01, 64.0), 32, 32), Vector2i(-1, 0))


func test_rect_owner_uses_half_open_bounds_and_lexicographic_minimum() -> void:
	var one_chunk := Rect2(32.0, 32.0, 992.0, 64.0)
	assert_eq(ChunkPrototype.owner_for_rect(one_chunk, &"building.one", 32, 32), Vector2i(0, 0))
	var crossing := Rect2(992.0, 32.0, 64.0, 64.0)
	assert_eq(ChunkPrototype.owner_for_rect(crossing, &"building.crossing", 32, 32), Vector2i(0, 0))
	var reversed: Array[Vector2i] = [Vector2i(1, 1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, 0)]
	assert_eq(ChunkPrototype.choose_owner(reversed, &"building.crossing"), Vector2i(0, 0))


func test_navigation_overlap_and_load_radius_match_config() -> void:
	var config := ChunkPrototype.load_config()
	assert_false(config.is_empty())
	var chunk_size := int(config["chunk_size_cells"])
	var border := int(config["navigation_border_cells"])
	assert_eq(ChunkPrototype.navigation_bake_rect(Vector2i(1, 2), chunk_size, border), Rect2i(30, 62, 36, 36))
	assert_eq(ChunkPrototype.chunks_in_radius(Vector2i.ZERO, int(config["load_radius_chunks"])).size(), 25)
	assert_true(int(config["simulation_radius_chunks"]) <= int(config["load_radius_chunks"]))


func test_coarse_route_is_deterministic_and_contiguous() -> void:
	var route := ChunkPrototype.route_chunks(Vector2i(-1, 2), Vector2i(2, 0))
	assert_eq(route, [
		Vector2i(-1, 2), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2),
		Vector2i(2, 1), Vector2i(2, 0),
	])
	for index in range(1, route.size()):
		var delta: Vector2i = route[index] - route[index - 1]
		assert_eq(absi(delta.x) + absi(delta.y), 1)


func test_visual_lod_bands_are_config_driven() -> void:
	var config := ChunkPrototype.load_config()
	assert_eq(ChunkPrototype.visual_lod(Vector2i.ZERO, Vector2i.ZERO, config), 0)
	assert_eq(ChunkPrototype.visual_lod(Vector2i(1, 1), Vector2i.ZERO, config), 0)
	assert_eq(ChunkPrototype.visual_lod(Vector2i(2, 0), Vector2i.ZERO, config), 1)
	assert_eq(ChunkPrototype.visual_lod(Vector2i(3, 0), Vector2i.ZERO, config), 2)


func test_cross_chunk_handles_do_not_encode_owner_chunk() -> void:
	var handle := ChunkPrototype.stable_handle(&"loc.lower_town_slice", &"char.example")
	assert_eq(handle, {"location_id": "loc.lower_town_slice", "object_id": "char.example"})
	assert_false(handle.has("chunk"))


func test_persistent_position_round_trips_without_chunk_coordinates() -> void:
	var position := Vector2(-0.25 * 32.0, 33.75 * 32.0)
	var payload := ChunkPrototype.persistent_position(position, 32)
	assert_eq(payload["global_cell"], [-1, 33])
	assert_eq(payload["sub_cell"], [0.75, 0.75])
	assert_false(payload.has("chunk"))
	assert_eq(ChunkPrototype.restore_persistent_position(payload, 32), position)
