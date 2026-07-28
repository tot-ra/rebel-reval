extends "res://tests/godot/test_case.gd"

const SkyAstronomy := preload("res://scripts/map/view3d/sky_astronomy.gd")
const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")


func test_weather_controller_keeps_astronomy_facade() -> void:
	var date := {"day": 21, "month": 4, "year": 1343}
	assert_eq(
		SkyWeather.OBSERVER_LATITUDE_DEGREES,
		SkyAstronomy.OBSERVER_LATITUDE_DEGREES,
		"the existing SkyWeather3D public latitude must remain available"
	)
	assert_true(
		SkyWeather.solar_direction(0.5, date).is_equal_approx(SkyAstronomy.solar_direction(0.5, date)),
		"the existing SkyWeather3D astronomy facade must delegate without changing results"
	)


func test_morning_fog_potential_is_deterministic_daily_and_occasional() -> void:
	var may_10 := {"day": 10, "month": 5, "year": 1343}
	# Deterministic per calendar day: the same date always gives the same potential.
	assert_true(
		is_equal_approx(SkyAstronomy.morning_fog_potential(may_10), SkyAstronomy.morning_fog_potential(may_10)),
		"a given morning must repeat its fog potential exactly"
	)
	var above := 0
	var below := 0
	var last := -1.0
	var varied := false
	for day in range(1, 31):
		var potential: float = SkyAstronomy.morning_fog_potential({"day": day, "month": 5, "year": 1343})
		assert_true(potential >= 0.0 and potential <= 1.0, "fog potential must be a 0..1 value")
		if potential > 0.6:
			above += 1
		else:
			below += 1
		if last >= 0.0 and not is_equal_approx(potential, last):
			varied = true
		last = potential
	assert_true(varied, "fog potential must vary from day to day, not sit constant")
	assert_true(below > 0, "some mornings must be too dry or breezy for fog — it is not a daily event")
	assert_true(above > 0, "some mornings must be primed for fog across a month")
	assert_true(below > above, "fog-prone mornings must be the minority, not the norm")


func test_sun_crosses_the_sky_from_east_to_west() -> void:
	var spring_date := {"day": 21, "month": 4, "year": 1343}
	var morning := SkyAstronomy.solar_direction(6.0 / 24.0, spring_date)
	var evening := SkyAstronomy.solar_direction(18.0 / 24.0, spring_date)
	assert_true(morning.y > 0.0, "the spring morning sun must be above the horizon")
	assert_true(morning.x > 0.0, "the morning sun must rise in the eastern (+X) sky")
	assert_true(evening.y > 0.0, "the spring evening sun must still be above the horizon")
	assert_true(evening.x < 0.0, "the evening sun must set in the western (-X) sky")


func test_sun_disk_visibility_matches_sky_shader_fade() -> void:
	assert_true(
		is_equal_approx(SkyAstronomy.sun_disk_visibility(Vector3(0.0, 0.2, 0.0)), 1.0),
		"sun above the fade band must be fully visible"
	)
	assert_true(
		is_equal_approx(SkyAstronomy.sun_disk_visibility(Vector3(0.0, -0.2, 0.0)), 0.0),
		"sun below the fade band must be fully hidden"
	)
	var mid := SkyAstronomy.sun_disk_visibility(Vector3(0.0, 0.0, 1.0))
	assert_true(mid > 0.4 and mid < 0.6, "horizon sun must be mid-fade like the sky shader")


func test_day_length_and_noon_height_follow_the_calendar() -> void:
	var winter := {"day": 21, "month": 12, "year": 1343}
	var spring := {"day": 21, "month": 4, "year": 1343}
	var summer := {"day": 21, "month": 6, "year": 1343}
	var winter_times := SkyAstronomy.sunrise_sunset_hours(winter)
	var spring_times := SkyAstronomy.sunrise_sunset_hours(spring)
	var summer_times := SkyAstronomy.sunrise_sunset_hours(summer)
	assert_true(
		float(winter_times["day_length"]) < float(spring_times["day_length"]),
		"Reval's April day must be longer than its December day"
	)
	assert_true(
		float(spring_times["day_length"]) < float(summer_times["day_length"]),
		"Reval's June day must be longer than its April day"
	)
	assert_true(
		float(summer_times["sunrise"]) < float(winter_times["sunrise"]),
		"summer sunrise must occur earlier than winter sunrise"
	)
	assert_true(
		float(summer_times["sunset"]) > float(winter_times["sunset"]),
		"summer sunset must occur later than winter sunset"
	)
	assert_true(
		SkyAstronomy.solar_elevation_degrees(0.5, summer) > SkyAstronomy.solar_elevation_degrees(0.5, winter),
		"the summer noon sun must climb higher than the winter noon sun"
	)


