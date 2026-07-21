extends "res://tests/godot/test_case.gd"

const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")


func test_starts_clear_with_full_lighting() -> void:
	var sky = SkyWeather.new()
	assert_eq(sky.weather, SkyWeather.WEATHER_CLEAR, "the cycle must open on clear weather")
	var modifiers: Dictionary = sky.lighting_modifiers()
	assert_eq(modifiers["sun_energy"], 1.0, "clear noon must not dim the authored sun")
	assert_eq(modifiers["ambient_energy"], 1.0, "clear noon must not dim the authored ambient")
	assert_eq(sky.rain_intensity(), 0.0, "clear weather must not rain")
	assert_true(sky.wind_strength() > 0.0 and sky.wind_strength() < 0.4, "clear weather keeps a light harbor breeze")
	assert_true(sky.wind_direction_xz().length() > 0.9, "wind direction must stay unit-length")
	sky.free()


func test_weather_sequence_is_deterministic() -> void:
	var first = SkyWeather.new()
	var second = SkyWeather.new()
	var first_sequence: Array[StringName] = []
	var second_sequence: Array[StringName] = []
	for step in 600:
		first.advance(1.0)
		second.advance(1.0)
		first_sequence.append(first.weather)
		second_sequence.append(second.weather)
	assert_eq(first_sequence, second_sequence, "the fixed seed must reproduce the same weather run")
	assert_array_contains(first_sequence, SkyWeather.WEATHER_CLOUDY, "clouds must roll in within ten in-game days")
	first.free()
	second.free()


func test_transition_blends_toward_rain_profile() -> void:
	var sky = SkyWeather.new()
	sky.auto_weather = false
	sky.set_weather(SkyWeather.WEATHER_RAIN)
	sky.advance(SkyWeather.TRANSITION_SECONDS * 0.5)
	var mid := sky.rain_intensity()
	assert_true(mid > 0.0 and mid < 1.0, "rain must fade in through the transition, not snap")
	sky.advance(SkyWeather.TRANSITION_SECONDS)
	assert_eq(sky.rain_intensity(), 1.0, "the completed transition must reach the full rain profile")
	assert_true(sky.wind_strength() > 0.8, "storm wind must rise with the rain profile")
	var modifiers: Dictionary = sky.lighting_modifiers()
	assert_true(modifiers["sun_energy"] < 0.5, "storm light must be visibly dimmer than clear light")
	assert_true(modifiers["overcast"] > 0.5, "storm light must desaturate toward overcast gray")
	sky.free()


func test_manual_weather_holds_when_auto_disabled() -> void:
	var sky = SkyWeather.new()
	sky.auto_weather = false
	sky.advance(10_000.0)
	assert_eq(sky.weather, SkyWeather.WEATHER_CLEAR, "auto_weather=false must pin the current state")
	sky.free()


func test_rain_only_follows_cloudy() -> void:
	var sky = SkyWeather.new()
	var previous: StringName = sky.weather
	for step in 3_000:
		sky.advance(1.0)
		if sky.weather != previous:
			if sky.weather == SkyWeather.WEATHER_RAIN:
				assert_eq(previous, SkyWeather.WEATHER_CLOUDY, "rain must never start from a clear sky")
			previous = sky.weather
	sky.free()


func test_sky_shader_covers_required_features() -> void:
	var source: String = SkyWeather.SKY_SHADER.code
	assert_true("shader_type sky" in source, "the dome must be a sky shader, not a mesh hack")
	assert_true("day_blend" in source, "the sky must follow the day/night cycle")
	assert_true("sunset_factor" in source, "dawn and dusk must warm the horizon")
	assert_true("cloud_coverage" in source, "weather must drive procedural cloud coverage")
	assert_true("moon_direction" in source, "the night sky must place a moon disk")
	assert_true("moon_normal" in source, "the moon disk must shade as a sphere")
	assert_true("lunar_albedo" in source, "the moon must include stable surface detail")
	assert_true("moon_halo" in source, "the moon must have a restrained atmospheric halo")


