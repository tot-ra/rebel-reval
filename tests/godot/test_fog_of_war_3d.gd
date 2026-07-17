extends "res://tests/godot/test_case.gd"

const FogOfWar := preload("res://scripts/map/view3d/map_fog_of_war.gd")
const LowerTownSlice := preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")


func test_visibility_uses_120_degree_character_facing() -> void:
	var fog = FogOfWar.new()
	var empty: Array[Rect2] = []
	fog._occluders = empty
	var player := Vector2.ZERO
	var facing := Vector2.RIGHT
	assert_true(fog.visibility_at(Vector2(5.0, 0.0), player, facing) > 0.5, "content in front must stay alive")
	assert_true(fog.visibility_at(Vector2(2.5, 4.0), player, facing) > 0.5, "content inside 120 degrees must stay alive")
	assert_true(fog.visibility_at(Vector2(2.0, 4.0), player, facing) > 0.5, "the rear-shifted vertex must widen the live cone around the character")
	assert_true(fog.visibility_at(Vector2(0.0, 4.0), player, facing) < 0.5, "content outside the shifted 120 degree cone must become memory")
	assert_true(fog.visibility_at(Vector2(-5.0, 0.0), player, facing) < 0.5, "content well behind must become memory")


func test_fov_vertex_starts_behind_the_character() -> void:
	var fog = FogOfWar.new()
	var empty: Array[Rect2] = []
	fog._occluders = empty
	var player := Vector2(10.0, 10.0)
	var facing := Vector2.RIGHT
	assert_eq(
		FogOfWar.fov_origin(player, facing),
		Vector2(10.0 - FogOfWar.FOV_ORIGIN_BACK_OFFSET_WORLD, 10.0),
		"the cone vertex must start behind the character"
	)
	assert_true(
		fog.visibility_at(player + Vector2(-0.5, 0.0), player, facing) > 0.5,
		"the character footprint just behind its pivot must remain live"
	)


func test_visibility_stops_at_memory_radius() -> void:
	var fog = FogOfWar.new()
	var empty: Array[Rect2] = []
	fog._occluders = empty
	assert_true(fog.visibility_at(Vector2(FogOfWar.MEMORY_RADIUS_WORLD - 0.1, 0.0), Vector2.ZERO, Vector2.RIGHT) > 0.5)
	assert_true(fog.visibility_at(Vector2(FogOfWar.MEMORY_RADIUS_WORLD + 0.1, 0.0), Vector2.ZERO, Vector2.RIGHT) < 0.5)


func test_building_footprint_hides_only_content_behind_it() -> void:
	var fog = FogOfWar.new()
	var occluders: Array[Rect2] = [Rect2(4.0, -1.0, 2.0, 2.0)]
	fog._occluders = occluders
	var player := Vector2.ZERO
	var facing := Vector2.RIGHT
	assert_true(fog.visibility_at(Vector2(5.0, 0.0), player, facing) > 0.5, "the blocking wall itself must remain visible")
	assert_true(fog.visibility_at(Vector2(3.0, 0.0), player, facing) > 0.5, "content before a wall must remain visible")
	assert_true(fog.visibility_at(Vector2(8.0, 0.0), player, facing) < 0.5, "content behind a wall must become memory")
	assert_true(fog.visibility_at(Vector2(8.0, 4.0), player, facing) > 0.5, "a sight line that misses the wall must remain visible")


func test_lower_town_buildings_feed_occluder_rectangles() -> void:
	var definition := LowerTownSlice.create()
	var rects: Array[Rect2] = FogOfWar.occluder_rects_for_definition(definition)
	assert_eq(rects.size(), definition.buildings.size(), "every building or wall must block sight")
	assert_true(rects[0].size.x > 0.0 and rects[0].size.y > 0.0, "occluders must use world-scale footprints")
