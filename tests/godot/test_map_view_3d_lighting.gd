extends "res://tests/godot/map_view_3d_test_base.gd"

func test_night_state_is_deterministic_and_darker() -> void:
	var definition := SmithyCourtyard.create()
	var first := MapView3D.create(definition, MapBuilder.build(definition), MapView3D.TIME_NIGHT)
	var second := MapView3D.create(definition, MapBuilder.build(definition), MapView3D.TIME_NIGHT)
	assert_eq(first.sun_light().light_energy, second.sun_light().light_energy, "night sun energy must be deterministic")
	assert_eq(first.sun_light().light_color, second.sun_light().light_color, "night sun color must be deterministic")
	assert_eq(first.sun_light().rotation_degrees, second.sun_light().rotation_degrees, "night sun angle must be deterministic")
	assert_true(
		MapView3D.SUN_NIGHT_ENERGY <= MapView3D.SUN_DAY_ENERGY * 0.8,
		"night must be at least 20 percent darker than day"
	)
	first.set_time_of_day(MapView3D.TIME_DAY)
	assert_true(
		is_equal_approx(first.sun_light().light_energy, MapView3D.SUN_DAY_ENERGY),
		"day state must restore deterministically"
	)
	first.free()
	second.free()


func test_cycle_progress_interpolates_lighting_and_advances() -> void:
	var definition := SmithyCourtyard.create()
	var view := MapView3D.create(definition, MapBuilder.build(definition), MapView3D.TIME_DAY)
	view.apply_cycle_progress(0.0)
	assert_true(
		view.sun_light().light_energy <= MapView3D.SUN_DAY_ENERGY * 0.8,
		"midnight cycle point must be at least as dark as discrete night"
	)
	view.apply_cycle_progress(0.5)
	assert_true(
		is_equal_approx(view.sun_light().light_energy, MapView3D.SUN_DAY_ENERGY),
		"noon cycle point must match discrete day energy"
	)
	var before_yaw := view.sun_light().rotation_degrees.y
	view.apply_cycle_progress(0.75)
	assert_false(
		is_equal_approx(view.sun_light().rotation_degrees.y, before_yaw),
		"cycle must sweep sun yaw so shadows move"
	)
	var progress := DayNightCycle.DEFAULT_PROGRESS
	progress = DayNightCycle.advance(progress, DayNightCycle.CYCLE_DURATION_SECONDS)
	assert_true(is_equal_approx(progress, DayNightCycle.DEFAULT_PROGRESS), "one full cycle must wrap to the start")
	view.free()


func test_view_uses_calendar_sun_direction_and_seasonal_daylight() -> void:
	var definition := SmithyCourtyard.create()
	var view := MapView3D.create(definition, MapBuilder.build(definition), MapView3D.TIME_DAY)
	view.set_calendar_date({"day": 21, "month": 4, "year": 1343})
	view.apply_cycle_progress(6.0 / 24.0)
	assert_true(view.sun_light().basis.z.x > 0.0, "morning light must come from the eastern (+X) sky")
	view.apply_cycle_progress(18.0 / 24.0)
	assert_true(view.sun_light().basis.z.x < 0.0, "evening light must come from the western (-X) sky")

	view.set_calendar_date({"day": 21, "month": 12, "year": 1343})
	view.apply_cycle_progress(7.0 / 24.0)
	assert_eq(view.time_of_day, MapView3D.TIME_NIGHT, "07:00 must still be winter night in Reval")
	view.set_calendar_date({"day": 21, "month": 6, "year": 1343})
	view.apply_cycle_progress(7.0 / 24.0)
	assert_eq(view.time_of_day, MapView3D.TIME_DAY, "07:00 must be summer daylight in Reval")
	view.free()


