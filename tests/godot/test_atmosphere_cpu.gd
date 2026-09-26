extends "res://tests/godot/test_case.gd"

## WS-11: AtmosphereCpu evaluates sun colour, sky irradiance and horizon colour from the
## static WS-09 LUT images, deterministically and cheaply enough for a 4 Hz lighting update.

const Atmosphere := preload("res://scripts/map/view3d/atmosphere_cpu.gd")
const ZENITH_ORACLE := Vector3(0.940, 0.868, 0.762)


static func _sun_at(elevation_deg: float, azimuth_deg: float = 180.0) -> Vector3:
	var e := deg_to_rad(elevation_deg)
	var a := deg_to_rad(azimuth_deg)
	return Vector3(cos(e) * sin(a), sin(e), -cos(e) * cos(a)).normalized()


func test_luts_load() -> void:
	assert_true(Atmosphere.load_luts(), "WS-09 LUT images must load for the CPU atmosphere")
	assert_true(Atmosphere.is_available())


func test_missing_luts_fail_closed_to_neutral_values() -> void:
	assert_false(Atmosphere.load_luts("res://missing/transmittance.exr", Atmosphere.MULTISCATTER_PATH))
	assert_eq(Atmosphere.sun_color_for(_sun_at(2.0)), Color.WHITE, "missing LUTs keep a neutral sun")
	var tracker := Atmosphere.new()
	assert_false(tracker.sample(_sun_at(30.0), 1000), "tracker reports the fallback")
	assert_true(Atmosphere.load_luts(), "restore the real LUTs for later tests")


func test_cpu_zenith_transmittance_matches_ws09_oracle() -> void:
	Atmosphere.load_luts()
	var t := Atmosphere.ground_transmittance(Vector3.UP)
	assert_almost_eq(t.x, ZENITH_ORACLE.x, 0.01, "zenith T red")
	assert_almost_eq(t.y, ZENITH_ORACLE.y, 0.01, "zenith T green")
	assert_almost_eq(t.z, ZENITH_ORACLE.z, 0.01, "zenith T blue")


func test_zenith_sun_is_near_white_and_low_sun_is_red() -> void:
	Atmosphere.load_luts()
	var zenith := Atmosphere.sun_color_for(Vector3.UP)
	assert_almost_eq(zenith.r, 1.0, 0.001, "normalised sun keeps its brightest channel at 1")
	assert_true(zenith.g > 0.85 and zenith.b > 0.75, "zenith sun must be near-white: %s" % zenith)
	assert_almost_eq(Atmosphere.sun_energy_for(Vector3.UP), 1.0, 0.001, "energy is relative to noon")
	var low := Atmosphere.sun_color_for(_sun_at(2.0))
	assert_true(low.r > low.g and low.g > low.b, "2 degree sun must be red > green > blue: %s" % low)
	assert_true(low.b < 0.2, "2 degree sun must lose most of its blue: %s" % low)
	assert_true(
		Atmosphere.sun_energy_for(_sun_at(2.0)) < Atmosphere.sun_energy_for(_sun_at(30.0)),
		"a low sun delivers less energy than a high one"
	)


func test_noon_sky_irradiance_is_blue_dominant() -> void:
	Atmosphere.load_luts()
	var e := Atmosphere.sky_irradiance_for(_sun_at(55.0))
	assert_true(e.b > e.g and e.g > e.r, "noon skylight must be blue-dominant: %s" % e)
	assert_true(Atmosphere.luminance(e) > 0.0, "noon skylight carries energy")


func test_horizon_is_brighter_towards_the_sun_at_sunset() -> void:
	Atmosphere.load_luts()
	var sun := _sun_at(2.0)
	var average := Atmosphere.horizon_color_for(sun)
	var towards := Atmosphere.horizon_color_for(sun, sun)
	var away := Atmosphere.horizon_color_for(sun, -sun)
	assert_true(
		Atmosphere.luminance(towards) > Atmosphere.luminance(away),
		"Mie glow makes the sun-side horizon brighter"
	)
	assert_true(towards.r / towards.b > average.r / average.b, "the sun-side horizon is warmer")


func test_evaluation_is_deterministic() -> void:
	Atmosphere.load_luts()
	var sun := _sun_at(7.5, 250.0)
	for label: String in ["sun", "irradiance", "horizon"]:
		var a := _evaluate(label, sun)
		var b := _evaluate(label, sun)
		assert_eq(a, b, "%s must be deterministic for a fixed sun" % label)
	# Only the sun elevation matters for the sun-relative irradiance.
	assert_true(
		Atmosphere.sky_irradiance_for(_sun_at(20.0, 10.0)).is_equal_approx(
			Atmosphere.sky_irradiance_for(_sun_at(20.0, 200.0))
		),
		"irradiance depends only on the sun elevation"
	)


func test_full_evaluation_stays_under_one_millisecond() -> void:
	Atmosphere.load_luts()
	var runs := 100
	var start := Time.get_ticks_usec()
	for i in runs:
		var sun := _sun_at(-3.0 + 63.0 * float(i) / float(runs), float(i) * 7.0)
		Atmosphere.sun_color_for(sun)
		Atmosphere.sun_energy_for(sun)
		Atmosphere.sky_irradiance_for(sun)
		Atmosphere.horizon_color_for(sun)
	var average_ms := float(Time.get_ticks_usec() - start) / 1000.0 / float(runs)
	print("WS11_ATMOSPHERE_CPU_MS %.4f" % average_ms)
	assert_true(average_ms < 1.0, "full evaluation took %.3f ms on average" % average_ms)


func test_tracker_throttles_to_four_hertz_and_smooths() -> void:
	Atmosphere.load_luts()
	var tracker := Atmosphere.new()
	var t0 := 5_000_000
	tracker.sample(_sun_at(12.0), t0)
	assert_eq(tracker.evaluation_count, 1, "the first sample evaluates and snaps")
	var snapped := tracker.sun_color
	assert_eq(snapped, Atmosphere.sun_color_for(_sun_at(12.0)), "first sample snaps to the target")
	# 1x day speed: about 6 degrees per second, sampled every 16 ms.
	var usec := t0
	var elevation := 12.0
	var max_step := 0.0
	var previous := tracker.sun_color
	for frame in 60:
		usec += 16_667
		elevation -= 0.1
		tracker.sample(_sun_at(elevation), usec)
		max_step = maxf(max_step, _color_distance(previous, tracker.sun_color))
		previous = tracker.sun_color
	assert_true(
		tracker.evaluation_count >= 4 and tracker.evaluation_count <= 5,
		"one second at 60 fps evaluates at most every 0.25 s, got %d" % tracker.evaluation_count
	)
	assert_true(max_step < 0.01, "smoothed sun colour must not step visibly (%.4f)" % max_step)
	# A jump (capture, save restore) snaps instead of easing for seconds.
	tracker.sample(_sun_at(60.0), usec + 16_667)
	assert_eq(tracker.sun_color, Atmosphere.sun_color_for(_sun_at(60.0)), "large jumps snap")


func _evaluate(label: String, sun: Vector3) -> Color:
	match label:
		"sun":
			return Atmosphere.sun_color_for(sun)
		"irradiance":
			return Atmosphere.sky_irradiance_for(sun)
		_:
			return Atmosphere.horizon_color_for(sun)


static func _color_distance(a: Color, b: Color) -> float:
	return maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), absf(a.b - b.b))
