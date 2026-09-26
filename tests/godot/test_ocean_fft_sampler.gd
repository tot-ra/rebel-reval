extends "res://tests/godot/test_case.gd"

## WS-05: OceanFftSampler is the CPU mirror of the WS-04 FFT water shader.

const WaterMaterials := preload("res://scripts/map/view3d/map_view_water_materials.gd")
const BoatFloat := preload("res://scripts/map/view3d/boat_float_3d.gd")

## Plain calm-to-storm sea-state scalars from the OCEAN_FFT_SEA_STATES table.
const CALM_SEA := 0.20
const REFERENCE_SEA := 0.50
const STORM_SEA := 0.85
const FRAME_BUDGET_MS := 0.5


func before_each() -> void:
	super.before_each()
	OceanFftSampler.reset_sea_state()
	OceanFftSampler.clear_time_override()


func after_each() -> void:
	OceanFftSampler.reset_sea_state()
	OceanFftSampler.clear_time_override()
	super.after_each()


func _set_sea(sea_scalar: float, wind_dir: Vector2, standing: float) -> void:
	var sea := WaterMaterials.fft_sea_state(sea_scalar, 0.0)
	OceanFftSampler.set_sea_state(
		PackedFloat32Array(sea["weights"]),
		float(sea["choppiness"]),
		float(sea["amplitude"]),
		wind_dir,
		standing
	)


func _profile_cascade(index: int) -> Dictionary:
	return (WaterMaterials.ocean_fft_profile()["cascades"] as Array)[index]


func test_loads_both_displacement_cascades_within_budget() -> void:
	assert_true(OceanFftSampler.load_profile(), "the baked C0/C1 atlases must decode on the CPU")
	var load_ms := OceanFftSampler.load_msec()
	var memory := OceanFftSampler.memory_bytes()
	print("  WS-05 OceanFftSampler load: %.1f ms, %d bytes" % [load_ms, memory])
	assert_true(load_ms < 300.0, "decoding both cascades must stay under 300 ms (%.1f ms)" % load_ms)
	# Raw RGBA8 bytes only: 128 x 128 x 64 frames x 4 channels per cascade.
	assert_eq(OceanFftSampler.memory_bytes(), 2 * 128 * 128 * 64 * 4, "atlases stay raw bytes")


