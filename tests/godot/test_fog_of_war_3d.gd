extends "res://tests/godot/test_case.gd"

const FogOfWar := preload("res://scripts/map/view3d/map_fog_of_war.gd")
const LowerTownSlice := preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")


func test_visibility_uses_radial_distance_from_player() -> void:
	var fog = FogOfWar.new()
	var empty: Array[Rect2] = []
	fog._occluders = empty
	var player := Vector2.ZERO
	var facing := Vector2.RIGHT
	assert_true(fog.visibility_at(Vector2(5.0, 0.0), player, facing) > 0.5, "nearby content must stay alive")
	assert_true(fog.visibility_at(Vector2(0.0, 5.0), player, facing) > 0.5, "content beside the player must stay alive")
	assert_true(fog.visibility_at(Vector2(-5.0, 0.0), player, facing) > 0.5, "content behind the player must stay alive within memory radius")


func test_player_clear_radius_keeps_the_whole_character_live() -> void:
	var fog = FogOfWar.new()
	var empty: Array[Rect2] = []
	fog._occluders = empty
	var player := Vector2(10.0, 10.0)
	var facing := Vector2.RIGHT
	assert_true(
		fog.visibility_at(player - facing * (FogOfWar.PLAYER_CLEAR_RADIUS_WORLD - 0.05), player, facing) > 0.5,
		"the entire animated character footprint must remain live around its pivot"
	)
	assert_true(
		fog.visibility_at(player - facing * (FogOfWar.PLAYER_CLEAR_RADIUS_WORLD + 0.05), player, facing) > 0.5,
		"content just outside the clear bubble must still stay alive within memory radius"
	)


func test_fullscreen_shader_is_not_face_culled() -> void:
	var source := FogOfWar.FOG_SHADER.code
	assert_true("cull_disabled" in source, "the clip-space overlay must draw regardless of quad winding")
	assert_false("cull_front" in source, "front-face culling silently removes the fullscreen pass")
	assert_true("hint_screen_texture" in source, "the overlay must sample the rendered scene")
	assert_true("hint_depth_texture" in source, "the overlay must preserve real character and building surfaces")
	assert_true("on_blocking_surface" in source, "facade classification must tolerate footprint-edge precision")
	assert_false("desaturation" in source, "unseen areas must not be communicated through saturation")
	assert_false("color.rgb *=" in source, "visibility must not darken scene lighting or real shadows")
	assert_eq(FogOfWar.OVERLAY_RENDER_PRIORITY, -127, "transparent smoke must render after the opaque-scene overlay")


func test_blur_distances_are_doubled_with_a_wide_transition() -> void:
	assert_eq(FogOfWar.CLEAR_RADIUS_WORLD, 18.0, "distant blur must begin at twice the original radius")
	assert_eq(FogOfWar.MEMORY_RADIUS_WORLD, 36.0, "the distant blur transition must end at twice the original radius")
	assert_eq(
		FogOfWar.MEMORY_RADIUS_WORLD - FogOfWar.CLEAR_RADIUS_WORLD,
		18.0,
		"the smooth transition width must also be doubled"
	)
	var fog = FogOfWar.new()
	var empty: Array[Rect2] = []
	fog._occluders = empty
	assert_true(fog.visibility_at(Vector2(FogOfWar.MEMORY_RADIUS_WORLD - 0.1, 0.0), Vector2.ZERO, Vector2.RIGHT) > 0.5)
	assert_true(fog.visibility_at(Vector2(FogOfWar.MEMORY_RADIUS_WORLD + 0.1, 0.0), Vector2.ZERO, Vector2.RIGHT) < 0.5)


func test_building_footprint_hides_only_content_beyond_its_surface() -> void:
	var fog = FogOfWar.new()
	var occluders: Array[Rect2] = [Rect2(4.0, -1.0, 2.0, 2.0)]
	fog._occluders = occluders
	var player := Vector2.ZERO
	var facing := Vector2.RIGHT
	assert_true(fog.visibility_at(Vector2(5.0, 0.0), player, facing) > 0.5, "the blocking wall itself must remain visible")
	assert_true(fog.visibility_at(Vector2(3.0, 0.0), player, facing) > 0.5, "content before a wall must remain visible")
	assert_true(
		fog.visibility_at(Vector2(6.0 + FogOfWar.OCCLUSION_TARGET_GRACE_WORLD * 0.5, 0.0), player, facing) > 0.5,
		"roof and facade details just beyond the footprint must remain visible"
	)
	assert_true(
		fog.visibility_at(Vector2(6.0 + FogOfWar.OCCLUSION_TARGET_GRACE_WORLD + 0.1, 0.0), player, facing) < 0.5,
		"content clearly beyond a wall must become memory"
	)
	assert_true(fog.visibility_at(Vector2(8.0, 4.0), player, facing) > 0.5, "a sight line that misses the wall must remain visible")


func test_lower_town_buildings_feed_occluder_rectangles() -> void:
	var definition := LowerTownSlice.create()
	var rects: Array[Rect2] = FogOfWar.occluder_rects_for_definition(definition)
	assert_eq(rects.size(), definition.buildings.size(), "every building or wall must block sight")
	assert_true(rects[0].size.x > 0.0 and rects[0].size.y > 0.0, "occluders must use world-scale footprints")
