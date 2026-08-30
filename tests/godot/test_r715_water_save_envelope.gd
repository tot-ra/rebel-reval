extends "res://tests/godot/test_case.gd"

const GameStatePersistenceScript := preload("res://scripts/state/game_state_persistence.gd")
const MapTypesContract := preload("res://scripts/map/map_types.gd")
const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")
const WaterMaterials := preload("res://scripts/map/view3d/map_view_water_materials.gd")
const MaterialsFacade := preload("res://scripts/map/view3d/map_view_materials.gd")

const REPORT_PATH := "res://docs/reports/r715_water_save_envelope.md"
const SAVE_SENTINEL := &"flag.r715_save_sentinel"
const WATER_UNIFORM_KEYS: Array[String] = [
	"wave_height",
	"wave_chaos",
	"wave_speed",
	"foam_intensity",
	"breaker_intensity",
	"sun_visibility",
	"sun_reflection_visibility",
	"day_blend",
	"tide_level",
	"sun_direction",
	"moon_direction",
	"star_visibility",
	"sidereal_angle",
]


func test_storm_night_environment_survives_game_state_json_round_trip() -> void:
	var progress := 0.08
	var day_blend := 0.0
	var source_weather := SkyWeather.new()
	source_weather.auto_weather = false
	source_weather.set_calendar_date({"day": 23, "month": 4, "year": 1343})
	source_weather.set_weather(SkyWeather.WEATHER_STORM)
	source_weather.advance(SkyWeather.TRANSITION_SECONDS)
	var source_snapshot := source_weather.snapshot_state(progress, 18)
	var source_environment: Dictionary = source_snapshot.to_dict()
	var source_state := _seed_game_state()
	assert_true(source_state.set_environment_state(source_environment))

	var saved_payload := source_state.save_payload()
	assert_true(saved_payload.has("environment"), "save_payload must include weather state")
	var json_text := JSON.stringify(saved_payload)
	var decoded: Variant = JSON.parse_string(json_text)
	assert_true(decoded is Dictionary, "the save payload must survive a JSON round-trip")
	if not decoded is Dictionary:
		source_weather.free()
		return

	var restored_state := GameState.new()
	var load_errors := GameStatePersistenceScript.load_payload(restored_state, decoded as Dictionary)
	assert_eq(load_errors, [], "GameStatePersistence must load the JSON-shaped payload")
	assert_eq(
		MapParitySnapshot.serialize_value(restored_state.get_environment_state()),
		MapParitySnapshot.serialize_value(source_environment),
		"the persisted environment snapshot must remain byte-stable after JSON decoding",
	)
	_assert_gameplay_sentinel(restored_state)

	var restored_weather := SkyWeather.new()
	assert_true(
		restored_weather.restore_state(restored_state.get_environment_state()),
		"the restored environment must hydrate a weather presenter",
	)
	var source_presentation := source_weather.presentation_snapshot(progress, day_blend)
	var restored_presentation := restored_weather.presentation_snapshot(progress, day_blend)
	_assert_presentation_inputs_equal(restored_presentation, source_presentation)
	assert_eq(source_presentation.weather, SkyWeather.WEATHER_STORM)
	assert_true(source_presentation.rain_intensity > 0.0, "storm fixture must carry rain")
	assert_true(source_presentation.wind_strength > 0.0, "storm fixture must carry wind")
	assert_true(absf(source_presentation.tide_level) > 0.001, "night fixture must carry a tide input")

	WaterMaterials.reset()
	WaterMaterials.apply_weather_presentation(source_presentation, MaterialsFacade.WATER_WAVE_BASE)
	var source_uniforms := _all_water_uniforms()
	WaterMaterials.apply_weather_presentation(restored_presentation, MaterialsFacade.WATER_WAVE_BASE)
	var restored_uniforms := _all_water_uniforms()
	assert_eq(
		restored_uniforms,
		source_uniforms,
		"every shared water profile must receive identical restored uniforms",
	)
	print("R-814 source presentation: %s" % str(_presentation_inputs(source_presentation)))
	print("R-814 restored presentation: %s" % str(_presentation_inputs(restored_presentation)))
	print("R-814 source water uniforms: %s" % str(source_uniforms))
	print("R-814 restored water uniforms: %s" % str(restored_uniforms))
	print("R-814 JSON round-trip: PASS; water profiles equal: PASS")

	restored_weather.free()
	source_weather.free()


func test_missing_environment_defaults_empty_without_gameplay_drift() -> void:
	var source_state := _seed_game_state()
	var payload := source_state.save_payload()
	payload.erase("environment")
	var restored_state := GameState.new()
	var load_errors := GameStatePersistenceScript.load_payload(restored_state, payload)

	assert_eq(load_errors, [], "a legacy payload without environment remains loadable")
	assert_true(
		restored_state.get_environment_state().is_empty(),
		"missing environment data must fail closed to an empty optional state",
	)
	_assert_gameplay_sentinel(restored_state)
	print("R-814 missing environment: PASS; gameplay sentinel unchanged: PASS")


