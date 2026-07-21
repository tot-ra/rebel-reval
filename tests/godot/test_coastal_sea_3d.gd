extends "res://tests/godot/test_case.gd"

const HarborNorthDefinition := preload("res://scripts/map/definitions/outdoor/reval_harbor_north_definition.gd")
const HarborEastDefinition := preload("res://scripts/map/definitions/outdoor/reval_harbor_east_definition.gd")


func test_harbor_maps_have_irregular_authored_waterlines() -> void:
	for definition: MapDefinition in [HarborNorthDefinition.create(), HarborEastDefinition.create()]:
		var grid := MapBuilder.build(definition)
		var first_sand_rows: Dictionary = {}
		for x in grid.size_cells.x:
			for y in grid.size_cells.y:
				if grid.get_terrain(Vector2i(x, y)) == MapTypes.TERRAIN_COAST_SAND:
					first_sand_rows[y] = true
					break
		assert_true(
			first_sand_rows.size() >= 3,
			"%s needs coves and headlands instead of one straight shoreline" % String(definition.map_id)
		)


func test_harbor_coastal_rocks_are_deterministic_and_visible() -> void:
	for definition: MapDefinition in [HarborNorthDefinition.create(), HarborEastDefinition.create()]:
		var grid := MapBuilder.build(definition)
		var first := MapViewMeshBuilder.build_scatter(definition, grid)
		var second := MapViewMeshBuilder.build_scatter(definition, grid)
		var first_rocks := first.get_node_or_null("CoastalRocks") as MultiMeshInstance3D
		var second_rocks := second.get_node_or_null("CoastalRocks") as MultiMeshInstance3D
		assert_true(first_rocks != null, "%s needs wave-washed rocks along the beach" % String(definition.map_id))
		assert_true(second_rocks != null, "%s must reproduce its rock scatter" % String(definition.map_id))
		if first_rocks != null and second_rocks != null:
			assert_true(first_rocks.multimesh.instance_count >= 8, "%s shoreline rocks must be readable at gameplay zoom" % String(definition.map_id))
			assert_eq(first_rocks.multimesh.instance_count, second_rocks.multimesh.instance_count, "the map seed must stabilize coastal rock count")
			for index in first_rocks.multimesh.instance_count:
				assert_eq(
					first_rocks.multimesh.get_instance_transform(index),
					second_rocks.multimesh.get_instance_transform(index),
					"the map seed must stabilize every coastal rock transform"
				)
		first.free()
		second.free()


func test_weather_changes_wave_speed_height_and_breakers() -> void:
	MapViewMaterials.apply_sea_weather(0.22, 0.0)
	var shallow := MapViewMaterials.water_surface(MapTypes.TERRAIN_SHALLOW_WATER)
	var calm_height := float(shallow.get_shader_parameter("wave_height"))
	var calm_speed := float(shallow.get_shader_parameter("wave_speed"))
	var calm_breakers := float(shallow.get_shader_parameter("breaker_intensity"))
	MapViewMaterials.apply_sea_weather(0.92, 1.0)
	var storm_height := float(shallow.get_shader_parameter("wave_height"))
	var storm_speed := float(shallow.get_shader_parameter("wave_speed"))
	var storm_breakers := float(shallow.get_shader_parameter("breaker_intensity"))
	assert_true(storm_height > calm_height * 2.0, "storm weather must produce visibly taller waves")
	assert_true(storm_speed > calm_speed * 1.5, "storm weather must drive a faster sea")
	assert_true(storm_breakers > calm_breakers * 2.0, "storm weather must strengthen breaking surf")
	MapViewMaterials.apply_sea_weather(0.22, 0.0)


func test_water_shader_contains_advancing_shore_breakers() -> void:
	var source := MapViewMaterialShaders.WATER_SHADER_CODE
	assert_true("breaker_intensity" in source, "weather must be able to strengthen breaking waves")
	assert_true("breaker_phase" in source, "surf bands must advance through the shoreline contour")
	assert_true("shoaling" in source, "waves must rise as they enter shallow water")
	assert_true("TIME * wave_speed" in source, "weather must control visible wave speed")


func test_water_shader_layers_seabed_materials_by_depth() -> void:
	var source := MapViewMaterialShaders.WATER_SHADER_CODE
	for uniform_name in ["sand_bed_color", "stone_bed_color", "algae_bed_color", "deep_bed_color"]:
		assert_true(uniform_name in source, "water needs a %s seabed layer" % uniform_name)
	assert_true("_seabed_layers" in source, "seabed masks must be stable procedural layers")
	assert_true("bed_layers.w" in source, "deep water must replace shallow bed detail")
	assert_true("floor_color" in source, "authored underwater geometry must remain visible")
	assert_true("spectral_transmission" in source, "water lighting must attenuate wavelengths by depth")
	assert_true("_bed_caustics" in source, "sunlit shallows need moving floor light")
	assert_true("day_blend" in source, "floor caustics must fade at night")


func test_authored_water_families_keep_distinct_optical_depths() -> void:
	var shallow := MapViewMaterials.water_surface(MapTypes.TERRAIN_SHALLOW_WATER)
	var river := MapViewMaterials.water_surface(MapTypes.TERRAIN_WATER)
	var deep := MapViewMaterials.water_surface(MapTypes.TERRAIN_DEEP_WATER)
	assert_true(
		float(shallow.get_shader_parameter("depth_absorption"))
		< float(river.get_shader_parameter("depth_absorption")),
		"river water must hide more bed light than shallow coastal water"
	)
	assert_true(
		float(river.get_shader_parameter("depth_absorption"))
		< float(deep.get_shader_parameter("depth_absorption")),
		"deep water must hide more bed light than river water"
	)
	assert_true("terrain_optical_depth" in deep.shader.code, "flat gameplay beds need visual depth per terrain family")
