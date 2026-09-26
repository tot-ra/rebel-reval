extends "res://tests/godot/test_case.gd"

const Weather := preload("res://scripts/map/view3d/sky_weather_3d.gd")
const Lighting := preload("res://scripts/map/view3d/map_view_lighting.gd")
const Atmosphere := preload("res://scripts/map/view3d/atmosphere_cpu.gd")


func test_legacy_linear_transition_resumes_without_a_zero_time_jump() -> void:
	var source := Weather.new()
	source.auto_weather = false
	source.set_weather(Weather.WEATHER_RAIN)
	var legacy = source.snapshot_state()
	legacy.transition_progress = 0.25
	for key in legacy.current_profile:
		legacy.current_profile[key] = lerpf(
			float(Weather.PROFILES[Weather.WEATHER_CLEAR][key]),
			float(Weather.PROFILES[Weather.WEATHER_RAIN][key]), 0.25
		)
	# Old rain lighting target was 0.32, not the new diffused 0.07.
	legacy.current_profile["sun_energy"] = lerpf(1.0, 0.32, 0.25)
	var restored := Weather.new()
	assert_true(restored.restore_state(legacy))
	var before := restored.rain_intensity()
	var light_before: float = restored.lighting_modifiers()["sun_energy"]
	restored.advance(0.0)
	assert_eq(restored.rain_intensity(), before, "paused legacy rain must not jump")
	assert_eq(restored.lighting_modifiers()["sun_energy"], light_before)
	restored.advance(0.01)
	assert_true(absf(restored.rain_intensity() - before) < 0.005)
	restored.advance(Weather.TRANSITION_SECONDS)
	assert_eq(restored.rain_intensity(), 1.0)
	source.free()
	restored.free()


func test_rain_haze_uses_snapshot_and_is_excluded_from_interiors() -> void:
	var sky := Weather.new()
	sky.auto_weather = false
	var environment := Environment.new()
	Lighting.apply_ground_mist(environment, sky.presentation_snapshot(0.5, 1.0), false)
	assert_false(environment.fog_enabled, "dry noon stays clear")
	sky.set_weather(Weather.WEATHER_RAIN)
	sky.advance(Weather.TRANSITION_SECONDS)
	var rainy := sky.presentation_snapshot(0.5, 1.0)
	Lighting.apply_ground_mist(environment, rainy, false)
	assert_true(environment.fog_enabled, "rain extinction must work at noon")
	assert_true(environment.fog_density > 0.002 and environment.fog_density < 0.005)
	assert_eq(environment.fog_height_density, 0.0, "rain haze fills distant air")
	var density := environment.fog_density
	sky.set_weather(Weather.WEATHER_CLEAR)
	sky.advance(Weather.TRANSITION_SECONDS)
	Lighting.apply_ground_mist(environment, rainy, false)
	assert_eq(environment.fog_density, density, "held snapshot is independent of new weather")
	Lighting.apply_ground_mist(environment, rainy, true)
	assert_false(environment.fog_enabled, "roofed rooms exclude rain haze")
	Lighting.apply_ground_mist(environment, sky.presentation_snapshot(0.5, 1.0), false)
	assert_false(environment.fog_enabled, "clear weather removes stale rain fog")
	sky.free()


func test_overcast_preserves_fill_while_suppressing_direct_light() -> void:
	var sky := Weather.new()
	sky.auto_weather = false
	sky.set_weather(Weather.WEATHER_OVERCAST)
	sky.advance(Weather.TRANSITION_SECONDS)
	var light := sky.lighting_modifiers()
	assert_true(float(light["sun_energy"]) < 0.15)
	assert_true(float(light["ambient_energy"]) > 0.85, "clouds diffuse rather than erase light")
	assert_eq(sky.rain_intensity(), 0.0, "overcast alone does not mean rain")
	sky.free()


func test_eased_transition_starts_gently_and_survives_interruption() -> void:
	var sky := Weather.new()
	sky.auto_weather = false
	sky.set_weather(Weather.WEATHER_RAIN)
	sky.advance(Weather.TRANSITION_SECONDS * 0.1)
	assert_true(sky.rain_intensity() > 0.0 and sky.rain_intensity() < 0.05)
	var before := sky.rain_intensity()
	sky.set_weather(Weather.WEATHER_CLEAR)
	sky.advance(0.0)
	assert_eq(sky.rain_intensity(), before, "interruption starts at current visible rain")
	sky.advance(Weather.TRANSITION_SECONDS)
	assert_eq(sky.rain_intensity(), 0.0)
	sky.free()


func test_rain_uses_world_wind_and_keeps_shelter_suppression() -> void:
	var sky := Weather.new()
	sky.auto_weather = false
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(sky)
	var camera := Camera3D.new()
	sky.add_child(camera)
	sky.configure(camera, Environment.new())
	sky.set_weather(Weather.WEATHER_RAIN)
	sky.advance(Weather.TRANSITION_SECONDS)
	var rain := sky.get_node("Rain") as GPUParticles3D
	var material := rain.process_material as ParticleProcessMaterial
	var horizontal := Vector2(material.direction.x, material.direction.z).normalized()
	assert_true(horizontal.dot(sky.wind_direction_xz()) > 0.999)
	assert_true(material.direction.y < -0.9, "wind must not make rain fly sideways")
	sky.rain_suppressed = true
	sky.advance(0.0)
	assert_false(rain.visible)
	sky.free()


