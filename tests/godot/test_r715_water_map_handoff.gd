extends "res://tests/godot/test_case.gd"

const EastDefinition := preload(
	"res://scripts/map/definitions/outdoor/reval_harbor_east_definition.gd"
)
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapParitySnapshot := preload("res://scripts/map/map_parity_snapshot.gd")
const MapTypes := preload("res://scripts/map/map_types.gd")
const MapVerification := preload("res://scripts/map/map_verification.gd")
const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")
const MapViewMaterials := preload("res://scripts/map/view3d/map_view_materials.gd")
const MapViewRuntime := preload("res://scripts/map/view3d/map_view_runtime.gd")
const NorthDefinition := preload(
	"res://scripts/map/definitions/outdoor/reval_harbor_north_definition.gd"
)
const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")

const REPORT_PATH := "res://docs/reports/r715_water_map_handoff.md"
const WATER_UNIFORM_KEYS: Array[String] = [
	"wave_height",
	"wave_chaos",
	"wave_speed",
	"foam_intensity",
	"breaker_intensity",
	"tide_level",
	"day_blend",
	"sun_direction",
	"moon_direction",
	"star_visibility",
	"sidereal_angle",
]


func test_water_handoff_preserves_shared_presentation_and_map_parity() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var session_state: Node = tree.root.get_node_or_null("SessionState")
	assert_true(session_state != null, "handoff fixture requires the SessionState autoload")
	if session_state == null:
		return

	var source_definition := NorthDefinition.create()
	var destination_definition := EastDefinition.create()
	var source_grid := MapBuilder.build(source_definition)
	var destination_grid := MapBuilder.build(destination_definition)
	var source_parity_before := _parity_signatures(source_definition, source_grid)
	var destination_parity_before := _parity_signatures(destination_definition, destination_grid)
	var source := _build_runtime(tree, "SourceHarbor", source_definition, source_grid)
	var destination: MapViewRuntime

	session_state.state.set_environment_state(null)
	source._bind_environment_runtime()
	assert_eq(
		_active_environment_owner_count([source]),
		1,
		"source handoff must leave exactly one active WorldEnvironment owner",
	)
	assert_eq(
		session_state.active_environment_runtime(), source,
		"source presenter must own the environment before the handoff",
	)

	# Use a non-default wet night so a reset to a fresh map presenter cannot pass by
	# retaining only the weather enum. The same snapshot drives water and sky inputs.
	source.cycle_progress = 0.18
	source.cycle_elapsed_days = 3
	source.view.set_calendar_date({"day": 7, "month": 5, "year": 1343})
	var source_weather := source.environment_weather() as SkyWeather
	source_weather.auto_weather = false
	source_weather.set_weather(SkyWeather.WEATHER_RAIN)
	source_weather.advance(SkyWeather.TRANSITION_SECONDS * 0.6)
	source.view.apply_cycle_progress(source.cycle_progress)
	var source_inputs := _presentation_inputs(source)
	MapViewMaterials.apply_weather_presentation(_presentation(source))
	var source_uniforms := _water_uniforms()
	var source_snapshot := source.environment_snapshot()

	destination = _build_runtime(tree, "DestinationHarbor", destination_definition, destination_grid)
	assert_true(
		source.is_inside_tree() and destination.is_inside_tree(),
		"handoff must keep both presenters in one live SceneTree",
	)
	assert_true(
		session_state.call("bind_environment_runtime", destination),
		"destination presenter must bind through SessionState",
	)
	var destination_inputs := _presentation_inputs(destination)
	MapViewMaterials.apply_weather_presentation(_presentation(destination))
	var destination_uniforms := _water_uniforms()
	var destination_snapshot := destination.environment_snapshot()

	assert_eq(
		session_state.active_environment_runtime(), destination,
		"destination presenter must become the active SessionState owner",
	)
	assert_false(
		source.view.environment_binding_active(),
		"source presenter must be deactivated after the handoff",
	)
	assert_true(
		destination.view.environment_binding_active(),
		"destination presenter must be the active environment binding",
	)
	assert_eq(
		_active_environment_owner_count([source, destination]),
		1,
		"handoff must leave exactly one active WorldEnvironment owner",
	)
	assert_true(
		source.view.environment_node().environment == null,
		"source WorldEnvironment must be detached from the active renderer",
	)
	assert_true(
		destination.view.environment_node().environment != null,
		"destination WorldEnvironment must remain attached to the active renderer",
	)

	_assert_presentation_inputs_equal(source_inputs, destination_inputs)
	_assert_water_uniforms_equal(source_uniforms, destination_uniforms)
	assert_eq(
		destination_snapshot,
		source_snapshot,
		"SessionState must transfer the complete weather snapshot without scene reload",
	)
	assert_eq(
		_parity_signatures(source_definition, source_grid),
		source_parity_before,
		"source terrain and walkability signatures must survive presenter handoff",
	)
	assert_eq(
		_parity_signatures(destination_definition, destination_grid),
		destination_parity_before,
		"destination terrain and walkability signatures must survive presenter handoff",
	)

	print("R-815 source map ID: %s" % source_definition.map_id)
	print("R-815 destination map ID: %s" % destination_definition.map_id)
	print("R-815 source presentation: %s" % str(source_inputs))
	print("R-815 destination presentation: %s" % str(destination_inputs))
	print("R-815 source water uniforms: %s" % str(source_uniforms))
	print("R-815 destination water uniforms: %s" % str(destination_uniforms))
	print(
		"R-815 owner counts: before=1, after=%d"
		% _active_environment_owner_count([source, destination])
	)
	print(
		"R-815 source parity before/after: %s / %s"
		% [source_parity_before, _parity_signatures(source_definition, source_grid)]
	)
	print(
		"R-815 destination parity before/after: %s / %s"
		% [destination_parity_before, _parity_signatures(destination_definition, destination_grid)]
	)
	print("R-815 visual/performance evidence: BLOCKED (structural headless test only)")

	source.free()
	destination.free()
	session_state.state.set_environment_state(null)