func test_night_directional_light_follows_the_moon() -> void:
	var definition := SmithyCourtyard.create()
	var view := MapView3D.create(definition, MapBuilder.build(definition), MapView3D.TIME_NIGHT)
	var full_moon := {"day": 10, "month": 5, "year": 1343}
	view.set_calendar_date(full_moon)
	view.apply_cycle_progress(0.0)
	var expected := SkyWeather3D.lunar_direction(0.0, full_moon)
	assert_true(
		view.sun_light().basis.z.is_equal_approx(expected),
		"night shadows must point back toward the visible moon"
	)
	var midnight_direction := view.sun_light().basis.z
	view.apply_cycle_progress(3.0 / 24.0)
	assert_false(
		view.sun_light().basis.z.is_equal_approx(midnight_direction),
		"moonlight and night shadows must move as the moon crosses the sky"
	)
	view.free()


func test_night_directional_light_follows_lunar_phase_and_horizon() -> void:
	var definition := SmithyCourtyard.create()
	var view := MapView3D.create(definition, MapBuilder.build(definition), MapView3D.TIME_NIGHT)
	view.set_calendar_date({"day": 25, "month": 4, "year": 1343})
	view.apply_cycle_progress(0.0)
	var new_moon_energy := view.sun_light().light_energy
	view.set_calendar_date({"day": 10, "month": 5, "year": 1343})
	view.apply_cycle_progress(0.0)
	var full_moon_energy := view.sun_light().light_energy
	assert_true(full_moon_energy > new_moon_energy, "full moon must cast more directional light than new moon")
	assert_true(
		SkyWeather3D.moonlight_strength(0.0, {"day": 10, "month": 5, "year": 1343})
			> SkyWeather3D.moonlight_strength(0.5, {"day": 10, "month": 5, "year": 1343}),
		"physical moonlight must fade after the moon sets"
	)
	view.free()


func test_evening_window_schedule_is_deterministic_and_bounded() -> void:
	var seed := String(&"house_test_lane").hash()
	var first: Dictionary = BuildingWindowLights3D.evening_schedule_for(seed)
	var second: Dictionary = BuildingWindowLights3D.evening_schedule_for(seed)
	assert_eq(first, second, "evening schedule must be deterministic per building id")
	if bool(first.get("participates", false)):
		var start_hour := float(first["start_hour"])
		var end_hour := float(first["end_hour"])
		assert_true(start_hour >= 18.0 and start_hour <= 20.5, "evening glow should start near dusk")
		assert_true(end_hour >= 22.0 and end_hour <= 23.75, "evening glow should end before midnight")
		assert_true(end_hour > start_hour + 1.0, "lit hours must span a meaningful evening")


func test_houses_get_evening_window_lights_with_per_building_variation() -> void:
	var definition := LowerTownSlice.create()
	var participating := 0
	var skipped := 0
	var start_hours: Dictionary = {}
	for building in definition.buildings:
		if building["kind"] != MapTypes.BUILDING_KIND_HOUSE:
			continue
		var node := MapViewMeshBuilder.build_building(building, definition.cell_size)
		assert_true(node.has_node("WindowLights"), "%s: houses need evening window lights" % building["id"])
		var lights := node.get_node("WindowLights") as BuildingWindowLights3D
		var schedule: Dictionary = BuildingWindowLights3D.evening_schedule_for(String(building["id"]).hash())
		if bool(schedule.get("participates", false)):
			participating += 1
			start_hours[building["id"]] = schedule["start_hour"]
			var shared := MapViewMaterials.role(&"window")
			var found_glass := false
			var found_evening_glow := false
			for child in node.get_children():
				if not child is MeshInstance3D:
					continue
				var mesh := child as MeshInstance3D
				if not mesh.name.begins_with("Window"):
					continue
				var suffix := mesh.name.substr(6)
				if suffix.is_empty() or not suffix.is_valid_int():
					continue
				found_glass = true
				var glass_mat := mesh.material_override as StandardMaterial3D
				assert_false(
					glass_mat == shared,
					"%s: lit windows must duplicate glass materials" % building["id"]
				)
			assert_true(found_glass, "%s: participating houses still need glass panes" % building["id"])
			lights.apply_cycle_progress(22.0 / 24.0)
			for child in node.get_children():
				if not child is MeshInstance3D:
					continue
				var mesh := child as MeshInstance3D
				if not mesh.name.begins_with("Window"):
					continue
				var suffix := mesh.name.substr(6)
				if suffix.is_empty() or not suffix.is_valid_int():
					continue
				var glass_mat := mesh.material_override as StandardMaterial3D
				if glass_mat != null and glass_mat.emission_enabled and glass_mat.emission_energy_multiplier > 0.0:
					found_evening_glow = true
					break
			assert_true(
				found_evening_glow,
				"%s: at least one evening window must emit light" % building["id"]
			)
			lights.apply_cycle_progress(0.5)
			for child in node.get_children():
				if not child is MeshInstance3D:
					continue
				var mesh := child as MeshInstance3D
				if not mesh.name.begins_with("Window"):
					continue
				var suffix := mesh.name.substr(6)
				if suffix.is_empty() or not suffix.is_valid_int():
					continue
				var glass_mat := mesh.material_override as StandardMaterial3D
				if glass_mat != null and glass_mat == shared:
					continue
				assert_false(
					glass_mat.emission_enabled,
					"%s: noon must turn window glow off" % building["id"]
				)
				break
		else:
			skipped += 1
		node.free()
	assert_true(participating > 0, "most houses should participate in evening window glow")
	assert_true(skipped > 0, "some houses should stay dark for variety")
	assert_true(start_hours.size() >= 2, "evening start times must vary across houses")


