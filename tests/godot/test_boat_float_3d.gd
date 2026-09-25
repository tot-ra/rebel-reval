extends "res://tests/godot/test_case.gd"

const BoatFloat := preload("res://scripts/map/view3d/boat_float_3d.gd")
const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")
const WaterMaterials := preload("res://scripts/map/view3d/map_view_water_materials.gd")


func test_boat_props_attach_float_controllers() -> void:
	var fishing := MapViewMeshBuilder.build_prop(
		{
			"id": &"float_fishing",
			"kind": MapTypes.PROP_KIND_FISHING_BOAT,
			"position": Vector2.ZERO,
		},
		MapTypes.DEFAULT_CELL_SIZE
	)
	var merchant := MapViewMeshBuilder.build_prop(
		{
			"id": &"float_merchant",
			"kind": MapTypes.PROP_KIND_MERCHANT_BOAT,
			"position": Vector2.ZERO,
		},
		MapTypes.DEFAULT_CELL_SIZE
	)
	assert_true(fishing.has_node("BoatFloat"), "fishing boats must ride the harbor wave field")
	assert_true(merchant.has_node("BoatFloat"), "merchant cogs must ride the harbor wave field")
	fishing.free()
	merchant.free()


func test_wave_sample_is_finite_and_varies_across_the_harbor() -> void:
	var near := BoatFloat.sample_wave(Vector2(12.0, 4.0), 1.5)
	var far := BoatFloat.sample_wave(Vector2(40.0, 18.0), 1.5)
	assert_true(
		is_finite(near.x) and is_finite(near.y) and is_finite(near.z),
		"wave sample must stay finite"
	)
	assert_true(near.distance_to(far) > 0.01, "distinct berths must not share one locked wave phase")


func test_bow_and_stern_wave_samples_differ_along_swell() -> void:
	var heading := Vector2(1.0, 0.28).normalized()
	var origin := Vector2(12.0, 4.0)
	var half_length := BoatFloat.DEFAULT_HULL_HALF_LENGTH
	var time := 1.5
	var standing := BoatFloat.HARBOR_STANDING_WAVE_RATIO
	var bow := BoatFloat.sample_wave(origin + heading * half_length, time, standing).x
	var stern := BoatFloat.sample_wave(origin - heading * half_length, time, standing).x
	assert_true(
		absf(bow - stern) > 0.001,
		"bow and stern must ride different crest heights along a swell"
	)


func test_multi_point_hull_attitude_derives_pitch_and_roll() -> void:
	var origin := Vector2(18.0, 6.0)
	var time := 2.25
	var standing := BoatFloat.HARBOR_STANDING_WAVE_RATIO
	var half_length := BoatFloat.DEFAULT_HULL_HALF_LENGTH
	var half_beam := BoatFloat.DEFAULT_HULL_HALF_BEAM
	var center_only := BoatFloat.sample_wave(origin, time, standing)
	var hull := BoatFloat.sample_hull_attitude(
		origin, time, standing, half_length, half_beam, Basis.IDENTITY
	)
	assert_true(
		is_finite(hull.x) and is_finite(hull.y) and is_finite(hull.z),
		"hull attitude must stay finite"
	)
	assert_true(
		absf(hull.y) > 0.0001 or absf(hull.z) > 0.0001,
		"multi-point sampling must pitch or roll the hull along the Gerstner field"
	)
	assert_almost_eq(
		hull.x, center_only.x, 0.0001, "center heave must match the center wave sample"
	)


func test_float_motion_moves_hull_off_rest_pose() -> void:
	var boat := Node3D.new()
	boat.position = Vector3(8.0, 0.1, 3.0)
	var floater: BoatFloat = BoatFloat.new()
	floater.configure(boat, 1.0, 42)
	boat.add_child(floater)
	var rest_position := boat.position
	var rest_basis := boat.basis
	floater._process(0.016)
	var moved := (
		not boat.position.is_equal_approx(rest_position)
		or not boat.basis.is_equal_approx(rest_basis)
	)
	assert_true(moved, "floating hulls must leave their authored rest pose each frame")
	boat.free()


func test_rain_raises_wind_above_clear_breeze() -> void:
	var sky: SkyWeather = SkyWeather.new()
	sky.auto_weather = false
	var clear_wind := sky.wind_strength()
	sky.set_weather(SkyWeather.WEATHER_RAIN)
	sky.advance(SkyWeather.TRANSITION_SECONDS)
	assert_true(
		sky.wind_strength() > clear_wind + 0.4,
		"storm wind must exceed the clear harbor breeze"
	)
	sky.free()


