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
const WATER_PARAM_TOLERANCE := 0.00001


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


## WS-04: one weather change must move the FFT cascade weights, amplitude, and
## wave heading in the same update, so the sea never steepens on a stale wind.
func test_weather_change_moves_fft_cascade_weights_with_wind_heading() -> void:
	WaterMaterials.reset()
	WaterMaterials.force_ocean_fft_support = true
	var sky := SkyWeather.new()
	sky.auto_weather = false
	sky.set_weather(SkyWeather.WEATHER_CLEAR)
	sky.advance(SkyWeather.TRANSITION_SECONDS)
	var calm := sky.presentation_snapshot(0.5, 0.0)
	WaterTestSupport.apply_weather_presentation(calm, MaterialsFacade.WATER_WAVE_BASE)
	var material := WaterMaterials.water_surface(
		MapTypesContract.TERRAIN_DEEP_WATER, MaterialsFacade.WATER_WAVE_BASE
	)
	assert_true(bool(material.get_shader_parameter("use_fft")), "deep sea takes the FFT path")
	var calm_cascades: PackedVector4Array = material.get_shader_parameter("fft_cascade")
	var calm_amplitude := float(material.get_shader_parameter("ocean_amplitude"))

	sky.set_weather(SkyWeather.WEATHER_STORM)
	sky.advance(SkyWeather.TRANSITION_SECONDS)
	var storm := sky.presentation_snapshot(0.5, 0.0)
	WaterTestSupport.apply_weather_presentation(storm, MaterialsFacade.WATER_WAVE_BASE)
	var storm_cascades: PackedVector4Array = material.get_shader_parameter("fft_cascade")
	for index in 3:
		assert_true(
			storm_cascades[index].w > calm_cascades[index].w,
			"storm must raise cascade %d weight" % index,
		)
	assert_true(
		float(material.get_shader_parameter("ocean_amplitude")) > calm_amplitude,
		"storm must raise the FFT amplitude",
	)
	assert_true(
		(material.get_shader_parameter("wind_direction") as Vector2).is_equal_approx(
			storm.wind_direction.normalized()
		),
		"the same update must steer the FFT trains to the storm heading",
	)
	var expected := WaterMaterials.fft_sea_state(storm.wind_strength, storm.rain_intensity)
	assert_almost_eq(
		storm_cascades[0].w, float(expected["weights"][0]), 0.00001,
		"material weights come from the shared fft_sea_state() mapping",
	)
	WaterMaterials.force_ocean_fft_support = false
	WaterMaterials.reset()
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
	assert_almost_eq(
		float(restored_presentation.puddle_wetness),
		float(source_presentation.puddle_wetness),
		WATER_PARAM_TOLERANCE,
		"save/load must restore retained ground wetness",
	)
	assert_almost_eq(
		float(restored_presentation.rain_intensity),
		float(source_presentation.rain_intensity),
		WATER_PARAM_TOLERANCE,
		"save/load must restore rain intensity for water adapters",
	)
	assert_true(
		restored_presentation.wind_direction.is_equal_approx(
			source_presentation.wind_direction
		),
		"save/load must restore wind heading for water",
	)
	assert_true(
		restored_presentation.sun_reflection_color.is_equal_approx(
			source_presentation.sun_reflection_color
		),
		"save/load must restore the water sun reflection colour",
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


## JSON round-trip can change Variant types while leaving printed numbers
## identical. Compare components with a tight tolerance and fail on missing
## keys or a real family mismatch instead of Dictionary ==.
func _assert_water_parameters_match(
	got: Dictionary, expected: Dictionary, message: String
) -> void:
	for key: String in expected.keys():
		assert_true(got.has(key), "%s: missing water uniform %s" % [message, key])
	for key: Variant in got.keys():
		assert_true(
			expected.has(key),
			"%s: unexpected water uniform %s" % [message, str(key)],
		)
	for key: String in expected.keys():
		if not got.has(key):
			continue
		_assert_water_value_match(got[key], expected[key], "%s: %s" % [message, key])


func _assert_water_value_match(got: Variant, expected: Variant, message: String) -> void:
	if _is_numeric(expected) or _is_numeric(got):
		if not _is_numeric(expected) or not _is_numeric(got):
			fail("%s: numeric type mismatch" % message)
			return
		assert_almost_eq(
			float(got), float(expected), WATER_PARAM_TOLERANCE, message
		)
		return
	if expected is Vector2 and got is Vector2:
		assert_true((expected as Vector2).is_equal_approx(got as Vector2), message)
		return
	if expected is Vector3 and got is Vector3:
		assert_true((expected as Vector3).is_equal_approx(got as Vector3), message)
		return
	if expected is Vector4 and got is Vector4:
		assert_true((expected as Vector4).is_equal_approx(got as Vector4), message)
		return
	if expected is Color or got is Color:
		if not _is_color_like(expected) or not _is_color_like(got):
			fail("%s: colour type mismatch" % message)
			return
		assert_true(
			_as_color(got).is_equal_approx(_as_color(expected)),
			message,
		)
		return
	assert_eq(typeof(got), typeof(expected), "%s: type mismatch" % message)
	assert_eq(got, expected, message)


func _is_numeric(value: Variant) -> bool:
	return value is float or value is int


func _is_color_like(value: Variant) -> bool:
	return value is Color or value is Vector3 or value is Vector4


func _as_color(value: Variant) -> Color:
	if value is Color:
		return value
	if value is Vector3:
		var rgb := value as Vector3
		return Color(rgb.x, rgb.y, rgb.z)
	var rgba := value as Vector4
	return Color(rgba.x, rgba.y, rgba.z, rgba.w)


func _water_parameters(terrain_id: StringName) -> Dictionary:
	var material := WaterMaterials.water_surface(terrain_id, MaterialsFacade.WATER_WAVE_BASE)
	return {
		"wind_direction": material.get_shader_parameter("wind_direction"),
		"wave_height": material.get_shader_parameter("wave_height"),
		"wave_chaos": material.get_shader_parameter("wave_chaos"),
		"choppiness": material.get_shader_parameter("choppiness"),
		"wave_speed": material.get_shader_parameter("wave_speed"),
		"breaker_intensity": material.get_shader_parameter("breaker_intensity"),
		"foam_intensity": material.get_shader_parameter("foam_intensity"),
		"sun_visibility": material.get_shader_parameter("sun_visibility"),
		"sun_reflection_visibility": material.get_shader_parameter("sun_reflection_visibility"),
		"sun_reflection_color": material.get_shader_parameter("sun_reflection_color"),
		"moon_visibility": material.get_shader_parameter("moon_visibility"),
		"day_blend": material.get_shader_parameter("day_blend"),
		"tide_level": material.get_shader_parameter("tide_level"),
		"sun_direction": material.get_shader_parameter("sun_direction"),
		"moon_direction": material.get_shader_parameter("moon_direction"),
		"star_visibility": material.get_shader_parameter("star_visibility"),
		"sidereal_angle": material.get_shader_parameter("sidereal_angle"),
	}


## WS-11: the water reflects the dome's own sky-view LUT with the dome's art exposure, and
## its sun colour is the physical one that also lights the walls.
func test_weather_presentation_binds_the_sky_view_lut_to_every_water_profile() -> void:
	MaterialsFacade.reset()
	var sky := SkyWeather.new()
	sky.auto_weather = false
	var presentation := sky.presentation_snapshot(0.8, 0.6)
	var lut := ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBAH))
	presentation.sky_lut = lut
	presentation.sky_lut_size = Vector2(4.0, 4.0)
	WaterTestSupport.apply_weather_presentation(presentation, MaterialsFacade.WATER_WAVE_BASE)
	assert_true(presentation.atmosphere_available, "the WS-09 LUT images feed the presentation")
	for terrain_id: StringName in WATER_TERRAINS:
		var material := WaterMaterials.water_surface(terrain_id, MaterialsFacade.WATER_WAVE_BASE)
		assert_true(bool(material.get_shader_parameter("sky_lut_available")), "%s LUT on" % terrain_id)
		assert_eq(
			material.get_shader_parameter("sky_view_lut"), lut, "%s samples the dome LUT" % terrain_id
		)
		assert_eq(material.get_shader_parameter("sky_lut_size"), Vector2(4.0, 4.0))
		assert_almost_eq(
			float(material.get_shader_parameter("sky_exposure")), presentation.sky_exposure, 1e-6
		)
		assert_true(
			_as_color(material.get_shader_parameter("sun_reflection_color")).is_equal_approx(
				presentation.physical_sun_color
			),
			"%s glitter uses the physical sun colour" % terrain_id
		)
	presentation.sky_lut = null
	WaterTestSupport.apply_weather_presentation(presentation, MaterialsFacade.WATER_WAVE_BASE)
	var fallback := WaterMaterials.water_surface(WATER_TERRAINS[0], MaterialsFacade.WATER_WAVE_BASE)
	assert_false(
		bool(fallback.get_shader_parameter("sky_lut_available")),
		"without a dome LUT the water keeps its gradient reflection"
	)
	sky.free()