func test_texel_centres_match_source_atlas_bytes() -> void:
	# The imported atlas is parsed, so compare against the lossless source PNG:
	# vertical strip, frame f is rows f*N..f*N+N-1, row = +Z, column = +X.
	assert_true(OceanFftSampler.ensure_loaded(), "sampler must load")
	var source := Image.load_from_file(
		ProjectSettings.globalize_path(WaterMaterials.OCEAN_FFT_DIR + "c0_disp.png")
	)
	source.convert(Image.FORMAT_RGBA8)
	var cascade := _profile_cascade(0)
	var n := int(cascade["n"])
	var frames := int(cascade["frames"])
	var meters_per_unit := float(WaterMaterials.ocean_fft_profile()["meters_per_world_unit"])
	var patch := float(cascade["patch_m"]) / meters_per_unit
	var scales: Dictionary = cascade["channel_scales"]
	# C0 alone, identity wind, no standing blend.
	OceanFftSampler.set_sea_state(PackedFloat32Array([1.0, 0.0]), 1.0, 1.0, Vector2(1.0, 0.0), 0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 505
	for probe in 24:
		var x := rng.randi_range(0, n - 1)
		var z := rng.randi_range(0, n - 1)
		var frame := rng.randi_range(0, frames - 1)
		var time := float(frame) * float(cascade["period_s"]) / float(frames)
		var p := Vector2((float(x) + 0.5) / n * patch, (float(z) + 0.5) / n * patch)
		var sampled := OceanFftSampler.baked_displacement(p, time)
		var texel := source.get_pixel(x, frame * n + z)
		var expected := Vector3(
			(texel.r - 0.5) * 2.0 * float(scales["dx"]),
			(texel.g - 0.5) * 2.0 * float(scales["dy"]),
			(texel.b - 0.5) * 2.0 * float(scales["dz"]),
		)
		assert_true(
			sampled.distance_to(expected) < 1e-4,
			"texel (%d, %d) frame %d decodes to %s, expected %s" % [x, z, frame, sampled, expected]
		)
		# World units: the vertical offset converts metres by 1 / 0.87.
		var world := OceanFftSampler.displacement_at(p, time)
		assert_almost_eq(world.y, expected.y / 0.87, 1e-4, "displacement_at converts metres to units")


func test_displacement_loops_with_the_longest_cascade() -> void:
	_set_sea(REFERENCE_SEA, Vector2(0.8, 0.6), 0.42)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2505
	for probe in 20:
		var p := Vector2(rng.randf_range(-200.0, 200.0), rng.randf_range(-200.0, 200.0))
		var t := rng.randf_range(0.0, 60.0)
		var a := OceanFftSampler.displacement_at(p, t)
		var b := OceanFftSampler.displacement_at(p, t + 25.6)
		assert_true(a.distance_to(b) < 1e-4, "the 25.6 s loop must repeat exactly at %s" % p)


func _worst_inversion_residual(surface: Vector3, seed: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var worst := 0.0
	for probe in 200:
		var target := Vector2(rng.randf_range(-150.0, 150.0), rng.randf_range(-150.0, 150.0))
		var t := rng.randf_range(0.0, 25.6)
		var x0 := target
		for i in OceanFftSampler.HEIGHT_ITERATIONS:
			var d := OceanFftSampler.displacement_at(x0, t, surface)
			x0 = target - Vector2(d.x, d.z)
		var landed := OceanFftSampler.displacement_at(x0, t, surface)
		worst = maxf(worst, (x0 + Vector2(landed.x, landed.z)).distance_to(target))
		assert_almost_eq(
			OceanFftSampler.height_at(target, t, surface), landed.y, 1e-6,
			"height_at reads the inverted point"
		)
	return worst


func test_height_at_inverts_horizontal_chop() -> void:
	# Contract case: the physical reference sea pushed to the 1.2 chop ceiling.
	var reference := WaterMaterials.fft_sea_state(REFERENCE_SEA, 0.0)
	OceanFftSampler.set_sea_state(
		PackedFloat32Array(reference["weights"]), 1.2, 1.0, Vector2(0.6, 0.8), 0.0
	)
	var physical := _worst_inversion_residual(OceanFftSampler.PHYSICAL_SURFACE, 1343)
	# What the hulls and swimmer query: the rendered open-sea mesh in a storm.
	_set_sea(STORM_SEA, Vector2(0.6, 0.8), 0.0)
	var rendered := _worst_inversion_residual(
		OceanFftSampler.terrain_surface(MapTypes.TERRAIN_DEEP_WATER), 1344
	)
	print(
		"  WS-05 inversion residual: physical ref %.6f, rendered storm %.6f units"
		% [physical, rendered]
	)
	assert_true(physical < 1e-3, "three steps must land within 1e-3 units (%.6f)" % physical)
	assert_true(rendered < 1e-3, "rendered storm sea must land within 1e-3 units (%.6f)" % rendered)


func test_single_step_hull_sampling_stays_close_to_three_steps() -> void:
	_set_sea(STORM_SEA, Vector2(0.8, 0.6), 0.42)
	var surface := OceanFftSampler.terrain_surface(MapTypes.TERRAIN_DEEP_WATER)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var worst := Vector3.ZERO
	for probe in 50:
		var origin := Vector2(rng.randf_range(-100.0, 100.0), rng.randf_range(-100.0, 100.0))
		var t := rng.randf_range(0.0, 25.6)
		var basis := Basis(Vector3.UP, rng.randf_range(-PI, PI))
		var one := BoatFloat.sample_fft_hull_attitude(origin, t, 3.0, 0.7, basis, surface, 1)
		var three := BoatFloat.sample_fft_hull_attitude(origin, t, 3.0, 0.7, basis, surface, 3)
		worst = Vector3(
			maxf(worst.x, absf(one.x - three.x)),
			maxf(worst.y, absf(one.y - three.y)),
			maxf(worst.z, absf(one.z - three.z))
		)
	print(
		"  WS-05 one-step hull error: heave %.5f units, pitch %.5f rad, roll %.5f rad"
		% [worst.x, worst.y, worst.z]
	)
	assert_true(worst.x < 0.002, "one-step heave must stay within 2 mm of three steps")
	assert_true(
		worst.y < 0.002 and worst.z < 0.004,
		"one-step attitude must stay within a fraction of a degree"
	)


func test_standing_ratio_blends_the_mirror_train() -> void:
	var wind := Vector2(0.9, 0.4)
	var axis := wind.normalized()
	var world := Vector2(37.5, -12.25)
	var t := 7.3
	var p := Vector2(world.x * axis.x + world.y * axis.y, -world.x * axis.y + world.y * axis.x)
	var forward := OceanFftSampler.baked_displacement(p, t)
	var mirror := OceanFftSampler.baked_displacement(-p, t)
	_set_sea(REFERENCE_SEA, wind, 1.0)
	var standing := OceanFftSampler.displacement_at(world, t)
	assert_almost_eq(
		standing.y, 0.5 * (forward.y + mirror.y) / 0.87, 1e-6, "ratio 1 is 0.5 * (F(p') + F(-p'))"
	)
	_set_sea(REFERENCE_SEA, wind, 0.0)
	var travelling := OceanFftSampler.displacement_at(world, t)
	assert_almost_eq(travelling.y, forward.y / 0.87, 1e-6, "ratio 0 is F(p') alone")
	# Horizontal: chop 0.9 x 0.5 mesh share, rotated back out of the bake frame.
	var h := Vector2(forward.x, forward.z) * 0.9 * OceanFftSampler.HORIZONTAL_GEOMETRY / 0.87
	var h_world := Vector2(h.x * axis.x - h.y * axis.y, h.x * axis.y + h.y * axis.x)
	assert_true(
		Vector2(travelling.x, travelling.z).distance_to(h_world) < 1e-6,
		"horizontal chop rotates back into world XZ"
	)


func _height_sigma(sea_scalar: float, samples: int) -> float:
	_set_sea(sea_scalar, Vector2(1.0, 0.0), 0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var total := 0.0
	var total_sq := 0.0
	for i in samples:
		var p := Vector2(rng.randf_range(0.0, 147.0), rng.randf_range(0.0, 147.0))
		var y := OceanFftSampler.displacement_at(p, rng.randf_range(0.0, 25.6)).y
		total += y
		total_sq += y * y
	var mean := total / samples
	return sqrt(maxf(total_sq / samples - mean * mean, 0.0))


func test_sea_states_scale_the_amplitude_monotonically() -> void:
	var calm := _height_sigma(CALM_SEA, 1500)
	var reference := _height_sigma(REFERENCE_SEA, 1500)
	var storm := _height_sigma(STORM_SEA, 1500)
	assert_true(
		calm < reference and reference < storm,
		"calm %.3f < ref %.3f < storm %.3f" % [calm, reference, storm]
	)


func test_reference_sea_matches_baked_significant_height() -> void:
	# 4 sigma of the C0 + C1 field, in metres, equals the quadrature sum of the
	# profile's per-cascade hs_m (WS-03 amendment 3). Catches a missing or doubled
	# amplitude normalisation.
	var sigma_units := _height_sigma(REFERENCE_SEA, 6000)
	var hs_measured := 4.0 * sigma_units * 0.87
	var hs0 := float(_profile_cascade(0)["hs_m"])
	var hs1 := float(_profile_cascade(1)["hs_m"])
	var hs_expected := sqrt(hs0 * hs0 + hs1 * hs1)
	print("  WS-05 reference Hs: measured %.3f m, baked %.3f m" % [hs_measured, hs_expected])
	assert_true(
		absf(hs_measured - hs_expected) / hs_expected < 0.06,
		"reference Hs %.3f m must match the baked %.3f m" % [hs_measured, hs_expected]
	)


func test_height_query_cost_and_harbour_frame_budget() -> void:
	assert_true(OceanFftSampler.ensure_loaded(), "sampler must load")
	_set_sea(STORM_SEA, Vector2(0.8, 0.6), 0.42)
	var surface := OceanFftSampler.terrain_surface(MapTypes.TERRAIN_WATER)
	var calls := 10000
	var started := Time.get_ticks_usec()
	var sink := 0.0
	for i in calls:
		var point := Vector2(float(i) * 0.37, float(i % 97) * 0.53)
		sink += OceanFftSampler.height_at(point, 3.0, surface)
	var per_call_us := float(Time.get_ticks_usec() - started) / calls
	print("  WS-05 height_at: %.1f us per call (standing basin, 3 iterations)" % per_call_us)
	assert_true(is_finite(sink), "height queries must stay finite")
	# reval_harbor_north moors six hulls (four cogs, two landing boats).
	var boats: Array[Node3D] = []
	for index in 6:
		var host := Node3D.new()
		host.position = Vector3(13.0 + index * 24.0, 0.0, 24.0 + index)
		var floater: BoatFloat = BoatFloat.new()
		floater.configure(host, 0.45 if index < 4 else 1.0, index)
		host.add_child(floater)
		boats.append(host)
	var frames := 30
	started = Time.get_ticks_usec()
	for frame in frames:
		OceanFftSampler.set_time_override(frame / 60.0)
		for host in boats:
			(host.get_node("BoatFloat") as BoatFloat)._process(1.0 / 60.0)
	var frame_ms := float(Time.get_ticks_usec() - started) / 1000.0 / frames
	print("  WS-05 six-hull harbour frame cost: %.3f ms" % frame_ms)
	assert_true(
		frame_ms < FRAME_BUDGET_MS, "all harbour hulls must cost < 0.5 ms/frame (%.3f)" % frame_ms
	)
	for host in boats:
		host.free()


func test_fetch_shelter_scale_matches_the_documented_lee_floor() -> void:
	assert_almost_eq(OceanFftSampler.fetch_shelter_scale(20.0, 20.0), 1.0, 0.001)
	assert_almost_eq(
		OceanFftSampler.fetch_shelter_scale(20.0, -8.0),
		OceanFftSampler.SHELTER_LEE_SCALE,
		0.001,
		"land upwind sits on the lee floor"
	)
