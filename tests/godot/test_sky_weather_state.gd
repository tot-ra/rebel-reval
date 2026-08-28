extends "res://tests/godot/test_case.gd"

const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")
const SkyWeatherState := preload("res://scripts/map/view3d/sky_weather_state.gd")


func test_default_state_is_versioned_and_renderer_free() -> void:
	var state := SkyWeatherState.default_state()
	assert_eq(
		state.schema_version,
		SkyWeatherState.CURRENT_VERSION,
		"the contract needs an explicit schema version"
	)
	assert_eq(
		state.weather,
		SkyWeatherState.WEATHER_CLEAR,
		"new sessions must begin in clear weather"
	)
	assert_eq(
		state.calendar_date,
		{"day": 21, "month": 4, "year": 1343},
		"state uses the campaign date"
	)
	assert_true(state.validation_errors().is_empty(), "the default contract must validate")
	var payload := state.to_dict()
	assert_false(
		payload.has("environment"),
		"renderer objects must not cross the persistence boundary"
	)
	assert_false(
		payload.has("camera"),
		"camera references must not cross the persistence boundary"
	)


func test_payload_lists_every_persisted_field() -> void:
	var expected_keys: Array[String] = [
		"schema_version",
		"weather",
		"transition_from_weather",
		"transition_progress",
		"time_in_state",
		"state_duration",
		"auto_weather",
		"time_scale",
		"rain_suppressed",
		"calendar_date",
		"cycle_progress",
		"elapsed_days",
		"cloud_offset",
		"cloud_detail_offset",
		"puddle_wetness",
		"seconds_since_rain",
		"gust",
		"gust_time",
		"lightning",
		"lightning_direction",
		"lightning_time",
		"time_to_strike",
		"weather_rng_state",
		"lightning_rng_state",
		"current_profile",
		"transition_from_profile",
	]
	var payload := SkyWeatherState.default_state().to_dict()
	assert_eq(payload.size(), expected_keys.size(), "payload field count must match the contract")
	for key in expected_keys:
		assert_true(payload.has(key), "persisted field is missing from the payload: %s" % key)


func test_state_round_trip_preserves_weather_continuity_inputs() -> void:
	var source := SkyWeather.new()
	source.auto_weather = false
	source.set_weather(SkyWeather.WEATHER_RAIN)
	source.advance(SkyWeather.TRANSITION_SECONDS * 0.4)
	var expected := source.snapshot_state(0.75, 3)
	var encoded := JSON.stringify(expected.to_dict())
	var decoded: Variant = JSON.parse_string(encoded)
	assert_true(decoded is Dictionary, "state payload must survive JSON encoding")
	var restored := SkyWeatherState.from_dict(decoded as Dictionary)
	assert_true(
		restored.validation_errors().is_empty(),
		"serialized state must validate after a JSON-like round trip"
	)
	var target := SkyWeather.new()
	assert_true(target.apply_state(restored), "a validated state must restore into a new presenter")
	var actual := target.snapshot_state(0.75, 3)
	assert_true(
		actual.to_dict() == expected.to_dict(),
		"map transition must not change deterministic weather state"
	)
	source.free()
	target.free()


func test_invalid_schema_is_rejected_without_mutating_presenter() -> void:
	var sky := SkyWeather.new()
	sky.auto_weather = false
	var before := sky.snapshot_state()
	var invalid := SkyWeatherState.from_dict(
		{"schema_version": SkyWeatherState.CURRENT_VERSION + 1, "weather": "clear"}
	)
	assert_true(invalid.validation_errors().size() > 0, "future schema versions must be rejected")
	assert_false(sky.apply_state(invalid), "presenter must reject a future schema")
	assert_eq(
		sky.snapshot_state().to_dict(),
		before.to_dict(),
		"rejection must leave the live presenter untouched"
	)
	sky.free()


func test_out_of_range_state_normalizes_to_safe_contract_values() -> void:
	var state := SkyWeatherState.from_dict(
		{
			"weather": "not-a-weather-mode",
			"transition_progress": 4.0,
			"time_scale": 999.0,
			"cycle_progress": -2.0,
			"puddle_wetness": -1.0,
			"lightning_direction": [0.0, 0.0],
		}
	)
	assert_eq(state.weather, SkyWeatherState.WEATHER_CLEAR, "unknown modes fall back to clear")
	assert_eq(state.transition_progress, 1.0, "transition progress is clamped")
	assert_eq(
		state.time_scale,
		SkyWeatherState.MAX_TIME_SCALE,
		"time scale is capped for performance safety"
	)
	assert_true(
		state.cycle_progress >= 0.0 and state.cycle_progress < 1.0,
		"clock progress is wrapped"
	)
	assert_eq(state.puddle_wetness, 0.0, "negative retained wetness is removed")
	assert_true(
		state.lightning_direction.length() > 0.9,
		"zero lightning direction gets a safe fallback"
	)
	assert_true(state.validation_errors().is_empty(), "normalized state must validate")