func test_catalog_contains_real_naked_eye_stars() -> void:
	assert_eq(SkyWeather.STAR_CATALOG.STARS.size(), 1627, "the sky must use the committed Hipparcos magnitude <= 5 catalog")
	var polaris: Vector4
	var sirius: Vector4
	for star in SkyWeather.STAR_CATALOG.STARS:
		if is_equal_approx(star.x, 37.9545) and is_equal_approx(star.y, 89.2641):
			polaris = star
		if is_equal_approx(star.x, 101.2872) and is_equal_approx(star.y, -16.7161):
			sirius = star
	assert_true(polaris != Vector4.ZERO, "Polaris must anchor the northern constellations")
	assert_true(sirius != Vector4.ZERO, "Sirius must anchor the spring/winter constellation field")


func test_catalog_is_precessed_to_campaign_year() -> void:
	var polaris_1343 := SkyWeather.precess_equatorial(
		Vector4(37.9545, 89.2641, 1.97, 0.636),
		SkyWeather.STAR_CATALOG.CATALOG_EPOCH,
		SkyWeather.SKY_EPOCH_YEAR
	)
	assert_true(absf(polaris_1343.x - 1.28) < 0.02, "1343 Polaris right ascension must reflect precession")
	assert_true(absf(polaris_1343.y - 85.71) < 0.02, "1343 Polaris declination must reflect precession")
	assert_eq(SkyWeather.REFERENCE_DATE, "1343-04-23", "the sky must follow the canonical St George's Night date")


func test_star_brightness_and_color_follow_catalog_photometry() -> void:
	assert_true(
		SkyWeather.magnitude_to_luminance(1.0) > SkyWeather.magnitude_to_luminance(4.0),
		"lower apparent magnitude must render brighter"
	)
	var blue := SkyWeather.bv_to_rgb(-0.2)
	var red := SkyWeather.bv_to_rgb(1.6)
	assert_true(blue.b > blue.r, "negative B-V stars must render blue-white")
	assert_true(red.r > red.b, "high B-V stars must render warm")


func test_shader_projects_stars_for_tallinn_and_weather() -> void:
	var source: String = SkyWeather.SKY_SHADER.code
	assert_true("star_map" in source, "the sky must sample the real star catalog texture")
	assert_true("observer_latitude" in source, "star altitude must use Tallinn latitude")
	assert_true("sidereal_angle" in source, "stars must rotate with the day/night clock")
	assert_true("equatorial_uv" in source, "catalog coordinates must project into the local horizon")
	assert_true("(1.0 - clouds)" in source, "weather must occlude stars")


func test_sun_crosses_the_sky_from_east_to_west() -> void:
	var spring_date := {"day": 21, "month": 4, "year": 1343}
	var morning := SkyWeather.solar_direction(6.0 / 24.0, spring_date)
	var evening := SkyWeather.solar_direction(18.0 / 24.0, spring_date)
	assert_true(morning.y > 0.0, "the spring morning sun must be above the horizon")
	assert_true(morning.x > 0.0, "the morning sun must rise in the eastern (+X) sky")
	assert_true(evening.y > 0.0, "the spring evening sun must still be above the horizon")
	assert_true(evening.x < 0.0, "the evening sun must set in the western (-X) sky")


func test_day_length_and_noon_height_follow_the_calendar() -> void:
	var winter := {"day": 21, "month": 12, "year": 1343}
	var spring := {"day": 21, "month": 4, "year": 1343}
	var summer := {"day": 21, "month": 6, "year": 1343}
	var winter_times := SkyWeather.sunrise_sunset_hours(winter)
	var spring_times := SkyWeather.sunrise_sunset_hours(spring)
	var summer_times := SkyWeather.sunrise_sunset_hours(summer)
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
		SkyWeather.solar_elevation_degrees(0.5, summer) > SkyWeather.solar_elevation_degrees(0.5, winter),
		"the summer noon sun must climb higher than the winter noon sun"
	)


func test_campaign_calendar_drives_daylight_thresholds() -> void:
	var winter := {"day": 21, "month": 12, "year": 1343}
	var summer := {"day": 21, "month": 6, "year": 1343}
	assert_true(
		SkyWeather.daylight_blend(7.0 / 24.0, summer) > 0.5,
		"07:00 must be daylight in a Reval summer"
	)
	assert_true(
		SkyWeather.daylight_blend(7.0 / 24.0, winter) < 0.5,
		"07:00 must still be night in a Reval winter"
	)
