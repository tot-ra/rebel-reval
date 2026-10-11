extends "res://tests/godot/test_case.gd"

## WS-10: the sky-view LUT node builds its HDR viewport at the tier size, throttles renders by
## sky_lut_every_n_frames, fails closed to the gradient sky without the WS-09 LUTs, and its
## shader ports the Hillaire non-linear latitude mapping on top of atmosphere_common.

const SkyAtmosphereLutScript := preload("res://scripts/map/view3d/sky_atmosphere_lut.gd")
const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")
const LUT_SHADER_PATH := "res://scripts/map/view3d/sky_view_lut.gdshader"
const SKY_SHADER_PATH := "res://scripts/map/view3d/sky_weather_3d.gdshader"
const NOON_SUN := Vector3(0.5, 0.866, 0.0)

# gdlint: disable=max-line-length


func test_viewport_matches_tier_size() -> void:
	for tier in SkyWeather.QUALITY_TIER_IDS:
		var settings := SkyWeather.quality_settings(tier)
		var lut = SkyAtmosphereLutScript.new()
		var size: Vector2i = settings["sky_lut_size"]
		assert_true(lut.configure(size, int(settings["sky_lut_every_n_frames"])), "%s LUT must build" % tier)
		assert_true(lut.is_available(), "%s LUT must report available" % tier)
		var viewport: SubViewport = lut.viewport()
		assert_eq(viewport.size, size, "%s viewport must use the tier LUT size" % tier)
		assert_true(viewport.use_hdr_2d, "the LUT stores HDR radiance, not RGBM")
		assert_true(lut.sky_view_texture() != null, "%s LUT must expose its texture" % tier)
		lut.free()
	var recommended := SkyWeather.quality_settings(SkyWeather.QUALITY_RECOMMENDED)
	var minimum := SkyWeather.quality_settings(SkyWeather.QUALITY_MINIMUM)
	assert_eq(recommended["sky_lut_size"], Vector2i(192, 108), "recommended uses the Tidewater 192x108 LUT")
	assert_eq(recommended["sky_lut_every_n_frames"], 1, "recommended renders the LUT every frame")
	assert_eq(minimum["sky_lut_size"], Vector2i(96, 54), "minimum uses a half-size LUT")
	assert_eq(minimum["sky_lut_every_n_frames"], 2, "minimum renders the LUT every second frame")


func test_update_throttle_follows_every_n_frames() -> void:
	var lut = SkyAtmosphereLutScript.new()
	lut.configure(SkyAtmosphereLutScript.SIZE_MINIMUM, 2)
	assert_true(lut.update(NOON_SUN, 10), "the first update always renders")
	assert_false(lut.update(NOON_SUN, 11), "every_n = 2 skips the next frame")
	assert_true(lut.update(NOON_SUN, 12), "every_n = 2 renders on the second frame")
	assert_eq(lut.viewport().render_target_update_mode, SubViewport.UPDATE_ONCE, "a render is scheduled once")
	# A sun jump (capture, save restore) must never reuse a stale LUT inside a skipped frame.
	var low_sun := Vector3(0.996, 0.087, 0.0)
	assert_true(lut.update(low_sun, 13), "a large sun change forces a render")
	assert_eq(lut.render_count, 3, "render_count tracks scheduled renders")
	lut.set_tier(SkyAtmosphereLutScript.SIZE_RECOMMENDED, 1)
	assert_true(lut.update(low_sun, 14), "the first update after a tier change renders")
	assert_true(lut.update(low_sun, 15), "every_n = 1 renders every frame")
	lut.free()


