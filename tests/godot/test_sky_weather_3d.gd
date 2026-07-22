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
	assert_array_contains(first_sequence, SkyWeather.WEATHER_RAIN, "rain must be reachable, and frequent enough to catch in a short run")
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


func test_morning_fog_potential_is_deterministic_daily_and_occasional() -> void:
	var may_10 := {"day": 10, "month": 5, "year": 1343}
	# Deterministic per calendar day: the same date always gives the same potential.
	assert_true(
		is_equal_approx(SkyWeather.morning_fog_potential(may_10), SkyWeather.morning_fog_potential(may_10)),
		"a given morning must repeat its fog potential exactly"
	)
	var above := 0
	var below := 0
	var last := -1.0
	var varied := false
	for day in range(1, 31):
		var potential: float = SkyWeather.morning_fog_potential({"day": day, "month": 5, "year": 1343})
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


func test_time_scale_freezes_and_accelerates_the_sky() -> void:
	# _process applies time_scale, so a paused clock (scale 0) freezes cloud drift
	# and the weather machine, while a higher scale advances the sky faster.
	var frozen = SkyWeather.new()
	frozen.time_scale = 0.0
	var frozen_start := frozen.cloud_offset()
	frozen._process(20.0)
	assert_true(frozen.cloud_offset() == frozen_start, "time_scale 0 must hold the whole sky still")

	var fast = SkyWeather.new()
	fast.time_scale = 3.0
	fast._process(1.0)
	var normal = SkyWeather.new()
	normal.time_scale = 1.0
	normal._process(1.0)
	assert_true(
		fast.cloud_offset().length() > normal.cloud_offset().length() * 2.0,
		"a higher time_scale must drift the clouds proportionally faster"
	)
	frozen.free()
	fast.free()
	normal.free()


func test_manual_weather_holds_when_auto_disabled() -> void:
	var sky = SkyWeather.new()
	sky.auto_weather = false
	sky.advance(10_000.0)
	assert_eq(sky.weather, SkyWeather.WEATHER_CLEAR, "auto_weather=false must pin the current state")
	sky.free()


func test_rain_never_starts_from_a_clear_sky() -> void:
	# Clouds must gather first, so rain is only ever entered through a cloudy or
	# overcast deck — never straight off clear or a passing shower with no build-up.
	var wet_predecessors: Array[StringName] = [SkyWeather.WEATHER_CLOUDY, SkyWeather.WEATHER_OVERCAST]
	var sky = SkyWeather.new()
	var previous: StringName = sky.weather
	for step in 4_000:
		sky.advance(1.0)
		if sky.weather != previous:
			if sky.weather == SkyWeather.WEATHER_RAIN:
				assert_true(previous in wet_predecessors, "rain must be preceded by cloudy or overcast, not clear")
			previous = sky.weather
	sky.free()


func test_weather_reaches_every_regime() -> void:
	# A short seeded run must be able to show all five regimes so the player can
	# actually catch clear, cloudy, overcast, widespread rain, and isolated storms.
	var sky = SkyWeather.new()
	var seen := {}
	for step in 4_000:
		sky.advance(1.0)
		seen[sky.weather] = true
	for regime in SkyWeather.ALL_WEATHERS:
		assert_true(seen.has(regime), "the weather cycle must reach %s within a short run" % regime)
	sky.free()


func test_isolated_storm_is_localized_while_rain_front_is_uniform() -> void:
	var sky = SkyWeather.new()
	sky.auto_weather = false
	sky.set_weather(SkyWeather.WEATHER_STORM)
	sky.advance(SkyWeather.TRANSITION_SECONDS)
	assert_true(sky.storm_intensity() > 0.9, "an isolated storm still towers a heavy cell")
	assert_true(sky.storm_locality() > 0.7, "an isolated storm must concentrate into a few cells")
	assert_true(sky.cloud_coverage() < 0.6, "an isolated storm must leave open sky around the cell")
	sky.set_weather(SkyWeather.WEATHER_RAIN)
	sky.advance(SkyWeather.TRANSITION_SECONDS)
	assert_true(sky.storm_locality() < 0.3, "a rain front must spread across the whole deck, not cluster")
	assert_true(sky.cloud_coverage() > 0.85, "a rain front must cover the sky")
	sky.free()


