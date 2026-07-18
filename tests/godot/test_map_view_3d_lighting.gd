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
			assert_true(node.has_node("Window0"), "%s: participating houses still need glass panes" % building["id"])
			var glass := node.get_node("Window0") as MeshInstance3D
			var glass_mat := glass.material_override as StandardMaterial3D
			var shared := MapViewMaterials.role(&"window")
			assert_false(
				glass_mat == shared,
				"%s: lit windows must duplicate glass materials" % building["id"]
			)
			lights.apply_cycle_progress(22.0 / 24.0)
			assert_true(
				glass_mat.emission_enabled,
				"%s: evening cycle must warm window glass" % building["id"]
			)
			assert_true(
				glass_mat.emission_energy_multiplier > 0.0,
				"%s: evening windows must emit light" % building["id"]
			)
			lights.apply_cycle_progress(0.5)
			assert_false(
				glass_mat.emission_enabled,
				"%s: noon must turn window glow off" % building["id"]
			)
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


