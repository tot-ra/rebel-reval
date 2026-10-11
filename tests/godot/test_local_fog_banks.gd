extends "res://tests/godot/test_case.gd"

const Banks := preload("res://scripts/map/view3d/local_fog_banks.gd")
const Mirage := preload("res://scripts/map/view3d/horizon_mirage.gd")
const Lighting := preload("res://scripts/map/view3d/map_view_lighting.gd")
const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")


func _presentation(sun_y: float = 0.7) -> SkyWeather.WeatherPresentation:
	var p := SkyWeather.WeatherPresentation.new()
	p.sun_direction = Vector3(0.0, sun_y, -1.0).normalized()
	p.sun_direction = Vector3(0.0, sun_y, -sqrt(maxf(1.0 - sun_y * sun_y, 0.0)))
	p.moon_direction = Vector3.DOWN
	p.sun_visibility = 1.0 if sun_y > 0.0 else 0.0
	p.sun_cloud_clear = 1.0
	p.sun_energy = 1.0
	p.day_blend = 1.0 if sun_y > 0.0 else 0.0
	p.cycle_progress = 0.5
	p.sunrise_hour = 5.0
	p.wind_strength = 0.1
	return p


func test_dry_clear_noon_has_no_fog() -> void:
	assert_eq(Banks.density_for(_presentation()), 0.0)


func test_damp_calm_air_makes_fog_and_wind_blows_it_away() -> void:
	var calm := _presentation()
	calm.overcast = 0.75
	calm.cloud_coverage = 0.98
	calm.puddle_wetness = 0.6
	var calm_density := Banks.density_for(calm)
	assert_true(calm_density > 0.4, "overcast damp air must hold fog: %s" % calm_density)
	var windy := _presentation()
	windy.overcast = 0.75
	windy.cloud_coverage = 0.98
	windy.puddle_wetness = 0.6
	windy.wind_strength = 0.95
	assert_true(Banks.density_for(windy) < calm_density * 0.5, "wind must disperse the fog")


func test_fog_quality_tier_scales_density() -> void:
	var full := _presentation()
	full.overcast = 0.75
	full.cloud_coverage = 0.98
	var reduced := _presentation()
	reduced.overcast = 0.75
	reduced.cloud_coverage = 0.98
	reduced.fog_quality = 0.65
	assert_true(Banks.density_for(reduced) < Banks.density_for(full))


func test_water_affinity_falls_with_distance_and_far_land_gets_none() -> void:
	assert_eq(Banks.affinity_for_distance(0.0), 1.0)
	assert_true(Banks.affinity_for_distance(20.0) > Banks.affinity_for_distance(40.0))
	assert_eq(Banks.affinity_for_distance(Banks.WATER_REACH), 0.0)
	assert_eq(Banks.cell_target(1.0, 0.0, 1.0), 0.0, "no water nearby, no bank")


func test_patches_leave_most_of_a_dry_shore_clear_and_are_deterministic() -> void:
	assert_eq(Banks.patch_at(Vector2(31.0, -12.0), 40.0), Banks.patch_at(Vector2(31.0, -12.0), 40.0))
	var covered := 0
	var samples := 400
	for i in samples:
		var xz := Vector2(float(i % 20), float(i / 20)) * 37.0
		if Banks.cell_target(0.5, 1.0, Banks.patch_at(xz, 0.0)) > 0.03:
			covered += 1
	assert_true(covered > 0, "some shore must be foggy")
	assert_true(covered < samples * 0.6, "fog must be local, not everywhere: %d" % covered)
	assert_true(Banks.patch_mask(0.5, 1.0) > Banks.patch_mask(0.5, 0.0), "damper air covers more")


func test_fog_light_follows_sun_then_moon_and_flashes_with_lightning() -> void:
	var day := Banks.light_params(_presentation())
	assert_true(float(day["light_amount"]) > 0.9)
	assert_almost_eq((day["light_dir"] as Vector3).y, 0.7, 0.01)
	var night := _presentation(-0.4)
	night.lunar_light_strength = 1.0
	night.moon_cloud_clear = 1.0
	night.moon_direction = Vector3(0.0, 0.5, -0.8).normalized()
	var moon := Banks.light_params(night)
	assert_true(float(moon["light_amount"]) < float(day["light_amount"]))
	assert_true((moon["light_dir"] as Vector3).y > 0.0, "moon side is lit at night")
	assert_true(float(moon["ambient_amount"]) < float(day["ambient_amount"]))
	night.lightning = 1.0
	assert_true(
		float(Banks.light_params(night)["ambient_amount"]) > float(moon["ambient_amount"]) + 0.5,
		"lightning lights the fog"
	)


