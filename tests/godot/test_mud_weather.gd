extends "res://tests/godot/test_case.gd"


func test_mud_viscosity_tracks_rain_retained_in_puddles() -> void:
	var sky := SkyWeather3D.new()
	sky.auto_weather = false
	assert_true(is_inf(sky.seconds_since_rain()))
	assert_eq(sky.mud_wetness(), 0.0)

	sky.set_weather(SkyWeather3D.WEATHER_RAIN)
	sky.advance(SkyWeather3D.TRANSITION_SECONDS + 5.0)
	var storm_wetness := sky.mud_wetness()
	assert_true(storm_wetness > 0.0, "rain must soften mud through retained ground water")
	assert_eq(sky.seconds_since_rain(), 0.0)

	sky.set_weather(SkyWeather3D.WEATHER_CLEAR)
	sky.advance(SkyWeather3D.TRANSITION_SECONDS + 10.0)
	assert_true(sky.seconds_since_rain() > 0.0)
	assert_true(sky.mud_wetness() < storm_wetness, "mud must dry after rain stops")
	sky.free()


func test_wet_mud_slows_more_than_granular_dry_mud() -> void:
	var definition := _mud_definition()
	var grid := MapBuilder.build(definition)
	var position := Vector2(48.0, 48.0)
	var dry_speed := MapTerrainMovement.speed_multiplier_at(definition, grid, position, 0.0)
	var wet_speed := MapTerrainMovement.speed_multiplier_at(definition, grid, position, 1.0)
	assert_eq(dry_speed, MapTerrainMovement.MUD_DRY_SPEED_MULTIPLIER)
	assert_eq(wet_speed, MapTerrainMovement.MUD_SATURATED_SPEED_MULTIPLIER)
	assert_true(wet_speed < dry_speed)


func test_mud_footprints_alternate_and_deepen_with_wetness() -> void:
	var trail := MudFootprints3D.new()
	assert_true(trail.try_add(Vector3.ZERO, Vector2.DOWN, 0.0))
	assert_true(trail.try_add(Vector3(0.0, 0.0, 0.6), Vector2.DOWN, 1.0))
	assert_eq(trail.get_child_count(), 2)
	var dry := trail.get_child(0) as MeshInstance3D
	var wet := trail.get_child(1) as MeshInstance3D
	assert_true(dry.position.x < 0.0)
	assert_true(wet.position.x > 0.0, "successive boots must alternate across the gait")
	assert_true(wet.scale.x > dry.scale.x, "saturated mud should spread the sole impression")
	assert_true(
		float(wet.get_meta(&"lifetime")) > float(dry.get_meta(&"lifetime")),
		"wet impressions must persist longer"
	)
	trail.free()


func _mud_definition() -> MapDefinition:
	var definition := MapDefinition.new()
	definition.map_id = &"mud_weather_test"
	definition.location = &"loc.mud_weather_test"
	definition.scope = &"prototype"
	definition.palette = &"clean_painted"
	definition.fingerprint = "mud_weather_test"
	definition.size_cells = Vector2i(4, 4)
	definition.cell_size = 32
	definition.base_terrain = MapTypes.TERRAIN_MUD
	definition.player_spawn = Vector2(48, 48)
	return definition
