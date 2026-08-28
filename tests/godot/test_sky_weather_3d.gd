extends "res://tests/godot/test_case.gd"

const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")
const SkyWeatherState := preload("res://scripts/map/view3d/sky_weather_state.gd")


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


func test_snapshot_json_round_trip_preserves_full_state() -> void:
	var source := SkyWeather.new()
	source.auto_weather = false
	source.set_calendar_date({"day": 23, "month": 4, "year": 1343})
	source.set_weather(SkyWeather.WEATHER_RAIN)
	source.advance(SkyWeather.TRANSITION_SECONDS * 0.4)
	var expected = source.snapshot_state(0.75, 3)
	var payload: Variant = JSON.parse_string(JSON.stringify(expected.to_dict()))
	var target := SkyWeather.new()
	assert_true(target.restore_state(payload), "JSON snapshots must restore into a new presenter")
	assert_eq(
		target.snapshot_state(0.75, 3).to_dict(),
		expected.to_dict(),
		"JSON round-trip must preserve all weather continuity inputs"
	)
	source.free()
	target.free()


func test_snapshot_restore_continues_deterministically() -> void:
	var source := SkyWeather.new()
	source.advance(37.0)
	var snapshot = source.snapshot_state(0.5, 1)
	var target := SkyWeather.new()
	assert_true(target.restore_state(snapshot), "a typed snapshot must restore")
	for step in 20:
		source.advance(0.25)
		target.advance(0.25)
		assert_eq(
			target.snapshot_state(0.5, 1).to_dict(),
			source.snapshot_state(0.5, 1).to_dict(),
			"restored weather must produce the same next simulation step"
		)
	source.free()
	target.free()


func test_malformed_snapshot_falls_back_without_mutating_presenter() -> void:
	var sky := SkyWeather.new()
	var before = sky.snapshot_state().to_dict()
	assert_false(sky.restore_state("not a snapshot"), "non-dictionary snapshots must be rejected")
	assert_eq(sky.snapshot_state().to_dict(), before, "rejection must leave the presenter untouched")
	var future := {"schema_version": SkyWeatherState.CURRENT_VERSION + 1, "weather": "clear"}
	assert_false(sky.restore_state(future), "future snapshots must be rejected")
	assert_eq(
		sky.snapshot_state().to_dict(), before,
		"future rejection must leave the presenter untouched"
	)
	var old_snapshot := {"weather": "cloudy"}
	assert_true(
		sky.restore_state(old_snapshot),
		"older snapshots with omitted fields must use defaults"
	)
	assert_eq(sky.weather, SkyWeather.WEATHER_CLOUDY, "legacy weather mode must remain recoverable")
	sky.free()




func test_puddles_form_only_after_rain_and_dry_afterward() -> void:
	var sky = SkyWeather.new()
	sky.auto_weather = false
	assert_eq(sky.puddle_wetness(), 0.0, "a fresh weather cycle must start with dry ground")
	sky.advance(120.0)
	assert_eq(sky.puddle_wetness(), 0.0, "clear weather must not create puddles")

	sky.set_weather(SkyWeather.WEATHER_RAIN)
	sky.advance(SkyWeather.TRANSITION_SECONDS + 1.0)
	assert_true(sky.puddle_wetness() > 0.0, "rain that reaches the ground must create puddles")

	sky.set_weather(SkyWeather.WEATHER_CLEAR)
	sky.advance(SkyWeather.TRANSITION_SECONDS)
	assert_true(sky.puddle_wetness() > 0.0, "puddles must persist through the rain-to-clear transition")
	sky.advance(1.0 / SkyWeather.PUDDLE_DRY_PER_SECOND + 1.0)
	assert_eq(sky.puddle_wetness(), 0.0, "puddles must eventually dry in clear weather")
	sky.free()


func test_enclosed_shell_hides_falling_rain() -> void:
	var sky = SkyWeather.new()
	sky.auto_weather = false
	sky.set_weather(SkyWeather.WEATHER_RAIN)
	sky.advance(SkyWeather.TRANSITION_SECONDS + 1.0)
	assert_eq(sky.rain_intensity(), 1.0, "precondition: the rain profile is fully in")
	assert_true(sky.rain_emitter_visible(), "rain must fall outdoors during a rain state")
	sky.rain_suppressed = true
	assert_false(sky.rain_emitter_visible(), "a roofed interior must not rain indoors")
	assert_eq(sky.rain_intensity(), 1.0, "suppression hides the emitter only; the weather field is unchanged")
	sky.free()


func test_configured_sky_roof_audio_follows_suppression() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var sky = SkyWeather.new()
	tree.root.add_child(sky)
	var camera := Camera3D.new()
	sky.add_child(camera)
	sky.configure(camera, Environment.new())
	sky.auto_weather = false
	sky.set_weather(SkyWeather.WEATHER_RAIN)
	sky.advance(SkyWeather.TRANSITION_SECONDS + 1.0)
	sky.rain_suppressed = false
	sky.advance(0.1)
	assert_false(sky.roof_audio_active(), "outdoor rain must not arm the roof bed")
	sky.rain_suppressed = true
	sky.advance(0.1)
	assert_true(sky.roof_audio_active(), "a roofed interior during rain must arm the roof bed")
	sky.set_roof_audio_enabled(false)
	sky.advance(0.1)
	assert_false(sky.roof_audio_active(), "muting roof audio must leave weather intensity unchanged")
	assert_eq(sky.rain_intensity(), 1.0, "audio mute must not alter rain intensity")
	sky.queue_free()


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
		"celestial_north" in source,
		"the NASA near-side mosaic must align to celestial north, not world zenith"
	)
	assert_true(
		"vec2(-moon_uv.x, -moon_uv.y) * 0.485 + 0.5" in source,
		"lunar UV must inset inside the crust, flip both axes for Estonia-facing orientation, and center the mosaic"
	)
	assert_true(
		"clamp(lunar_uv" in source,
		"lunar UV must stay inside the authored disk so bilinear taps never sample the black skirt"
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
	assert_true(
		"solar_glare_fade" in source,
		"near-sun crescents must fade in solar glare instead of sitting on the sun disk"
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
