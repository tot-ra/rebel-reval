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
		graded.adjustment_saturation < 1.0,
		"day grade must desaturate the Baltic palette"
	)