func test_sea_weather_scales_water_wave_height() -> void:
	var clear_height := float(
		MapViewMaterials.water_surface(MapTypes.TERRAIN_DEEP_WATER).get_shader_parameter("wave_height")
	)
	MapViewMaterials.apply_sea_weather(0.22, 0.0)
	var calm := float(
		MapViewMaterials.water_surface(MapTypes.TERRAIN_DEEP_WATER).get_shader_parameter("wave_height")
	)
	MapViewMaterials.apply_sea_weather(0.92, 1.0)
	var storm := float(
		MapViewMaterials.water_surface(MapTypes.TERRAIN_DEEP_WATER).get_shader_parameter("wave_height")
	)
	assert_true(storm > calm, "rain and wind must raise the animated water surface")
	assert_true(calm > 0.0 and clear_height > 0.0, "water waves must stay active in calm weather")
	# Restore a near-clear sea state so later mesh tests keep stable uniforms.
	MapViewMaterials.apply_sea_weather(0.22, 0.0)


func test_world_wind_drives_vegetation_and_cloth_uniforms() -> void:
	var calm_dir := Vector2(1.0, 0.0)
	var storm_dir := Vector2(0.0, 1.0)
	MapViewMaterials.apply_world_wind(calm_dir, 0.22)
	var grass := MapViewMaterials.grass_blades()
	var canopy := MapViewMaterials.canopy(&"leaf")
	var sail := MapViewMaterials.sail_cloth()
	var flag := MapViewMaterials.flag_cloth()
	assert_eq(grass.get_shader_parameter("wind_strength"), 0.22, "calm wind must reach grass")
	assert_eq(
		canopy.get_shader_parameter("wind_direction"), calm_dir, "canopy must share calm wind heading"
	)
	assert_eq(
		sail.get_shader_parameter("wind_direction"), calm_dir, "sails must share calm wind heading"
	)
	MapViewMaterials.apply_world_wind(storm_dir, 0.92)
	assert_eq(
		grass.get_shader_parameter("wind_strength"), 0.92, "storm wind must raise grass sway power"
	)
	assert_eq(
		flag.get_shader_parameter("wind_direction"), storm_dir, "flags must turn with storm wind"
	)
	assert_eq(
		sail.get_shader_parameter("wind_strength"), 0.92, "sails must stiffen with storm wind"
	)
	# Restore calm defaults for later material-sensitive tests.
	MapViewMaterials.apply_world_wind(Vector2(0.9285, 0.3714), 0.22)


# --- WS-05 FFT path -------------------------------------------------------------


func _fft_boat(position: Vector3, phase_seed: int) -> Node3D:
	var host := Node3D.new()
	host.position = position
	var floater: BoatFloat = BoatFloat.new()
	floater.configure(host, 1.0, phase_seed)
	host.add_child(floater)
	return host


func test_fft_path_is_declared_and_loaded() -> void:
	assert_true(BoatFloat.FFT_SUPPORTED, "WS-05 declares FFT hull support for WS-04 enablement")
	assert_true(WaterMaterials.ocean_fft_supported(), "sea materials follow the boat constant")
	var host := _fft_boat(Vector3.ZERO, 1)
	assert_true((host.get_node("BoatFloat") as BoatFloat).uses_fft(), "boats ride the baked FFT sea")
	host.free()


func test_fft_heave_follows_the_hull_mean_surface_height() -> void:
	OceanFftSampler.reset_sea_state()
	OceanFftSampler.set_time_override(4.2)
	var rest := Vector3(21.0, 0.05, 9.0)
	var host := _fft_boat(rest, 7)
	(host.get_node("BoatFloat") as BoatFloat)._process(0.016)
	var hull := BoatFloat.sample_fft_hull_attitude(
		Vector2(rest.x, rest.z),
		4.2,
		BoatFloat.DEFAULT_HULL_HALF_LENGTH,
		BoatFloat.DEFAULT_HULL_HALF_BEAM,
		Basis.IDENTITY,
		OceanFftSampler.terrain_surface(MapTypes.TERRAIN_WATER),
		BoatFloat.FFT_HULL_ITERATIONS
	)
	assert_almost_eq(host.position.y - rest.y, hull.x, 1e-5, "heave is the five-point mean height")
	var centre := OceanFftSampler.surface_height_at(
		Vector2(rest.x, rest.z), 4.2, OceanFftSampler.terrain_surface(MapTypes.TERRAIN_WATER)
	)
	# The hull-length mean is a low-pass, not an unrelated number.
	assert_true(absf(hull.x - centre) < 0.1, "hull heave stays on the local surface")
	OceanFftSampler.clear_time_override()
	host.free()