func test_campaign_calendar_drives_daylight_thresholds() -> void:
	var winter := {"day": 21, "month": 12, "year": 1343}
	var summer := {"day": 21, "month": 6, "year": 1343}
	assert_true(
		SkyAstronomy.daylight_blend(7.0 / 24.0, summer) > 0.5,
		"07:00 must be daylight in a Reval summer"
	)
	assert_true(
		SkyAstronomy.daylight_blend(7.0 / 24.0, winter) < 0.5,
		"07:00 must still be night in a Reval winter"
	)


func test_moon_crosses_the_sky_from_east_to_west() -> void:
	var full_moon := {"day": 10, "month": 5, "year": 1343}
	var evening := SkyAstronomy.lunar_direction(18.0 / 24.0, full_moon)
	var midnight := SkyAstronomy.lunar_direction(0.0, full_moon)
	var morning := SkyAstronomy.lunar_direction(6.0 / 24.0, full_moon)
	assert_true(evening.x > 0.0, "the evening full moon must rise in the eastern (+X) sky")
	assert_true(midnight.y > evening.y, "the full moon must climb after rising")
	assert_true(morning.x < 0.0, "the morning full moon must set in the western (-X) sky")


func test_moon_angle_follows_phase_not_the_sun_path() -> void:
	var prologue := {"day": 21, "month": 4, "year": 1343}
	var new_moon := {"day": 25, "month": 4, "year": 1343}
	var full_moon := {"day": 10, "month": 5, "year": 1343}
	var noon := 0.5
	var prologue_sep := SkyAstronomy.sun_moon_separation_degrees(noon, prologue)
	var new_sep := SkyAstronomy.sun_moon_separation_degrees(noon, new_moon)
	var full_sep := SkyAstronomy.sun_moon_separation_degrees(noon, full_moon)
	assert_true(
		prologue_sep > 35.0,
		"the late-April waning crescent must sit well clear of the noon sun, not behind it"
	)
	assert_true(new_sep < 15.0, "new moon must approach solar conjunction")
	assert_true(full_sep > 130.0, "full moon must sit opposite the sun, not on its path")
	var sun_noon := SkyAstronomy.solar_direction(noon, new_moon)
	var moon_noon := SkyAstronomy.lunar_direction(noon, new_moon)
	assert_true(
		absf(
			SkyAstronomy.lunar_declination_degrees(prologue)
			- SkyAstronomy.solar_declination_degrees(prologue)
		) > 2.0,
		"lunar inclination must tilt the moon off the sun's declination arc"
	)
	assert_false(
		sun_noon.is_equal_approx(moon_noon),
		"even near new moon the inclined lunar path must not reuse the sun vector"
	)


func test_celestial_motion_uses_distinct_astronomical_rates() -> void:
	var date := {"day": 21, "month": 4, "year": 1343}
	var start := 0.10
	var interval := 0.10
	var finish := start + interval
	var sun_rotation := fposmod(
		_hour_angle(SkyAstronomy.solar_direction(finish, date))
		- _hour_angle(SkyAstronomy.solar_direction(start, date)),
		TAU
	)
	var moon_rotation := fposmod(
		_hour_angle(SkyAstronomy.lunar_direction(finish, date))
		- _hour_angle(SkyAstronomy.lunar_direction(start, date)),
		TAU
	)
	var star_rotation := (
		SkyAstronomy.sidereal_angle_for_progress(finish)
		- SkyAstronomy.sidereal_angle_for_progress(start)
	)

	assert_true(moon_rotation < sun_rotation, "the moon must move west more slowly than the sun")
	assert_true(sun_rotation < star_rotation, "the sidereal sky must move west faster than the sun")
	assert_true(
		absf(rad_to_deg(moon_rotation / interval) - 347.81) < 0.02,
		"the moon must lose about 12.2 degrees per solar day to its eastward orbit"
	)
	assert_true(
		absf(rad_to_deg(star_rotation / interval) - 360.986) < 0.002,
		"the stars must gain about 0.986 degrees per solar day"
	)