func test_view_updates_window_lights_through_cycle_progress() -> void:
	var definition := SmithyCourtyard.create()
	var view := MapView3D.create(definition, MapBuilder.build(definition), MapView3D.TIME_DAY)
	var lit_at_evening := false
	var dark_at_noon := true
	for building in definition.buildings:
		if building["kind"] != MapTypes.BUILDING_KIND_HOUSE:
			continue
		var schedule: Dictionary = BuildingWindowLights3D.evening_schedule_for(String(building["id"]).hash())
		if not bool(schedule.get("participates", false)):
			continue
		var building_node := view.get_node("Buildings/Building_%s" % String(building["id"]))
		if not building_node.has_node("Window0"):
			continue
		var glass := building_node.get_node("Window0") as MeshInstance3D
		var glass_mat := glass.material_override as StandardMaterial3D
		view.apply_cycle_progress(20.0 / 24.0)
		if glass_mat.emission_enabled:
			lit_at_evening = true
		view.apply_cycle_progress(0.5)
		if glass_mat.emission_enabled:
			dark_at_noon = false
	view.free()
	assert_true(lit_at_evening, "cycle progress must light some evening windows")
	assert_true(dark_at_noon, "noon cycle progress must keep windows dark")


func test_clear_weather_preserves_authored_day_night_lighting() -> void:
	const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")
	var definition := SmithyCourtyard.create()
	var view := MapView3D.create(definition, MapBuilder.build(definition), MapView3D.TIME_DAY)
	var sky := view.sky_weather()
	sky.auto_weather = false
	sky.set_weather(SkyWeather.WEATHER_CLEAR)
	view.apply_cycle_progress(0.5)
	assert_true(
		is_equal_approx(view.sun_light().light_energy, MapView3D.SUN_DAY_ENERGY),
		"clear noon must keep the authored sun energy"
	)
	var world_env := view.get_node("ViewEnvironment") as WorldEnvironment
	assert_true(
		is_equal_approx(world_env.environment.ambient_light_energy, MapView3D.AMBIENT_DAY_ENERGY),
		"clear noon must keep the authored ambient energy"
	)
	view.apply_cycle_progress(0.0)
	assert_true(
		view.sun_light().light_energy <= MapView3D.SUN_DAY_ENERGY * 0.8,
		"clear midnight must stay at least as dark as the authored night baseline"
	)
	view.free()


