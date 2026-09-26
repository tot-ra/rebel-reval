extends "res://tests/godot/map_view_3d_test_base.gd"

const Lighting := preload("res://scripts/map/view3d/map_view_lighting.gd")


func test_post_process_grade_is_enabled_with_frozen_values() -> void:
	var definition := SmithyCourtyard.create()
	var view := MapView3D.create(definition, MapBuilder.build(definition), MapView3D.TIME_DAY)
	var env := (view.get_node("ViewEnvironment") as WorldEnvironment).environment

	assert_eq(env.tonemap_mode, MapView3D.TONEMAP_MODE, "tonemap must use the frozen AgX mapper")
	assert_true(env.adjustment_enabled, "color adjustment must stay enabled")
	assert_true(env.glow_enabled, "glow must stay enabled for emissive highlights")
	assert_true(is_equal_approx(env.glow_hdr_threshold, MapView3D.GLOW_HDR_THRESHOLD))
	assert_true(is_equal_approx(env.glow_bloom, MapView3D.GLOW_BLOOM))
	assert_true(is_equal_approx(env.glow_strength, MapView3D.GLOW_STRENGTH))
	assert_true(is_equal_approx(env.glow_mix, MapView3D.GLOW_MIX))

	view.apply_cycle_progress(0.5)
	assert_true(is_equal_approx(env.tonemap_exposure, MapView3D.GRADE_DAY_EXPOSURE))
	assert_true(is_equal_approx(env.adjustment_saturation, MapView3D.GRADE_DAY_SATURATION))
	assert_true(is_equal_approx(env.adjustment_contrast, MapView3D.GRADE_DAY_CONTRAST))
	assert_true(is_equal_approx(env.adjustment_brightness, MapView3D.GRADE_DAY_BRIGHTNESS))
	assert_true(is_equal_approx(env.glow_intensity, MapView3D.GLOW_INTENSITY_DAY))

	view.apply_cycle_progress(0.0)
	assert_true(is_equal_approx(env.tonemap_exposure, MapView3D.GRADE_NIGHT_EXPOSURE))
	assert_true(is_equal_approx(env.adjustment_saturation, MapView3D.GRADE_NIGHT_SATURATION))
	assert_true(is_equal_approx(env.adjustment_contrast, MapView3D.GRADE_NIGHT_CONTRAST))
	assert_true(is_equal_approx(env.adjustment_brightness, MapView3D.GRADE_NIGHT_BRIGHTNESS))
	assert_true(is_equal_approx(env.glow_intensity, MapView3D.GLOW_INTENSITY_NIGHT))
	view.free()


func test_post_grade_night_stays_at_least_twenty_percent_darker_than_day() -> void:
	var day_proxy := Lighting.post_grade_luminance_proxy(1.0)
	var night_proxy := Lighting.post_grade_luminance_proxy(0.0)
	assert_true(
		night_proxy <= day_proxy * 0.8,
		"night post-grade proxy must be at least 20 percent darker than day"
	)


func test_post_grade_differs_from_ungraded_baseline() -> void:
	var graded := Environment.new()
	Lighting.configure_post_process(graded)
	Lighting.apply_post_grade(graded, 0.5)

	var baseline := Environment.new()
	assert_ne(baseline.tonemap_mode, graded.tonemap_mode, "graded tonemap must differ from default")
	assert_false(baseline.adjustment_enabled, "baseline must stay unadjusted for contrast")
	assert_false(baseline.glow_enabled, "baseline must stay without glow for contrast")
	assert_true(
		graded.adjustment_saturation > 1.0,
		"ADR 0018 grade must preserve a saturated Baltic palette"
	)
	assert_true(
		graded.glow_hdr_threshold >= 1.0,
		"glow must stay selective so matte plaster does not bloom with windows"
	)
	assert_true(
		Lighting.AMBIENT_NIGHT_ENERGY >= 0.85,
		"night ambient fill must keep local color readable outside emissive pools"
	)
	assert_true(
		Lighting.SUN_NIGHT_ENERGY <= Lighting.SUN_DAY_ENERGY * 0.8,
		"night sun must remain at least 20 percent dimmer than day"
	)


func test_night_ground_mist_stays_darker_than_night_ambient_and_pales_toward_sunrise() -> void:
	var sunrise := 5.0
	var night := _mist_presentation(0.0, sunrise - 2.0, sunrise)
	var environment := Environment.new()
	Lighting.apply_ground_mist(environment, night, false)
	assert_true(environment.fog_enabled, "fog-prone pre-dawn night must still raise mist")
	assert_true(Lighting.morning_mist_factor(sunrise - 2.0, sunrise) > 0.0)
	var night_luma := _linear_luminance(environment.fog_light_color)
	assert_true(
		night_luma <= _linear_luminance(Lighting.AMBIENT_NIGHT_COLOR) + 0.0001,
		"night mist must not outshine night ambient fill"
	)
	var previous := night_luma
	for blend: float in [0.15, 0.35, 0.5, 0.75, 1.0]:
		var toward_dawn := _mist_presentation(blend, sunrise - 0.25, sunrise)
		Lighting.apply_ground_mist(environment, toward_dawn, false)
		var luma := _linear_luminance(environment.fog_light_color)
		assert_true(
			luma + 0.0001 >= previous,
			"mist light colour must rise monotonically toward sunrise"
		)
		previous = luma
	var dawn := _mist_presentation(0.5, sunrise, sunrise)
	Lighting.apply_ground_mist(environment, dawn, false)
	assert_true(
		_linear_luminance(environment.fog_light_color) > night_luma + 0.05,
		"dawn mist must read paler than the night haze"
	)


