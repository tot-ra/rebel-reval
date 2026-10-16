extends "res://tests/godot/test_case.gd"

const SkyAstronomy := preload("res://scripts/map/view3d/sky_astronomy.gd")


func test_night_sky_seasonal_brightness_follows_solar_declination() -> void:
	var winter := {"day": 18, "month": 12, "year": 1343}
	var equinox := {"day": 13, "month": 3, "year": 1343}
	var summer := {"day": 24, "month": 6, "year": 1343}
	var winter_brightness := SkyAstronomy.seasonal_night_brightness(winter)
	var equinox_brightness := SkyAstronomy.seasonal_night_brightness(equinox)
	var summer_brightness := SkyAstronomy.seasonal_night_brightness(summer)

	assert_true(
		winter_brightness < 0.05,
		"winter night tint should be at its darkest near solstice"
	)
	assert_true(
		is_equal_approx(equinox_brightness, 0.5),
		"the seasonal night tint should cross its midpoint at the equinox"
	)
	assert_true(
		summer_brightness > 0.95,
		"summer night tint should peak around the solstice"
	)
	assert_true(
		winter_brightness < summer_brightness,
		"summer white nights must stay lighter than deep winter nights"
	)