func test_storms_throw_lightning_that_flashes_and_decays() -> void:
	var sky = SkyWeather.new()
	sky.auto_weather = false
	assert_eq(sky.lightning_flash(), 0.0, "a clear sky must not flash")
	sky.set_weather(SkyWeather.WEATHER_STORM)
	sky.advance(SkyWeather.TRANSITION_SECONDS)
	# Drive time until a strike fires, then confirm it flashes bright and decays.
	var peak := 0.0
	for step in 2_000:
		sky.advance(0.05)
		peak = maxf(peak, sky.lightning_flash())
	assert_true(peak > 0.5, "a thunderstorm must throw bright lightning strikes")
	assert_true(sky.lightning_direction().length() > 0.9, "each strike must have a bearing to light a cell")
	# Once the storm has fully passed to clear, the sky holds no charge: after the
	# transition blend and the last flash decay, lightning must stay at zero.
	sky.set_weather(SkyWeather.WEATHER_CLEAR)
	sky.advance(SkyWeather.TRANSITION_SECONDS + 2.0)
	for step in 200:
		sky.advance(0.1)
		assert_eq(sky.lightning_flash(), 0.0, "a settled clear sky must never flash lightning")
	sky.free()


func test_sky_shader_covers_required_features() -> void:
	var source: String = SkyWeather.SKY_SHADER.code
	assert_true("shader_type sky" in source, "the dome must be a sky shader, not a mesh hack")
	assert_true("day_blend" in source, "the sky must follow the day/night cycle")
	assert_true("sunset_factor" in source, "dawn and dusk must warm the horizon")
	assert_true("cloud_coverage" in source, "weather must drive procedural cloud coverage")
	assert_true("cloud_detail_offset" in source, "cloud edges must drift independently of bank masses")
	assert_true("cloud_chaos" in source, "cloud banks must domain-warp for torn edges")
	assert_true("bank_mask" in source, "partial cloudiness must leave open sky between cloud masses")
	assert_true("cloud_shape" in source, "cumulus bodies must come from cellular puff noise, not fluid FBM swirls")
	assert_true("self_shadow" in source, "heaps must self-shadow toward the sun so they read as 3D volume")
	assert_true("storm_intensity" in source, "storms must tower into cumulonimbus, not just thicken flat cloud")
	assert_true("cloud_light" in source, "sunlit tops and shadowed undersides must shade the clouds")
	assert_true("wind_dir" in source, "cirrus and the squall wall must follow the prevailing wind")
	assert_true("rain_shafts" in source, "storms must hang distant rain curtains under the cloud deck")
	assert_true("storm_locality" in source, "storms must localize into cells instead of always covering the sky")
	assert_true("local_storm" in source, "storminess must vary across the sky so one cloud can rain while others do not")
	assert_true("lightning" in source, "thunderstorms must throw lightning that lights their cell")
	assert_true("lightning_bolt" in source, "a strike must draw a visible jagged bolt, not only a flash")
	assert_true("moon_direction" in source, "the night sky must place a moon disk")
	assert_true("moon_phase" in source, "the campaign date must drive weekly lunar lighting phases")
	assert_true(
		"-dot(sun_direction, moon_direction)" in source,
		"moon disk shading must use the live sun direction, not a phase-only fake light"
	)
	assert_true("moon_normal" in source, "the moon disk must shade as a sphere")
	assert_true("lunar_albedo" in source, "the moon must include stable surface detail")
	assert_true("textureSize(lunar_albedo_map" in source, "lunar albedo sampling must follow the authored map resolution")
	assert_true(
		"moon_uv * 0.485" in source,
		"lunar UV must inset inside the crust so limb filtering cannot pick up exterior black"
	)
	assert_true(
		"max(lunar_albedo, vec3(0.08))" not in source,
		"a dark albedo floor turns filter fringes into a visible black moon border"
	)
	assert_true(
		"mix(0.94, 1.0" in source,
		"limb darkening must stay mild so the small sky disk does not grow a dark rim"
	)
	assert_true("lommel" in source, "dusty regolith must use a Lommel-Seeliger lobe, not flat Lambertian fill")
	assert_true(
		"mix(color, moon_surface, moon_opacity)" in source,
		"the moon disk must occlude the sky opaquely instead of additively tinting blue through the surface"
	)
	assert_true("moon_ndotl" in source, "the terminator must use the signed sun cosine, not a pre-clamped light term")
	assert_true("moon_halo" in source, "the moon must have a restrained atmospheric halo")
	assert_true(
		"mix(1.0, 1.08, day_blend)" in source,
		"daytime moon photometry must stay pale-silver instead of fading into a dark sticker"
	)
	assert_true(
		"mix(1.0, 0.42, day_blend)" not in source,
		"daytime moon must not crush luminance below the blue day sky"
	)
	assert_true(
		"terminator * terminator" in source,
		"daytime crescents must hide the unlit nightside against bright sky"
	)


