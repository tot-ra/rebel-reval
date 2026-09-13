extends "res://tests/godot/test_case.gd"

const Weather := preload("res://scripts/map/view3d/sky_weather_3d.gd")
const Lighting := preload("res://scripts/map/view3d/map_view_lighting.gd")


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