## WS-11: the sun, skylight and mist take their colour from AtmosphereCpu; the *_ART_TINT
## constants multiply it and the legacy colours stay the missing-LUT fallback.
func test_physical_sun_colour_drives_the_light_through_the_art_tint() -> void:
	var sky := Weather.new()
	sky.auto_weather = false
	var low := sky.presentation_snapshot(_evening_progress_for(2.0), 0.74)
	assert_true(low.atmosphere_available, "the WS-09 LUTs feed the presentation")
	var light := Lighting.sun_light_color(low, 1.0)
	assert_true(
		light.is_equal_approx(low.physical_sun_color * Lighting.SUN_ART_TINT),
		"a clear horizon sun is the physical colour times the art tint"
	)
	assert_true(light.r > light.g and light.g > light.b, "the 2 degree sun is orange-red")
	assert_true(
		low.sun_reflection_color.is_equal_approx(low.physical_sun_color),
		"water glitter uses the same physical sun colour"
	)
	var overcast := sky.presentation_snapshot(_evening_progress_for(2.0), 0.74)
	overcast.overcast = 1.0
	assert_true(
		Lighting.sun_light_color(overcast, 1.0).is_equal_approx(Lighting.OVERCAST_LIGHT_COLOR),
		"overcast stays authoritative on top of physics"
	)
	var fallback := sky.presentation_snapshot(0.5, 1.0)
	fallback.atmosphere_available = false
	assert_true(
		Lighting.sun_light_color(fallback, 1.0).is_equal_approx(Lighting.SUN_DAY_COLOR),
		"without LUTs noon keeps the legacy SUN_DAY_COLOR"
	)
	sky.free()


func test_noon_sun_keeps_authored_energy_and_low_sun_follows_transmittance() -> void:
	var sky := Weather.new()
	sky.auto_weather = false
	var noon := sky.presentation_snapshot(0.5, 1.0)
	assert_almost_eq(noon.physical_sun_energy, 1.0, 0.001, "energy is relative to local noon")
	assert_almost_eq(Lighting.sun_light_energy(noon), Lighting.SUN_DAY_ENERGY, 0.001)
	var low := sky.presentation_snapshot(_evening_progress_for(2.0), 1.0)
	assert_true(low.physical_sun_energy < 0.3, "a 2 degree sun loses most of its energy")
	assert_almost_eq(
		Lighting.sun_light_energy(low),
		Lighting.SUN_DAY_ENERGY
			* clampf(low.physical_sun_energy, Lighting.PHYSICAL_SUN_ENERGY_MIN, 1.0)
			* low.weather_sun_energy,
		0.001,
		"physical energy replaces SUNSET_ENERGY_DIM instead of stacking on it"
	)
	sky.free()


func test_ambient_takes_the_skylight_hue_at_the_calibrated_luminance() -> void:
	var sky := Weather.new()
	sky.auto_weather = false
	var noon := sky.presentation_snapshot(0.5, 1.0)
	var ambient := Lighting.ambient_day_color(noon)
	assert_true(ambient.b > ambient.g and ambient.g > ambient.r, "noon shadows fill with blue sky")
	assert_almost_eq(
		Atmosphere.luminance(ambient.srgb_to_linear()),
		Atmosphere.luminance(Lighting.AMBIENT_DAY_COLOR.srgb_to_linear()),
		0.002,
		"only the hue is physical; the tuned ambient luminance stays"
	)
	var dusk := sky.presentation_snapshot(_evening_progress_for(-3.0), 0.16)
	var violet := Lighting.ambient_day_color(dusk)
	assert_true(violet.r > violet.g and violet.b > violet.g, "civil-twilight skylight is violet")
	sky.free()


func test_mist_takes_the_horizon_hue_but_rain_stays_rain() -> void:
	var sky := Weather.new()
	sky.auto_weather = false
	var sunrise := sky.presentation_snapshot(_evening_progress_for(2.0), 0.74)
	var physical := Lighting.physical_hue(sunrise.horizon_display_color, Lighting.FOG_MORNING_COLOR)
	var mist := Lighting.ground_mist_light_color(1.0, 1.0, 0.0, physical)
	assert_true(mist.is_equal_approx(physical), "day mist is horizon-coloured")
	assert_true(mist.r > mist.b, "low-sun horizon mist is warm, not grey")
	var rain := Lighting.ground_mist_light_color(1.0, 0.0, 1.0, physical)
	assert_true(
		rain.is_equal_approx(Lighting.ground_mist_light_color(1.0, 0.0, 1.0)),
		"full rain haze keeps today's rain colour"
	)
	sky.free()


static func _evening_progress_for(target_deg: float) -> float:
	var lo := 0.5
	var hi := 1.0
	for _i in 40:
		var mid := (lo + hi) * 0.5
		if Weather.solar_elevation_degrees(mid, Weather.GAME_CALENDAR.DEFAULT_DATE) > target_deg:
			lo = mid
		else:
			hi = mid
	return (lo + hi) * 0.5
