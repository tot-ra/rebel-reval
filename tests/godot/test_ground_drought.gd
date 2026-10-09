extends "res://tests/godot/test_case.gd"

## R-1516: drought spells, sun-baked ground dryness and the cracks -> loose earth ->
## puddles order when rain returns (docs/SYSTEMS/WEATHER_GROUND.md).

const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")
const SkyWeatherState := preload("res://scripts/map/view3d/sky_weather_state.gd")

# gdlint: disable=max-line-length


func _manual_sky() -> Node:
	var sky = SkyWeather.new()
	sky.auto_weather = false
	return sky


func test_fair_spell_dusts_ground_but_never_cracks_it() -> void:
	var sky = _manual_sky()
	sky.set_weather(SkyWeather.WEATHER_CLOUDLESS)
	sky.advance(2000.0)
	assert_true(sky.ground_dryness() > 0.0, "open sun must dry bare ground")
	assert_true(
		sky.ground_dryness() <= SkyWeather.DRYNESS_FAIR_CAP + 0.0001,
		"without a drought dryness stays under the crack threshold"
	)
	sky.free()


func test_puddles_must_dry_before_the_soil_bakes() -> void:
	var sky = _manual_sky()
	sky.set_weather(SkyWeather.WEATHER_RAIN)
	sky.advance(SkyWeather.TRANSITION_SECONDS + 5.0)
	sky.set_weather(SkyWeather.WEATHER_CLOUDLESS)
	sky.advance(SkyWeather.TRANSITION_SECONDS + 20.0)
	assert_true(sky.puddle_wetness() > 0.0, "puddles still stand shortly after rain")
	assert_eq(sky.ground_dryness(), 0.0, "ground with standing water cannot bake dry")
	sky.free()


func test_drought_bakes_cracks_and_they_outlast_it() -> void:
	var sky = _manual_sky()
	sky.set_weather(SkyWeather.WEATHER_CLOUDLESS)
	sky.start_drought(600.0)
	assert_true(sky.drought_active(), "start_drought must open a drought spell")
	sky.advance(SkyWeather.TRANSITION_SECONDS)
	for step in 400:
		sky.advance(1.0)
	assert_true(sky.ground_dryness() > 0.9, "a long drought must crack the basins open")
	sky.start_drought(0.0)
	sky.advance(300.0)
	assert_true(sky.ground_dryness() > 0.9, "only rain closes the cracks, not the end of the drought")
	sky.free()


func test_rain_soaks_cracks_before_puddles_form() -> void:
	var sky = _manual_sky()
	sky.set_weather(SkyWeather.WEATHER_CLOUDLESS)
	sky.start_drought(600.0)
	sky.advance(SkyWeather.TRANSITION_SECONDS)
	for step in 400:
		sky.advance(1.0)
	var cracked: float = sky.ground_dryness()
	sky.set_weather(SkyWeather.WEATHER_RAIN)
	var saw_loose_earth := false
	for step in 200:
		sky.advance(0.5)
		if sky.rain_intensity() > 0.001:
			assert_false(sky.drought_active(), "rain must end a drought")
		if sky.ground_dryness() > 0.0:
			assert_eq(sky.puddle_wetness(), 0.0, "no puddle may form on cracked or baked ground")
		elif sky.ground_dryness() < cracked:
			saw_loose_earth = true
	assert_true(saw_loose_earth, "rain must soak the crust back to loose earth")
	assert_true(sky.puddle_wetness() > 0.0, "once soaked, continued rain must fill puddles again")
	sky.free()


func test_drought_keeps_the_auto_sky_dry() -> void:
	var sky = SkyWeather.new()
	sky.set_weather(SkyWeather.WEATHER_CLEAR)
	sky.advance(SkyWeather.TRANSITION_SECONDS)
	sky.start_drought(100000.0)
	for step in 3000:
		sky.advance(1.0)
		assert_true(
			sky.weather in [SkyWeather.WEATHER_CLEAR, SkyWeather.WEATHER_CLOUDLESS, SkyWeather.WEATHER_CLOUDY],
			"a drought sky never thickens to overcast, rain or storm"
		)
	assert_eq(sky.rain_intensity(), 0.0, "no rain falls during a drought")
	sky.free()


func test_drought_starts_only_from_clear_sky_over_parched_ground() -> void:
	var sky = _manual_sky()
	sky.set_weather(SkyWeather.WEATHER_OVERCAST)
	sky.advance(SkyWeather.TRANSITION_SECONDS)
	assert_true(sky.ground_dryness() < SkyWeather.DROUGHT_ONSET_DRYNESS, "fresh ground under cloud has not been parched yet")
	var started := false
	# Fresh ground: no roll may start a drought however often the sky clears.
	for step in 40:
		sky.set_weather(SkyWeather.WEATHER_CLEAR if step % 2 == 0 else SkyWeather.WEATHER_CLOUDY)
		started = started or sky.drought_active()
	assert_false(started, "a drought needs ground already parched by a fair spell")
	sky.set_weather(SkyWeather.WEATHER_CLOUDLESS)
	sky.advance(2000.0)
	for step in 80:
		sky.set_weather(SkyWeather.WEATHER_CLOUDY if step % 2 == 0 else SkyWeather.WEATHER_CLOUDLESS)
		if sky.drought_active():
			started = true
			assert_true(
				sky.weather in [SkyWeather.WEATHER_CLEAR, SkyWeather.WEATHER_CLOUDLESS],
				"droughts open on a clear or cloudless sky"
			)
			break
	assert_true(started, "parched ground under repeated clearing must eventually tip into a drought")
	sky.free()


func test_dryness_and_drought_survive_save_round_trip() -> void:
	var sky = _manual_sky()
	sky.set_weather(SkyWeather.WEATHER_CLOUDLESS)
	sky.start_drought(500.0)
	sky.advance(SkyWeather.TRANSITION_SECONDS)
	for step in 120:
		sky.advance(1.0)
	var state = sky.snapshot_state(0.5, 0)
	var restored_state = SkyWeatherState.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())))
	var restored = SkyWeather.new()
	assert_true(restored.apply_state(restored_state), "saved drought state must validate")
	assert_true(is_equal_approx(restored.ground_dryness(), sky.ground_dryness()), "dryness round-trips")
	assert_true(is_equal_approx(restored.drought_seconds_left(), sky.drought_seconds_left()), "drought timer round-trips")
	sky.free()
	restored.free()


func test_old_saves_load_with_wet_ground_and_no_drought() -> void:
	var data: Dictionary = SkyWeatherState.default_state().to_dict()
	data.erase("ground_dryness")
	data.erase("drought_seconds_left")
	data.erase("drought_rng_state")
	var state = SkyWeatherState.from_dict(data)
	assert_eq(state.validation_errors(), [] as Array[String], "pre-R-1516 saves stay valid")
	assert_eq(state.ground_dryness, 0.0, "old saves load with unbaked ground")
	assert_eq(state.drought_seconds_left, 0.0, "old saves load without a drought")