func test_clear_weather_is_partly_cloudy_with_moving_banks() -> void:
	var sky = SkyWeather.new()
	assert_true(
		sky.cloud_coverage() > 0.2 and sky.cloud_coverage() < 0.5,
		"clear weather must keep discrete cloud banks, not an empty or fully overcast sky"
	)
	assert_true(sky.cloud_chaos() > 0.0, "even clear banks need mild edge chaos")
	var start_offset := sky.cloud_offset()
	var start_detail := sky.cloud_detail_offset()
	sky.advance(10.0)
	assert_true(
		sky.cloud_offset() != start_offset,
		"cloud banks must translate across the sky over time"
	)
	assert_true(
		sky.cloud_detail_offset() != start_detail,
		"cloud detail must churn while banks translate"
	)
	assert_true(
		sky.cloud_detail_offset().length() > sky.cloud_offset().length(),
		"detail drift must outpace bank drift so edges look chaotic"
	)
	sky.free()


func test_storm_clouds_are_denser_and_more_chaotic_than_clear() -> void:
	var sky = SkyWeather.new()
	var clear_coverage := sky.cloud_coverage()
	var clear_chaos := sky.cloud_chaos()
	var clear_storm := sky.storm_intensity()
	sky.auto_weather = false
	sky.set_weather(SkyWeather.WEATHER_RAIN)
	sky.advance(SkyWeather.TRANSITION_SECONDS)
	assert_true(sky.cloud_coverage() > clear_coverage, "rain must thicken cloud cover")
	assert_true(sky.cloud_chaos() > clear_chaos, "rain must tear cloud edges harder")
	assert_true(sky.storm_intensity() > clear_storm, "rain must tower clear cumulus into a storm anvil")
	assert_true(sky.storm_intensity() > 0.9, "the rain profile must reach full cumulonimbus development")
	sky.free()


func test_gust_front_shoves_ahead_of_the_rain() -> void:
	var sky = SkyWeather.new()
	sky.auto_weather = false
	var calm_wind := sky.wind_strength()
	assert_eq(sky.wind_gust(), 0.0, "a clear sky must have no gust")
	sky.set_weather(SkyWeather.WEATHER_RAIN)
	# The gust peaks early, while the rain profile is still only fading in.
	sky.advance(SkyWeather.GUST_RISE_SECONDS)
	var peak_gust := sky.wind_gust()
	assert_true(peak_gust > 0.2, "a gust front must shove the wind ahead of the rain")
	assert_true(
		sky.wind_strength() > calm_wind + 0.2,
		"the gust must lift the felt wind above the calm-weather breeze"
	)
	assert_true(sky.rain_intensity() < 0.9, "the gust must arrive before the rain fully lands")
	# ... and then decays back down toward the sustained storm wind.
	sky.advance(SkyWeather.GUST_DECAY_SECONDS * 3.0)
	assert_true(sky.wind_gust() < peak_gust * 0.5, "the gust must decay after the front passes")
	assert_true(sky.wind_strength() <= 1.0, "felt wind must stay within the material range")
	sky.free()


func test_cloud_drift_accelerates_with_the_wind() -> void:
	var calm = SkyWeather.new()
	var storm = SkyWeather.new()
	calm.auto_weather = false
	storm.auto_weather = false
	storm.set_weather(SkyWeather.WEATHER_RAIN)
	storm.advance(SkyWeather.TRANSITION_SECONDS)
	var calm_start := calm.cloud_offset()
	var storm_start := storm.cloud_offset()
	calm.advance(2.0)
	storm.advance(2.0)
	var calm_moved := (calm.cloud_offset() - calm_start).length()
	var storm_moved := (storm.cloud_offset() - storm_start).length()
	assert_true(storm_moved > calm_moved, "storm wind must drive clouds across the sky faster than a calm breeze")
	calm.free()
	storm.free()


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