func test_report_records_handoff_evidence_boundary() -> void:
	var report := FileAccess.get_file_as_string(REPORT_PATH)
	assert_true(not report.is_empty(), "water handoff report must exist")
	for required_anchor: String in [
		"reval_harbor_north",
		"reval_harbor_east",
		"before/after",
		"uniform keys",
		"owner counts",
		"terrain_fingerprint",
		"walkability_sha256",
		"R-757",
		"BLOCKED",
		"real-renderer visual",
		"test_r715_water_map_handoff.gd",
	]:
		assert_true(
			report.contains(required_anchor),
			"handoff report must preserve the evidence boundary: %s" % required_anchor,
		)
	for uniform_key: String in WATER_UNIFORM_KEYS:
		assert_true(
			report.contains("`%s`" % uniform_key),
			"handoff report must record uniform key %s" % uniform_key,
		)


func _build_runtime(
	tree: SceneTree, runtime_name: String, definition: MapDefinition, grid: MapTerrainGrid
) -> MapViewRuntime:
	var runtime := MapViewRuntime.new()
	runtime.name = runtime_name
	runtime._definition = definition
	runtime.view = MapView3D.create(definition, grid)
	tree.root.add_child(runtime)
	runtime.add_child(runtime.view)
	return runtime


func _presentation(runtime: MapViewRuntime) -> SkyWeather.WeatherPresentation:
	var weather := runtime.environment_weather() as SkyWeather
	var day_blend := SkyWeather.daylight_blend(runtime.cycle_progress, weather.calendar_date)
	return weather.presentation_snapshot(runtime.cycle_progress, day_blend)


func _presentation_inputs(runtime: MapViewRuntime) -> Dictionary:
	var weather := runtime.environment_weather() as SkyWeather
	var presentation := _presentation(runtime)
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
		"star_visibility": presentation.star_visibility,
		"sidereal_angle": presentation.sidereal_angle,
		"cloud_offset": weather.cloud_offset(),
		"cloud_detail_offset": weather.cloud_detail_offset(),
		"rain_suppressed": presentation.rain_suppressed,
	}