func test_heat_needs_a_high_summer_sun_clear_calm_and_dry() -> void:
	assert_eq(Lighting.heat_amount(_presentation(0.67)), 0.0, "April noon is not hot")
	var summer := _presentation(0.81)
	summer.wind_strength = 0.1
	assert_true(Lighting.heat_amount(summer) > 0.7)
	summer.cloud_coverage = 0.9
	assert_eq(Lighting.heat_amount(summer), 0.0, "cloud shuts the shimmer")
	var rainy := _presentation(0.81)
	rainy.rain_intensity = 0.6
	assert_eq(Lighting.heat_amount(rainy), 0.0)
	assert_true(Mirage.strength_for(_presentation(0.81)) > 0.5)


func test_horizon_haze_is_faint_by_default_and_thickens_with_heat_and_damp() -> void:
	var base := Lighting.horizon_haze_amount(_presentation(0.5))
	assert_almost_eq(base, Lighting.HORIZON_HAZE_BASE, 0.001)
	assert_true(Lighting.horizon_haze_amount(_presentation(0.81)) > base, "heat thickens it")
	var damp := _presentation(0.5)
	damp.overcast = 0.75
	assert_true(Lighting.horizon_haze_amount(damp) > base, "damp air thickens it")


func test_horizon_haze_drives_distance_fog_without_ground_mist() -> void:
	var environment := Environment.new()
	var noon := _presentation(0.5)
	Lighting.apply_ground_mist(environment, noon, false)
	assert_false(environment.fog_enabled, "no haze requested keeps the sky clear")
	Lighting.apply_ground_mist(environment, noon, false, 1.0)
	assert_true(environment.fog_enabled)
	assert_almost_eq(environment.fog_density, Lighting.HORIZON_HAZE_DENSITY, 0.0001)
	assert_eq(environment.fog_height_density, 0.0, "pure distance haze has no height fog")
	Lighting.apply_ground_mist(environment, noon, true, 1.0)
	assert_false(environment.fog_enabled, "roofed rooms exclude the haze")


func test_banks_claim_cells_near_water_only_and_fade_in() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var camera := Camera3D.new()
	tree.root.add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 30.0, 30.0), Vector3(0.0, 0.0, 0.0), Vector3.UP)
	var banks := Banks.new()
	tree.root.add_child(banks)
	# Sea for x < -8; everything east of that is land.
	banks.configure(camera, func(xz: Vector2) -> float: return 0.0 if xz.x < -8.0 else NAN)
	var damp := _presentation()
	damp.overcast = 0.9
	damp.cloud_coverage = 0.98
	damp.puddle_wetness = 1.0
	damp.wind_strength = 0.0
	damp.sun_energy = 0.1
	for i in 600:
		banks.update(0.1, damp, 5000.0 + float(i) * 0.1)
	var shown := banks.visible_bank_count()
	assert_true(shown > 0, "damp calm air near water must raise banks")
	for bank in banks.banks():
		if bank.emitter.visible:
			var cell_x := banks._cell_center(bank.cell).x
			assert_true(cell_x < 8.0 + Banks.WATER_REACH, "bank at x=%s is far from water" % cell_x)
	# The air dries out: banks fade away and the slots free up.
	var dry := _presentation()
	for i in 600:
		banks.update(0.1, dry, 5060.0 + float(i) * 0.1)
	assert_eq(banks.visible_bank_count(), 0, "dry air must clear every bank")
	banks.free()
	camera.free()


func test_no_water_no_banks() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var camera := Camera3D.new()
	tree.root.add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 30.0, 30.0), Vector3.ZERO, Vector3.UP)
	var banks := Banks.new()
	tree.root.add_child(banks)
	banks.configure(camera, Callable())
	var damp := _presentation()
	damp.overcast = 0.9
	damp.cloud_coverage = 0.98
	damp.puddle_wetness = 1.0
	for i in 200:
		banks.update(0.1, damp, 100.0 + float(i) * 0.1)
	assert_eq(banks.visible_bank_count(), 0)
	banks.free()
	camera.free()


func test_not_created_indoors() -> void:
	assert_false(Banks.should_create(true))
	assert_false(Mirage.should_create(true))
	assert_true(Banks.should_create(false))