func _hour_angle(direction: Vector3) -> float:
	var latitude := deg_to_rad(SkyAstronomy.OBSERVER_LATITUDE_DEGREES)
	var north := -direction.z
	return atan2(-direction.x, direction.y * cos(latitude) - north * sin(latitude))


func test_lunar_phase_changes_in_weekly_quarters() -> void:
	var new_moon := {"day": 25, "month": 4, "year": 1343}
	var first_quarter := {"day": 2, "month": 5, "year": 1343}
	var full_moon := {"day": 10, "month": 5, "year": 1343}
	var last_quarter := {"day": 17, "month": 5, "year": 1343}
	assert_true(SkyAstronomy.lunar_illumination(SkyAstronomy.lunar_phase(new_moon)) < 0.01, "25 April must be near new moon")
	assert_true(absf(SkyAstronomy.lunar_illumination(SkyAstronomy.lunar_phase(first_quarter)) - 0.5) < 0.1, "one week after new moon must approach first quarter")
	assert_true(SkyAstronomy.lunar_illumination(SkyAstronomy.lunar_phase(full_moon)) > 0.99, "two weeks after new moon must approach full moon")
	assert_true(absf(SkyAstronomy.lunar_illumination(SkyAstronomy.lunar_phase(last_quarter)) - 0.5) < 0.1, "three weeks after new moon must approach last quarter")
	var phase_step := fposmod(
		SkyAstronomy.lunar_phase({"day": 26, "month": 4, "year": 1343}) - SkyAstronomy.lunar_phase(new_moon),
		1.0
	)
	assert_true(
		phase_step > 0.03 and phase_step < 0.04,
		"the phase must advance by about one synodic day with each campaign date"
	)


func test_lunar_phase_shifts_rise_time_through_the_month() -> void:
	var new_moon := {"day": 25, "month": 4, "year": 1343}
	var full_moon := {"day": 10, "month": 5, "year": 1343}
	var new_moon_midnight := SkyAstronomy.lunar_elevation_degrees(0.0, new_moon)
	var full_moon_midnight := SkyAstronomy.lunar_elevation_degrees(0.0, full_moon)
	assert_true(new_moon_midnight < 0.0, "a new moon must share the sun's below-horizon midnight position")
	assert_true(full_moon_midnight > 0.0, "a full moon must be above the midnight horizon")


func test_tide_has_two_daily_highs_and_follows_lunar_phase() -> void:
	var new_moon := {"day": 25, "month": 4, "year": 1343}
	var first_quarter := {"day": 2, "month": 5, "year": 1343}
	var spring_min := 1.0
	var spring_max := -1.0
	var neap_min := 1.0
	var neap_max := -1.0
	var spring_highs := 0
	var samples := 192
	var spring_levels: Array[float] = []
	for index in samples:
		var progress := float(index) / float(samples)
		var spring := SkyAstronomy.tide_level(progress, new_moon)
		var neap := SkyAstronomy.tide_level(progress, first_quarter)
		spring_levels.append(spring)
		spring_min = minf(spring_min, spring)
		spring_max = maxf(spring_max, spring)
		neap_min = minf(neap_min, neap)
		neap_max = maxf(neap_max, neap)
	for index in samples:
		if (
			spring_levels[index] > spring_levels[(index + samples - 1) % samples]
			and spring_levels[index] > spring_levels[(index + 1) % samples]
		):
			spring_highs += 1
	assert_eq(spring_highs, 2, "the lunar/solar tide must produce two high waters per day")
	assert_true(
		(spring_max - spring_min) > (neap_max - neap_min) * 1.35,
		"new/full moon spring tides must exceed quarter-moon neap tides"
	)
	var first_sample := SkyAstronomy.tide_level(0.25, new_moon)
	var second_sample := SkyAstronomy.tide_level(0.25, new_moon)
	assert_true(
		is_equal_approx(first_sample, second_sample),
		"the tide must be deterministic for the same date and clock time"
	)