func test_fft_crest_at_the_bow_pitches_the_bow_up() -> void:
	# Storm sea: harbour crests are only ~0.1 units, so a calm hull pitches less
	# than the wind heel term and the sign test would measure the wind instead.
	var storm := WaterMaterials.fft_sea_state(0.85, 0.0)
	OceanFftSampler.set_sea_state(
		PackedFloat32Array(storm["weights"]),
		float(storm["choppiness"]),
		float(storm["amplitude"]),
		Vector2(1.0, 0.28),
		0.42
	)
	var surface := OceanFftSampler.terrain_surface(MapTypes.TERRAIN_WATER)
	var half_length := BoatFloat.DEFAULT_HULL_HALF_LENGTH
	var found := false
	for probe in 400:
		var origin := Vector2(float(probe % 20) * 3.1, float(probe / 20) * 2.3)
		var t := float(probe) * 0.37
		var hull := BoatFloat.sample_fft_hull_attitude(
			origin, t, half_length, BoatFloat.DEFAULT_HULL_HALF_BEAM, Basis.IDENTITY, surface, 1
		)
		# Clear the wind heel term (a fraction of a degree) before judging the sign.
		if hull.y < deg_to_rad(1.5):
			continue
		found = true
		var bow := OceanFftSampler.surface_height_at(origin + Vector2(half_length, 0.0), t, surface, 1)
		var stern := OceanFftSampler.surface_height_at(origin - Vector2(half_length, 0.0), t, surface, 1)
		assert_true(bow > stern, "positive pitch means the crest is at the bow")
		OceanFftSampler.set_time_override(t)
		var host := _fft_boat(Vector3(origin.x, 0.0, origin.y), 3)
		(host.get_node("BoatFloat") as BoatFloat)._process(0.016)
		assert_true(
			(host.basis * Vector3(half_length, 0.0, 0.0)).y > 0.0, "the bow rises onto the crest"
		)
		host.free()
		break
	OceanFftSampler.clear_time_override()
	OceanFftSampler.reset_sea_state()
	assert_true(found, "a storm sea must lift a bow somewhere in the probe grid")


func test_fft_boats_share_one_sea_without_phase_offsets() -> void:
	OceanFftSampler.reset_sea_state()
	OceanFftSampler.set_time_override(11.0)
	var a := _fft_boat(Vector3(33.0, 0.0, 17.0), 11)
	var b := _fft_boat(Vector3(33.0, 0.0, 17.0), 90210)
	(a.get_node("BoatFloat") as BoatFloat)._process(0.016)
	(b.get_node("BoatFloat") as BoatFloat)._process(0.016)
	assert_true(a.transform.is_equal_approx(b.transform), "same place and time give the same pose")
	var c := _fft_boat(Vector3(61.0, 0.0, 4.0), 11)
	(c.get_node("BoatFloat") as BoatFloat)._process(0.016)
	assert_false(a.transform.is_equal_approx(c.transform), "different berths ride different water")
	OceanFftSampler.clear_time_override()
	a.free()
	b.free()
	c.free()


func test_fft_spring_smooths_a_sudden_sea_change() -> void:
	OceanFftSampler.reset_sea_state()
	OceanFftSampler.set_time_override(2.0)
	var rest := Vector3(9.0, 0.0, 30.0)
	var host := _fft_boat(rest, 5)
	var floater := host.get_node("BoatFloat") as BoatFloat
	floater._process(0.016)
	var before := host.position.y
	# Jump the clock half a C1 loop: the target moves, the hull eases towards it.
	OceanFftSampler.set_time_override(8.4)
	floater._process(0.016)
	var target := BoatFloat.sample_fft_hull_attitude(
		Vector2(rest.x, rest.z), 8.4, BoatFloat.DEFAULT_HULL_HALF_LENGTH,
		BoatFloat.DEFAULT_HULL_HALF_BEAM, Basis.IDENTITY,
		OceanFftSampler.terrain_surface(MapTypes.TERRAIN_WATER), BoatFloat.FFT_HULL_ITERATIONS
	).x
	var step := absf(host.position.y - before)
	assert_true(step < absf(target - before), "one frame must not snap to a jumped target")
	for i in 120:
		floater._process(0.016)
	assert_almost_eq(host.position.y, rest.y + target, 1e-3, "the spring settles on the surface")
	OceanFftSampler.clear_time_override()
	host.free()