func test_invalid_environment_fails_closed_without_gameplay_drift() -> void:
	var source_state := _seed_game_state()
	var payload := source_state.save_payload()
	payload["environment"] = {
		"schema_version": GameState.ENVIRONMENT_STATE_VERSION + 1,
		"weather": String(SkyWeather.WEATHER_STORM),
		"puddle_wetness": 0.8,
	}
	var restored_state := GameState.new()
	var load_errors := GameStatePersistenceScript.load_payload(restored_state, payload)

	assert_true(not load_errors.is_empty(), "an invalid environment must report a load error")
	assert_true(
		"environment" in ", ".join(load_errors),
		"the failure must identify the environment payload",
	)
	assert_true(
		restored_state.get_environment_state().is_empty(),
		"invalid environment data must be discarded rather than partially applied",
	)
	_assert_gameplay_sentinel(restored_state)
	print("R-814 invalid environment: PASS; fail-closed status: PASS")


func test_report_records_required_evidence_boundary() -> void:
	var report := FileAccess.get_file_as_string(REPORT_PATH)
	assert_true(report.contains("GameState.save_payload()"))
	assert_true(report.contains("GameStatePersistence.load_payload()"))
	assert_true(report.contains("JSON round-trip"))
	assert_true(report.contains("source/restored"))
	assert_true(report.contains("fail-closed"))
	assert_true(report.contains("BLOCKED"))
	assert_true(report.contains("test_r715_water_save_envelope.gd"))


func _seed_game_state() -> GameState:
	var state := GameState.new()
	state.set_phase(&"phase.investigation_night")
	state.player.health = 61.5
	state.player.location_id = &"reval_harbor_north"
	state.set_flag(SAVE_SENTINEL, true)
	return state


func _assert_gameplay_sentinel(state: GameState) -> void:
	assert_eq(state.get_phase(), &"phase.investigation_night")
	assert_true(is_equal_approx(state.player.health, 61.5))
	assert_eq(state.player.location_id, &"reval_harbor_north")
	assert_true(state.get_flag(SAVE_SENTINEL))


func _presentation_inputs(presentation: SkyWeather.WeatherPresentation) -> Dictionary:
	return {
		"weather": String(presentation.weather),
		"rain_intensity": presentation.rain_intensity,
		"wind_strength": presentation.wind_strength,
		"wind_direction": presentation.wind_direction,
		"puddle_wetness": presentation.puddle_wetness,
		"day_blend": presentation.day_blend,
		"tide_level": presentation.tide_level,
		"sun_direction": presentation.sun_direction,
		"moon_direction": presentation.moon_direction,
		"sun_visibility": presentation.sun_visibility,
		"moon_visibility": presentation.moon_visibility,
		"star_visibility": presentation.star_visibility,
		"sidereal_angle": presentation.sidereal_angle,
	}


func _assert_presentation_inputs_equal(
	restored: SkyWeather.WeatherPresentation, source: SkyWeather.WeatherPresentation
) -> void:
	assert_eq(restored.weather, source.weather, "weather mode must survive the envelope")
	for numeric_name: String in [
		"rain_intensity",
		"wind_strength",
		"puddle_wetness",
		"day_blend",
		"tide_level",
		"sun_visibility",
		"moon_visibility",
		"star_visibility",
		"sidereal_angle",
	]:
		assert_true(
			is_equal_approx(float(restored.get(numeric_name)), float(source.get(numeric_name))),
			"%s must survive the envelope" % numeric_name,
		)
	assert_true(
		restored.wind_direction.is_equal_approx(source.wind_direction),
		"wind_direction must survive the envelope",
	)
	assert_true(
		restored.sun_direction.is_equal_approx(source.sun_direction),
		"sun_direction must survive the envelope",
	)
	assert_true(
		restored.moon_direction.is_equal_approx(source.moon_direction),
		"moon_direction must survive the envelope",
	)


func _all_water_uniforms() -> Dictionary:
	var uniforms: Dictionary = {}
	for terrain_id: StringName in MapTypesContract.WATER_TERRAINS:
		var material := WaterMaterials.water_surface(terrain_id, MaterialsFacade.WATER_WAVE_BASE)
		var terrain_uniforms: Dictionary = {}
		for parameter_name: String in WATER_UNIFORM_KEYS:
			terrain_uniforms[parameter_name] = material.get_shader_parameter(parameter_name)
		uniforms[String(terrain_id)] = terrain_uniforms
	return uniforms