func test_peak_dawn_mist_keeps_the_waterline_readable() -> void:
	var sunrise := 5.0
	var dawn := _mist_presentation(0.5, sunrise, sunrise)
	var environment := Environment.new()
	Lighting.apply_ground_mist(environment, dawn, false)
	assert_true(environment.fog_enabled, "peak dawn on a fog-prone morning must still raise mist")
	assert_true(
		is_equal_approx(environment.fog_density, Lighting.FOG_MAX_DENSITY),
		"dry dawn density must stay the capped distance veil"
	)
	assert_true(
		is_equal_approx(environment.fog_height_density, Lighting.FOG_MAX_HEIGHT_DENSITY),
		"dry dawn height density must stay the capped waterline term"
	)
	var cover := Lighting.waterline_height_fog_cover(1.0)
	assert_true(
		cover >= Lighting.FOG_WATERLINE_COVER_MIN,
		"dawn mist must still read as ground haze, not clear air"
	)
	assert_true(
		cover <= Lighting.FOG_WATERLINE_COVER_MAX,
		"dawn mist must leave boats and the waterline readable"
	)
	var night := _mist_presentation(0.0, sunrise - 2.0, sunrise)
	Lighting.apply_ground_mist(environment, night, false)
	assert_true(environment.fog_enabled, "pre-dawn night must keep the thinner dark haze")
	assert_true(
		environment.fog_height_density < Lighting.FOG_MAX_HEIGHT_DENSITY,
		"night height density must stay below the dawn peak"
	)


func test_rain_haze_density_is_unchanged_when_morning_mist_is_absent() -> void:
	var noon_rain := _mist_presentation(1.0, 12.0, 5.0)
	noon_rain.rain_intensity = 1.0
	noon_rain.fog_potential = 0.0
	var environment := Environment.new()
	Lighting.apply_ground_mist(environment, noon_rain, false)
	assert_true(environment.fog_enabled, "noon rain must still add distant haze")
	assert_true(
		is_equal_approx(environment.fog_density, 0.0035),
		"rain-only haze density must stay on the previous 0.0035 term"
	)
	assert_true(
		is_equal_approx(environment.fog_height_density, 0.0),
		"rain-only haze must not add height fog"
	)


func test_rain_haze_color_is_unchanged_when_morning_mist_is_absent() -> void:
	var noon_rain := _mist_presentation(1.0, 12.0, 5.0)
	noon_rain.rain_intensity = 1.0
	noon_rain.fog_potential = 0.0
	var environment := Environment.new()
	Lighting.apply_ground_mist(environment, noon_rain, false)
	assert_true(environment.fog_enabled, "noon rain must still add distant haze")
	var expected := Color8(34, 42, 58).lerp(Color8(145, 157, 168), 1.0)
	assert_true(
		environment.fog_light_color.is_equal_approx(expected),
		"rain-only haze must keep the previous day-blend lerp"
	)


func test_overcast_lighting_pushes_preset_cloud_darken_to_water() -> void:
	MapViewMaterials.reset()
	var definition := SmithyCourtyard.create()
	var view := MapView3D.create(definition, MapBuilder.build(definition), MapView3D.TIME_DAY)
	var sky := view.sky_weather()
	sky.auto_weather = false
	sky.set_weather(SkyWeather3D.WEATHER_CLEAR)
	view.apply_cycle_progress(0.5)
	var water := MapViewMaterials.water_surface(MapTypes.TERRAIN_DEEP_WATER)
	var clear_darken := float(SkyWeather3D.PROFILES[SkyWeather3D.WEATHER_CLEAR]["darken"])
	assert_almost_eq(
		float(water.get_shader_parameter("cloud_darken")),
		clear_darken,
		0.0001,
		"clear noon water must receive the clear preset darken"
	)
	assert_almost_eq(
		float(water.get_shader_parameter("sunset_factor")),
		sky.sunset_factor,
		0.0001,
		"noon water sunset_factor must match the sky snapshot"
	)

	sky.set_weather(SkyWeather3D.WEATHER_OVERCAST)
	view.apply_cycle_progress(0.5)
	var overcast_darken := float(
		SkyWeather3D.PROFILES[SkyWeather3D.WEATHER_OVERCAST]["darken"]
	)
	assert_almost_eq(overcast_darken, 0.72, 0.0001, "overcast preset darken is 0.72")
	assert_almost_eq(
		float(water.get_shader_parameter("cloud_darken")),
		overcast_darken,
		0.0001,
		"overcast lighting must push preset darken onto cached water"
	)
	assert_almost_eq(
		Lighting.water_cloud_darken(sky.presentation_snapshot(0.5, 1.0)),
		overcast_darken,
		0.0001,
		"lighting helper must expose the same overcast darken"
	)
	view.free()
	MapViewMaterials.reset()


func _mist_presentation(
	day_blend: float, hour: float, sunrise: float
) -> SkyWeather3D.WeatherPresentation:
	var presentation := SkyWeather3D.WeatherPresentation.new()
	presentation.cycle_progress = hour / 24.0
	presentation.day_blend = day_blend
	presentation.sunrise_hour = sunrise
	presentation.fog_potential = 1.0
	presentation.fog_quality = 1.0
	presentation.wind_strength = 0.0
	presentation.rain_intensity = 0.0
	return presentation


func _linear_luminance(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
