extends "res://tests/godot/test_case.gd"

const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")
const MapTypesContract := preload("res://scripts/map/map_types.gd")
const WaterMaterials := preload("res://scripts/map/view3d/map_view_water_materials.gd")
const MaterialsFacade := preload("res://scripts/map/view3d/map_view_materials.gd")
const WaterTestSupport := preload("res://tests/godot/r715_water_test_support.gd")

const MAP_VIEW_SOURCE := "res://scripts/map/view3d/map_view_3d.gd"
const SESSION_STATE_SOURCE := "res://scripts/session/session_state.gd"
const WATER_TERRAINS: Array[StringName] = [
	MapTypesContract.TERRAIN_WATER,
	MapTypesContract.TERRAIN_RIVER_WATER,
	MapTypesContract.TERRAIN_SHALLOW_WATER,
	MapTypesContract.TERRAIN_DEEP_WATER,
]


func test_one_weather_snapshot_updates_every_water_profile() -> void:
	WaterMaterials.reset()
	var sky := SkyWeather.new()
	sky.auto_weather = false
	sky.set_calendar_date({"day": 23, "month": 4, "year": 1343})
	sky.set_weather(SkyWeather.WEATHER_STORM)
	sky.advance(SkyWeather.TRANSITION_SECONDS)
	var storm_night := sky.presentation_snapshot(0.0, 0.0)
	WaterTestSupport.apply_weather_presentation(storm_night, MaterialsFacade.WATER_WAVE_BASE)

	for terrain_id: StringName in WATER_TERRAINS:
		var material := WaterMaterials.water_surface(terrain_id, MaterialsFacade.WATER_WAVE_BASE)
		assert_eq(
			float(material.get_shader_parameter("day_blend")),
			0.0,
			"%s must receive the night blend from the shared snapshot" % terrain_id,
		)
		assert_eq(
			float(material.get_shader_parameter("tide_level")),
			float(storm_night.tide_level),
			"%s must receive the shared astronomical tide" % terrain_id,
		)

	var river := WaterMaterials.water_surface(
		MapTypesContract.TERRAIN_RIVER_WATER, MaterialsFacade.WATER_WAVE_BASE
	)
	assert_eq(
		river.get_shader_parameter("flow_direction"),
		Vector2(0.0, -1.0),
		"the weather adapter must not erase the authored river current",
	)
	assert_true(
		float(river.get_shader_parameter("flow_strength")) > 0.0,
		"the weather adapter must preserve non-zero river flow",
	)
	for river_tide_parameter: String in ["tide_height", "tide_shore_retreat", "tide_optical_depth"]:
		assert_eq(
			float(river.get_shader_parameter(river_tide_parameter)),
			0.0,
			"river profile must keep %s outside coastal tide response" % river_tide_parameter,
		)

	var storm_speed := float(river.get_shader_parameter("wave_speed"))
	sky.set_weather(SkyWeather.WEATHER_CLEAR)
	sky.advance(SkyWeather.TRANSITION_SECONDS)
	var clear_day := sky.presentation_snapshot(0.5, 1.0)
	WaterTestSupport.apply_weather_presentation(clear_day, MaterialsFacade.WATER_WAVE_BASE)
	assert_true(
		float(river.get_shader_parameter("wave_speed")) < storm_speed,
		"clear weather must reduce wave speed through the same adapter",
	)
	assert_eq(
		float(river.get_shader_parameter("day_blend")),
		1.0,
		"the adapter must restore daylight without recreating water materials",
	)
	sky.free()


func test_weather_presentation_pushes_wind_heading_to_water() -> void:
	WaterMaterials.reset()
	var sky := SkyWeather.new()
	sky.auto_weather = false
	sky.set_weather(SkyWeather.WEATHER_STORM)
	sky.advance(SkyWeather.TRANSITION_SECONDS)
	var presentation := sky.presentation_snapshot(0.4, 0.6)
	WaterTestSupport.apply_weather_presentation(presentation, MaterialsFacade.WATER_WAVE_BASE)
	var material := WaterMaterials.water_surface(
		MapTypesContract.TERRAIN_DEEP_WATER, MaterialsFacade.WATER_WAVE_BASE
	)
	assert_true(
		(material.get_shader_parameter("wind_direction") as Vector2).is_equal_approx(
			presentation.wind_direction.normalized()
		),
		"the shared weather snapshot must steer cached water swell heading",
	)
	sky.free()


func test_rain_shelter_changes_emitter_only_not_water_state() -> void:
	WaterMaterials.reset()
	var sky := SkyWeather.new()
	sky.auto_weather = false
	sky.set_weather(SkyWeather.WEATHER_RAIN)
	sky.advance(SkyWeather.TRANSITION_SECONDS)
	var outside := sky.presentation_snapshot(0.25, 0.5)
	WaterTestSupport.apply_weather_presentation(outside, MaterialsFacade.WATER_WAVE_BASE)
	var outside_parameters := _water_parameters(MapTypesContract.TERRAIN_SHALLOW_WATER)

	sky.rain_suppressed = true
	var sheltered := sky.presentation_snapshot(0.25, 0.5)
	assert_true(sheltered.rain_suppressed, "the shared snapshot must retain roof suppression")
	assert_eq(
		sheltered.rain_intensity,
		outside.rain_intensity,
		"rain shelter must not mutate the shared weather intensity",
	)
	WaterTestSupport.apply_weather_presentation(sheltered, MaterialsFacade.WATER_WAVE_BASE)
	assert_eq(
		_water_parameters(MapTypesContract.TERRAIN_SHALLOW_WATER),
		outside_parameters,
		"water must keep receiving rain and wind while the visible emitter is sheltered",
	)
	sky.free()