func test_water_probe_cache_is_bounded_during_travel() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var camera := Camera3D.new()
	tree.root.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	var banks := Banks.new()
	tree.root.add_child(banks)
	banks.configure(camera, func(_xz: Vector2) -> float: return 0.0)
	var damp := _presentation()
	damp.overcast = 0.9
	for step in 100:
		var focus := Vector3(float(step) * 80.0, 0.0, 0.0)
		camera.look_at_from_position(focus + Vector3(0, 30, 30), focus, Vector3.UP)
		banks.update(0.5, damp, float(step))
	var diameter := Banks.CACHE_RADIUS_CELLS * 2 + 1
	assert_true(banks._affinity.size() <= diameter * diameter, "cache must evict travel history")
	assert_true(banks._pending.size() <= diameter * diameter, "probe queue must stay bounded")
	banks.free()
	camera.free()


func test_roof_suppression_clears_banks_and_stops_emitters() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var camera := Camera3D.new()
	tree.root.add_child(camera)
	camera.look_at_from_position(Vector3(0, 30, 30), Vector3.ZERO, Vector3.UP)
	var banks := Banks.new()
	tree.root.add_child(banks)
	banks.configure(camera, func(_xz: Vector2) -> float: return 0.0)
	var damp := _presentation()
	damp.overcast = 0.9
	for i in 200:
		banks.update(0.1, damp, float(i) * 0.1)
	assert_true(banks.visible_bank_count() > 0)
	for i in 100:
		banks.update(0.1, damp, 20.0 + float(i) * 0.1, false)
	assert_eq(banks.visible_bank_count(), 0)
	for bank in banks.banks():
		assert_false(bank.emitter.emitting, "hidden banks must not simulate particles")
	banks.free()
	camera.free()


func test_haze_and_mirage_follow_the_active_camera_projection() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var configured := Camera3D.new()
	tree.root.add_child(configured)
	configured.projection = Camera3D.PROJECTION_ORTHOGONAL
	var active := Camera3D.new()
	tree.root.add_child(active)
	active.make_current()
	var sky := SkyWeather.new()
	tree.root.add_child(sky)
	sky._camera = configured
	sky.set_process(false)
	var mirage := Mirage.new()
	tree.root.add_child(mirage)
	mirage.configure(configured)
	assert_true(sky.view_is_perspective(), "haze must use the active camera")
	mirage.update(_presentation(0.81))
	assert_true(mirage._ring.visible, "perspective summer camera gets shimmer")
	active.projection = Camera3D.PROJECTION_ORTHOGONAL
	assert_false(sky.view_is_perspective())
	mirage.update(_presentation(0.81))
	assert_false(mirage._ring.visible, "overview gets no shimmer")
	active.projection = Camera3D.PROJECTION_PERSPECTIVE
	mirage.update(_presentation(0.81), false)
	assert_false(mirage._ring.visible, "roof suppression disables shimmer")
	mirage.free()
	sky.free()
	active.free()
	configured.free()


func test_separate_viewports_do_not_suppress_each_others_fog() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var views: Array[SubViewport] = []
	var layers: Array[Banks] = []
	for _i in 2:
		var viewport := SubViewport.new()
		viewport.own_world_3d = true
		tree.root.add_child(viewport)
		views.append(viewport)
		var camera := Camera3D.new()
		viewport.add_child(camera)
		camera.look_at_from_position(Vector3(0, 30, 30), Vector3.ZERO, Vector3.UP)
		var banks := Banks.new()
		viewport.add_child(banks)
		banks.configure(camera, func(_xz: Vector2) -> float: return 0.0)
		layers.append(banks)
	var damp := _presentation()
	damp.overcast = 0.9
	for i in 200:
		for layer in layers:
			layer.update(0.1, damp, float(i) * 0.1)
	for layer in layers:
		assert_true(layer.visible_bank_count() > 0, "each viewport owns its atmosphere")
	for viewport in views:
		viewport.free()


func test_soft_fog_priority_and_ground_height_follow_translated_map() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var camera := Camera3D.new()
	tree.root.add_child(camera)
	var banks := Banks.new()
	banks.position.y = 10.0
	tree.root.add_child(banks)
	banks.configure(camera, Callable(), func(_xz: Vector2) -> float: return 3.0)
	var bank := banks.banks()[0]
	banks._assign(bank, Vector2i.ZERO)
	assert_eq(bank.material.render_priority, Banks.FOG_RENDER_PRIORITY)
	assert_true(Banks.FOG_RENDER_PRIORITY > -100, "fog follows cloud shadows")
	assert_true(Banks.FOG_RENDER_PRIORITY < 0, "depth is read before screen-reading water")
	assert_almost_eq(float(bank.material.get_shader_parameter("ground_height")), 13.0, 0.001)
	banks.free()
	camera.free()