func _water_uniforms() -> Dictionary:
	var uniforms: Dictionary = {}
	for terrain_id: StringName in MapTypes.WATER_TERRAINS:
		var material := MapViewMaterials.water_surface(terrain_id)
		var terrain_uniforms: Dictionary = {}
		for uniform_key: String in WATER_UNIFORM_KEYS:
			terrain_uniforms[uniform_key] = material.get_shader_parameter(uniform_key)
		uniforms[String(terrain_id)] = terrain_uniforms
	return uniforms


func _assert_presentation_inputs_equal(source: Dictionary, destination: Dictionary) -> void:
	assert_eq(destination["weather"], source["weather"], "weather front must survive the map handoff")
	assert_eq(
		destination["rain_suppressed"],
		source["rain_suppressed"],
		"rain suppression must not be reset by the destination presenter",
	)
	for numeric_key: String in [
		"rain_intensity",
		"wind_strength",
		"puddle_wetness",
		"day_blend",
		"tide_level",
		"star_visibility",
		"sidereal_angle",
	]:
		assert_true(
			is_equal_approx(float(destination[numeric_key]), float(source[numeric_key])),
			"%s must survive the map handoff" % numeric_key,
		)
	for vector_key: String in [
		"wind_direction",
		"sun_direction",
		"moon_direction",
		"cloud_offset",
		"cloud_detail_offset",
	]:
		assert_true(
			destination[vector_key].is_equal_approx(source[vector_key]),
			"%s must survive the map handoff" % vector_key,
		)


func _assert_water_uniforms_equal(source: Dictionary, destination: Dictionary) -> void:
	assert_eq(
		destination.keys(),
		source.keys(),
		"source and destination must expose the same water terrain uniform profiles",
	)
	for terrain_id: String in source:
		var source_profile: Dictionary = source[terrain_id]
		var destination_profile: Dictionary = destination[terrain_id]
		assert_eq(
			destination_profile.keys(),
			source_profile.keys(),
			"water uniform keys must remain stable for %s" % terrain_id,
		)
		for uniform_key: String in source_profile:
			var source_value: Variant = source_profile[uniform_key]
			var destination_value: Variant = destination_profile[uniform_key]
			if source_value is Vector3:
				assert_true(
					destination_value.is_equal_approx(source_value),
					"%s.%s must survive the map handoff" % [terrain_id, uniform_key],
				)
			else:
				assert_true(
					is_equal_approx(float(destination_value), float(source_value)),
					"%s.%s must survive the map handoff" % [terrain_id, uniform_key],
				)


func _active_environment_owner_count(runtimes: Array[MapViewRuntime]) -> int:
	var count := 0
	for runtime: MapViewRuntime in runtimes:
		var environment := runtime.view.environment_node()
		if runtime.view.environment_binding_active() and environment.environment != null:
			count += 1
	return count


func _parity_signatures(definition: MapDefinition, grid: MapTerrainGrid) -> Dictionary:
	var blocked := MapVerification.blocked_cells(definition)
	var walkability := PackedByteArray()
	walkability.resize(definition.size_cells.x * definition.size_cells.y)
	for y in definition.size_cells.y:
		for x in definition.size_cells.x:
			var cell := Vector2i(x, y)
			var walkable := not MapTypes.WATER_TERRAINS.has(grid.get_terrain(cell))
			walkable = walkable and not blocked.has(cell)
			walkability[y * definition.size_cells.x + x] = 1 if walkable else 0
	return {
		"terrain_fingerprint": grid.fingerprint(),
		"terrain_grid_fingerprint": MapParitySnapshot.terrain_grid_fingerprint(grid),
		"walkability_sha256": walkability.hex_encode().sha256_text(),
		"parity_sha256": MapParitySnapshot.serialize(definition, grid).sha256_text(),
	}