func test_missing_assets_fall_back_to_gradient() -> void:
	var lut = SkyAtmosphereLutScript.new()
	var built: bool = lut.configure(
		SkyAtmosphereLutScript.SIZE_RECOMMENDED, 1, "res://assets/sky/atmosphere/missing_transmittance.exr"
	)
	assert_false(built, "a missing transmittance LUT must not build the viewport")
	assert_false(lut.is_available(), "a missing LUT reports unavailable")
	assert_true(lut.viewport() == null, "no viewport is created without the baked LUTs")
	assert_false(lut.update(NOON_SUN, 1), "an unavailable LUT never schedules renders")
	lut.free()
	# SkyWeather3D keeps the gradient sky when the LUT is unavailable.
	var sky = SkyWeather.new()
	var environment := Environment.new()
	var camera := Camera3D.new()
	sky.configure(camera, environment)
	var material := environment.sky.sky_material as ShaderMaterial
	assert_true(sky.uses_atmosphere_lut(), "the shipped WS-09 assets enable the physical sky")
	assert_true(bool(material.get_shader_parameter(&"sky_lut_available")), "the sky shader samples the LUT")
	sky.atmosphere_lut().configure(
		SkyAtmosphereLutScript.SIZE_RECOMMENDED, 1, "res://missing.exr", "res://missing.exr"
	)
	sky.set_quality_tier(SkyWeather.QUALITY_MINIMUM)
	assert_false(sky.uses_atmosphere_lut(), "a failed LUT build disables the physical sky")
	assert_false(
		bool(material.get_shader_parameter(&"sky_lut_available")),
		"the sky shader falls back to the gradient when the LUT is missing"
	)
	sky.free()
	camera.free()


func test_sky_weather_binds_lut_at_tier_size() -> void:
	var sky = SkyWeather.new()
	var environment := Environment.new()
	var camera := Camera3D.new()
	sky.configure(camera, environment)
	var material := environment.sky.sky_material as ShaderMaterial
	assert_eq(sky.atmosphere_lut().lut_size, Vector2i(192, 108), "recommended binds the full-size LUT")
	assert_eq(material.get_shader_parameter(&"sky_lut_size"), Vector2(192, 108), "the sky shader knows the LUT grid")
	assert_true(material.get_shader_parameter(&"sky_view_lut") != null, "the sky shader samples the LUT texture")
	assert_true(
		material.get_shader_parameter(&"atmosphere_transmittance_lut") != null,
		"the sun disk and clouds read the transmittance LUT"
	)
	sky.set_quality_tier(SkyWeather.QUALITY_MINIMUM)
	assert_eq(sky.atmosphere_lut().lut_size, Vector2i(96, 54), "minimum resizes the LUT")
	assert_eq(material.get_shader_parameter(&"sky_lut_size"), Vector2(96, 54), "the sky shader follows the resize")
	var before: int = sky.atmosphere_lut().render_count
	sky.apply_sky_state(0.5, 1.0, NOON_SUN)
	assert_eq(sky.atmosphere_lut().render_count, before + 1, "apply_sky_state drives the LUT update")
	sky.free()
	camera.free()


func test_lut_shader_ports_non_linear_latitude_mapping() -> void:
	var source := FileAccess.get_file_as_string(LUT_SHADER_PATH)
	assert_true(
		source.contains('#include "res://scripts/map/view3d/atmosphere_common.gdshaderinc"'),
		"the LUT shader must share the WS-09 atmosphere include"
	)
	assert_true(source.contains("float c = 1.0 - 2.0 * unit.y;"), "upper half squares towards the horizon")
	assert_true(source.contains("c = 1.0 - c * c;"), "upper half uses 1 - (1 - 2 uv)^2")
	assert_true(source.contains("cos_view_zenith = cos(zh * c);"), "upper half maps to cos(zh * c)")
	assert_true(source.contains("cos_view_zenith = cos(zh + beta * c);"), "lower half maps to cos(zh + beta * c)")
	assert_true(
		source.contains("cos_light_view = -(unit.x * unit.x * 2.0 - 1.0);"),
		"azimuth uses the squared sun-relative mapping"
	)
	assert_true(source.contains("MARCH_STEPS = 30"), "the LUT marches 30 steps")
	var sky_source := FileAccess.get_file_as_string(SKY_SHADER_PATH)
	assert_true(sky_source.contains("uniform float sky_exposure"), "art exposure stays available")
	assert_true(sky_source.contains("uniform vec4 sky_tint"), "art tint stays available")
	assert_true(sky_source.contains("uniform float sunset_boost"), "art sunset boost stays available")
	var shader := load(LUT_SHADER_PATH) as Shader
	assert_true(shader != null and shader.get_mode() == Shader.MODE_CANVAS_ITEM, "the LUT is a canvas_item pass")