func test_saved_weather_handoff_restores_identical_water_uniforms() -> void:
	WaterMaterials.reset()
	var source := SkyWeather.new()
	source.auto_weather = false
	source.set_calendar_date({"day": 7, "month": 5, "year": 1343})
	source.set_weather(SkyWeather.WEATHER_RAIN)
	source.advance(SkyWeather.TRANSITION_SECONDS * 0.4)
	var saved := source.snapshot_state(0.75, 3)
	var encoded: Variant = JSON.parse_string(JSON.stringify(saved.to_dict()))

	var restored := SkyWeather.new()
	assert_true(
		restored.restore_state(encoded),
		"a map handoff must accept the saved weather snapshot",
	)
	var source_presentation := source.presentation_snapshot(0.75, 0.35)
	var restored_presentation := restored.presentation_snapshot(0.75, 0.35)
	WaterTestSupport.apply_weather_presentation(
		source_presentation, MaterialsFacade.WATER_WAVE_BASE
	)
	var source_parameters := _water_parameters(MapTypesContract.TERRAIN_DEEP_WATER)
	WaterTestSupport.apply_weather_presentation(
		restored_presentation, MaterialsFacade.WATER_WAVE_BASE
	)
	_assert_water_parameters_match(
		_water_parameters(MapTypesContract.TERRAIN_DEEP_WATER),
		source_parameters,
		"save/load and map handoff must restore deterministic water uniforms",
	)
	assert_eq(
		restored_presentation.tide_level,
		source_presentation.tide_level,
		"restored astronomical time must drive the same tide",
	)
	source.free()
	restored.free()


func test_environment_binding_keeps_one_cross_map_owner() -> void:
	var map_view_source := FileAccess.get_file_as_string(MAP_VIEW_SOURCE)
	var session_source := FileAccess.get_file_as_string(SESSION_STATE_SOURCE)
	assert_eq(
		map_view_source.split("WorldEnvironment.new()").size() - 1,
		1,
		"each map view must create one renderer environment binding",
	)
	assert_eq(
		map_view_source.split("SkyWeather3D.new()").size() - 1,
		1,
		"each map view must create one weather presenter",
	)
	for required_method: String in [
		"activate_environment_binding",
		"deactivate_environment_binding",
		"environment_binding_active",
	]:
		assert_true(map_view_source.contains("func %s" % required_method))
	for session_contract: String in [
		"bind_environment_runtime",
		"unbind_environment_runtime",
		"active_environment_runtime",
		"_capture_environment_runtime",
	]:
		assert_true(session_source.contains("func %s" % session_contract))
	var water_source := FileAccess.get_file_as_string(
		"res://scripts/map/view3d/map_view_water_materials.gd"
	)
	var support_source := FileAccess.get_file_as_string(
		"res://tests/godot/r715_water_test_support.gd"
	)
	assert_true(
		water_source.contains("static func apply_sea_weather(")
		and water_source.contains("static func apply_water_lighting("),
		"water must expose the composable weather adapters",
	)
	assert_true(
		support_source.contains("static func apply_weather_presentation("),
		"tests must keep one snapshot adapter for R-715 fixtures",
	)
	assert_false(water_source.contains("var weather"), "water must not own a second weather state")
	assert_false(
		water_source.contains("SkyWeatherState"),
		"water must not serialize or duplicate the shared weather state",
	)


func _assert_water_parameters_match(
	got: Dictionary, expected: Dictionary, message: String
) -> void:
	for key: String in expected.keys():
		var a: Variant = expected[key]
		var b: Variant = got.get(key)
		if a is float:
			assert_almost_eq(float(b), float(a), 0.00001, "%s: %s" % [message, key])
		elif a is Vector2:
			assert_true(
				(a as Vector2).is_equal_approx(b as Vector2),
				"%s: %s" % [message, key],
			)
		elif a is Vector3:
			assert_true(
				(a as Vector3).is_equal_approx(b as Vector3),
				"%s: %s" % [message, key],
			)
		else:
			assert_eq(b, a, "%s: %s" % [message, key])


func _water_parameters(terrain_id: StringName) -> Dictionary:
	var material := WaterMaterials.water_surface(terrain_id, MaterialsFacade.WATER_WAVE_BASE)
	return {
		"wind_direction": material.get_shader_parameter("wind_direction"),
		"wave_height": material.get_shader_parameter("wave_height"),
		"wave_chaos": material.get_shader_parameter("wave_chaos"),
		"choppiness": material.get_shader_parameter("choppiness"),
		"wave_speed": material.get_shader_parameter("wave_speed"),
		"foam_intensity": material.get_shader_parameter("foam_intensity"),
		"sun_visibility": material.get_shader_parameter("sun_visibility"),
		"sun_reflection_visibility": material.get_shader_parameter("sun_reflection_visibility"),
		"day_blend": material.get_shader_parameter("day_blend"),
		"tide_level": material.get_shader_parameter("tide_level"),
		"sun_direction": material.get_shader_parameter("sun_direction"),
		"moon_direction": material.get_shader_parameter("moon_direction"),
		"star_visibility": material.get_shader_parameter("star_visibility"),
		"sidereal_angle": material.get_shader_parameter("sidereal_angle"),
	}
