extends "res://tests/godot/test_case.gd"

## R-1443: star positions follow the campaign calendar, not one fixed night.

const SkyAstronomy := preload("res://scripts/map/view3d/sky_astronomy.gd")


func test_sidereal_sky_drifts_with_the_calendar() -> void:
	# R-1443: the midnight sky gains ~0.986 degrees per day, so a month later the
	# same clock shows stars about two hours further west.
	var reference := {"day": 23, "month": 4, "year": 1343}
	var month_later := {"day": 23, "month": 5, "year": 1343}
	assert_true(
		is_equal_approx(
			SkyAstronomy.sidereal_angle_for_progress(0.0, reference),
			SkyAstronomy.sidereal_angle_for_progress(0.0)
		),
		"St George's Night keeps the canonical midnight sidereal angle"
	)
	var drift := rad_to_deg(
		SkyAstronomy.sidereal_angle_for_progress(0.0, month_later)
		- SkyAstronomy.sidereal_angle_for_progress(0.0, reference)
	)
	assert_true(
		absf(drift - 30.0 * 0.98565) < 0.01, "sidereal time must advance ~0.986 degrees per day"
	)