func test_sun_disk_visibility_matches_sky_shader_fade() -> void:
	assert_true(
		is_equal_approx(SkyWeather.sun_disk_visibility(Vector3(0.0, 0.2, 0.0)), 1.0),
		"sun above the fade band must be fully visible"
	)
	assert_true(
		is_equal_approx(SkyWeather.sun_disk_visibility(Vector3(0.0, -0.2, 0.0)), 0.0),
		"sun below the fade band must be fully hidden"
	)
	var mid := SkyWeather.sun_disk_visibility(Vector3(0.0, 0.0, 1.0))
	assert_true(mid > 0.4 and mid < 0.6, "horizon sun must be mid-fade like the sky shader")

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


func test_moon_crosses_the_sky_from_east_to_west() -> void:
	var full_moon := {"day": 10, "month": 5, "year": 1343}
	var evening := SkyWeather.lunar_direction(18.0 / 24.0, full_moon)
	var midnight := SkyWeather.lunar_direction(0.0, full_moon)
	var morning := SkyWeather.lunar_direction(6.0 / 24.0, full_moon)
	assert_true(evening.x > 0.0, "the evening full moon must rise in the eastern (+X) sky")
	assert_true(midnight.y > evening.y, "the full moon must climb after rising")
	assert_true(morning.x < 0.0, "the morning full moon must set in the western (-X) sky")


func test_celestial_motion_uses_distinct_astronomical_rates() -> void:
	var date := {"day": 21, "month": 4, "year": 1343}
	var start := 0.10
	var interval := 0.10
	var finish := start + interval
	var sun_rotation := fposmod(
		_hour_angle(SkyWeather.solar_direction(finish, date))
		- _hour_angle(SkyWeather.solar_direction(start, date)),
		TAU
	)
	var moon_rotation := fposmod(
		_hour_angle(SkyWeather.lunar_direction(finish, date))
		- _hour_angle(SkyWeather.lunar_direction(start, date)),
		TAU
	)
	var star_rotation := (
		SkyWeather.sidereal_angle_for_progress(finish)
		- SkyWeather.sidereal_angle_for_progress(start)
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
	var latitude := deg_to_rad(SkyWeather.OBSERVER_LATITUDE_DEGREES)
	var north := -direction.z
	return atan2(-direction.x, direction.y * cos(latitude) - north * sin(latitude))


func test_lunar_phase_changes_in_weekly_quarters() -> void:
	var new_moon := {"day": 25, "month": 4, "year": 1343}
	var first_quarter := {"day": 2, "month": 5, "year": 1343}
	var full_moon := {"day": 10, "month": 5, "year": 1343}
	var last_quarter := {"day": 17, "month": 5, "year": 1343}
	assert_true(SkyWeather.lunar_illumination(SkyWeather.lunar_phase(new_moon)) < 0.01, "25 April must be near new moon")
	assert_true(absf(SkyWeather.lunar_illumination(SkyWeather.lunar_phase(first_quarter)) - 0.5) < 0.1, "one week after new moon must approach first quarter")
	assert_true(SkyWeather.lunar_illumination(SkyWeather.lunar_phase(full_moon)) > 0.99, "two weeks after new moon must approach full moon")
	assert_true(absf(SkyWeather.lunar_illumination(SkyWeather.lunar_phase(last_quarter)) - 0.5) < 0.1, "three weeks after new moon must approach last quarter")
	var phase_step := fposmod(
		SkyWeather.lunar_phase({"day": 26, "month": 4, "year": 1343}) - SkyWeather.lunar_phase(new_moon),
		1.0
	)
	assert_true(
		phase_step > 0.03 and phase_step < 0.04,
		"the phase must advance by about one synodic day with each campaign date"
	)


func test_lunar_phase_shifts_rise_time_through_the_month() -> void:
	var new_moon := {"day": 25, "month": 4, "year": 1343}
	var full_moon := {"day": 10, "month": 5, "year": 1343}
	var new_moon_midnight := SkyWeather.lunar_elevation_degrees(0.0, new_moon)
	var full_moon_midnight := SkyWeather.lunar_elevation_degrees(0.0, full_moon)
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
		var spring := SkyWeather.tide_level(progress, new_moon)
		var neap := SkyWeather.tide_level(progress, first_quarter)
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
	var first_sample := SkyWeather.tide_level(0.25, new_moon)
	var second_sample := SkyWeather.tide_level(0.25, new_moon)
	assert_true(
		is_equal_approx(first_sample, second_sample),
		"the tide must be deterministic for the same date and clock time"
	)
