extends "res://tests/godot/test_case.gd"

const GodRayPass := preload("res://scripts/map/view3d/god_ray_pass.gd")
const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")


func _presentation(sun_y: float, clear: float, coverage: float) -> SkyWeather.WeatherPresentation:
	var p := SkyWeather.WeatherPresentation.new()
	p.sun_direction = Vector3(0.0, sun_y, -1.0).normalized()
	p.sun_visibility = 1.0 if sun_y > 0.0 else 0.0
	p.sun_cloud_clear = clear
	p.cloud_coverage = coverage
	p.moon_direction = Vector3.DOWN
	return p


func test_low_sun_through_broken_cloud_beats_high_sun_clear_sky() -> void:
	var low := GodRayPass.light_strength(_presentation(0.15, 1.0, 0.5))
	var high := GodRayPass.light_strength(_presentation(0.95, 1.0, 0.0))
	assert_true(low > high, "low sun in broken cloud must show stronger rays than clear noon")


func test_fog_and_rain_haze_raise_the_scatter() -> void:
	var dry := _presentation(0.2, 1.0, 0.0)
	var wet := _presentation(0.2, 1.0, 0.0)
	wet.rain_intensity = 1.0
	assert_true(GodRayPass.haze_amount(wet) > GodRayPass.haze_amount(dry))


func test_no_rays_at_night_without_moon_or_when_sun_is_blocked() -> void:
	var night := _presentation(-0.5, 1.0, 0.5)
	assert_eq(GodRayPass.light_strength(night), 0.0)
	assert_eq(GodRayPass.light_strength(_presentation(0.2, 0.0, 0.5)), 0.0)


func test_moonlight_rays_are_fainter_than_sunlight() -> void:
	var night := _presentation(-0.5, 1.0, 0.5)
	night.lunar_light_strength = 1.0
	night.moon_cloud_clear = 1.0
	night.moon_direction = Vector3(0.0, 0.4, -1.0).normalized()
	var moon := GodRayPass.light_strength(night)
	assert_true(moon > 0.0)
	assert_true(moon < GodRayPass.light_strength(_presentation(0.2, 1.0, 0.5)))
	assert_false(GodRayPass.uses_sun(night))


func test_haze_scatters_forward_toward_the_light() -> void:
	assert_almost_eq(GodRayPass.phase(1.0), 1.0, 0.0001)
	assert_true(GodRayPass.phase(0.0) < 0.15, "side-on haze must be faint")
	assert_true(GodRayPass.phase(-0.5) < GodRayPass.phase(0.0))


func test_top_down_camera_sees_almost_no_rays() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	tree.root.add_child(camera)
	var low_sun := Vector3(0.0, 0.25, -1.0).normalized()
	camera.look_at_from_position(Vector3(0.0, 50.0, 0.0), Vector3.ZERO, Vector3.FORWARD)
	var top_down := GodRayPass.view_phase(camera, low_sun, 1.7778)
	camera.look_at_from_position(Vector3(0.0, 10.0, 10.0), Vector3(0.0, 0.0, -10.0), Vector3.UP)
	var facing := GodRayPass.view_phase(camera, low_sun, 1.7778)
	camera.free()
	assert_true(top_down < 0.05, "top-down view must not show a ray veil: %s" % top_down)
	assert_true(facing > top_down * 4.0, "looking toward the sun must show rays")


func test_height_raster_keeps_the_tallest_mass_per_texel() -> void:
	var boxes: Array[AABB] = [
		AABB(Vector3(1.0, 0.0, 1.0), Vector3(2.0, 5.0, 1.0)),
		AABB(Vector3(2.0, 0.0, 1.0), Vector3(1.0, 9.0, 3.0)),
	]
	var image := GodRayPass.rasterize_heights(boxes, Vector2(4.0, 4.0), 1.0)
	assert_eq(image.get_size(), Vector2i(4, 4))
	assert_eq(image.get_format(), Image.FORMAT_RF)
	assert_almost_eq(image.get_pixel(1, 1).r, 5.0, 0.001)
	assert_almost_eq(image.get_pixel(2, 1).r, 9.0, 0.001)
	assert_almost_eq(image.get_pixel(2, 3).r, 9.0, 0.001)
	assert_almost_eq(image.get_pixel(0, 0).r, GodRayPass.FLOOR_Y, 0.001)
	assert_almost_eq(GodRayPass.volume_top(image), 10.0, 0.001)


func test_relief_ground_lifts_the_raster_floor() -> void:
	var image := GodRayPass.rasterize_heights(
		[] as Array[AABB], Vector2(4.0, 4.0), 1.0, func(_xz: Vector2) -> float: return 3.0
	)
	assert_almost_eq(image.get_pixel(3, 3).r, 3.0, 0.001)


func test_height_raster_rebuilds_once_streamed_masses_settle() -> void:
	# Read volume_top, not the texture: the headless dummy renderer keeps the first
	# Image behind ImageTexture.update().
	var boxes: Array[AABB] = []
	var camera := Camera3D.new()
	var pass_node := GodRayPass.new()
	pass_node.configure(camera, Vector2(8.0, 8.0), func() -> Array[AABB]: return boxes)
	var overlay := pass_node.get_node("GodRayOverlay") as MeshInstance3D
	var material := overlay.mesh.surface_get_material(0)
	var top := func() -> float: return float(material.get_shader_parameter(&"volume_top"))
	assert_almost_eq(top.call(), GodRayPass.MIN_VOLUME_TOP, 0.001)
	boxes.append(AABB(Vector3(1.0, 0.0, 1.0), Vector3(3.0, 9.0, 3.0)))
	pass_node._sync_height_map(0.1)
	pass_node._sync_height_map(0.1)
	assert_almost_eq(top.call(), GodRayPass.MIN_VOLUME_TOP, 0.001, "a growing list must wait")
	pass_node._sync_height_map(GodRayPass.REBUILD_SETTLE_SECONDS)
	assert_almost_eq(top.call(), 10.0, 0.001)
	pass_node.free()
	camera.free()


func test_not_created_indoors() -> void:
	assert_false(GodRayPass.should_create(true))
	assert_true(GodRayPass.should_create(false))