func test_water_specular_dies_with_sun_disk_after_sunset() -> void:
	MapViewMaterials.reset()
	var definition := SmithyCourtyard.create()
	var view := MapView3D.create(definition, MapBuilder.build(definition), MapView3D.TIME_DAY)
	var date := {"day": 23, "month": 4, "year": 1343}
	view.set_calendar_date(date)
	view.apply_cycle_progress(0.5)
	var water := MapViewMaterials.water_surface(MapTypes.TERRAIN_DEEP_WATER)
	assert_true(
		float(water.get_shader_parameter("sun_visibility")) > 0.99,
		"noon water must keep full sun specular"
	)
	assert_true(
		float(water.get_shader_parameter("day_blend")) > 0.99,
		"noon water sky reflection must stay day-tinted"
	)

	view.apply_cycle_progress(0.0)
	assert_true(
		float(water.get_shader_parameter("sun_visibility")) < 0.01,
		"midnight must kill sun specular on water"
	)

	# Civil twilight: sun disk already gone, directional light still sun-weighted.
	var twilight_progress := -1.0
	for step in 240:
		var progress := float(step) / 240.0
		var sun_direction := SkyWeather3D.solar_direction(progress, date)
		var elevation := SkyWeather3D.solar_elevation_degrees(progress, date)
		var disk := SkyWeather3D.sun_disk_visibility(sun_direction)
		var light_weight := smoothstep(-6.0, 0.0, elevation)
		if disk < 0.05 and light_weight > 0.2 and elevation < 0.0:
			twilight_progress = progress
			break
	assert_true(twilight_progress >= 0.0, "must find a post-sunset civil-twilight sample")
	view.apply_cycle_progress(twilight_progress)
	assert_true(
		float(water.get_shader_parameter("sun_visibility")) < 0.05,
		"after the sun disk sets, water must not keep a sun specular glint"
	)
	view.free()
	MapViewMaterials.reset()


func test_water_reflections_follow_sky_catalog_cycle_and_weather() -> void:
	MapViewMaterials.reset()
	var definition := SmithyCourtyard.create()
	var view := MapView3D.create(definition, MapBuilder.build(definition), MapView3D.TIME_NIGHT)
	(Engine.get_main_loop() as SceneTree).root.add_child(view)
	var sky := view.sky_weather()
	sky.auto_weather = false
	var water := MapViewMaterials.water_surface(MapTypes.TERRAIN_DEEP_WATER)

	var full_moon := {"day": 10, "month": 5, "year": 1343}
	view.set_calendar_date(full_moon)
	view.apply_cycle_progress(0.0)
	assert_eq(
		water.get_shader_parameter("star_map"),
		sky.star_map_texture(),
		"water and sky must share one Hipparcos catalog texture"
	)
	assert_true(
		float(water.get_shader_parameter("star_visibility")) > 0.7,
		"clear midnight must reflect stars through light cloud cover"
	)
	assert_true(
		float(water.get_shader_parameter("moon_visibility")) > 0.7,
		"a high full moon must reflect through light cloud cover"
	)
	assert_true(
		(water.get_shader_parameter("moon_direction") as Vector3).is_equal_approx(
			SkyWeather3D.lunar_direction(0.0, full_moon)
		),
		"the water moon path must match the visible moon"
	)
	var midnight_sidereal := float(water.get_shader_parameter("sidereal_angle"))
	view.apply_cycle_progress(3.0 / 24.0)
	assert_false(
		is_equal_approx(float(water.get_shader_parameter("sidereal_angle")), midnight_sidereal),
		"reflected constellations must rotate with the visible sky"
	)

	sky.set_weather(SkyWeather3D.WEATHER_RAIN)
	sky.advance(SkyWeather3D.TRANSITION_SECONDS)
	view.apply_cycle_progress(0.0)
	assert_true(
		float(water.get_shader_parameter("star_visibility")) < 0.1,
		"rain clouds must occlude reflected stars"
	)
	view.queue_free()
	await (Engine.get_main_loop() as SceneTree).process_frame
	MapViewMaterials.reset()


