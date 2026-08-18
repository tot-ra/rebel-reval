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


func test_water_shader_has_dual_scrolling_detail_normals() -> void:
	var source := MapViewMaterialShaders.WATER_SHADER_CODE
	for feature in [
		"detail_normal_strength",
		"detail_normal_scale",
		"_detail_gradient",
		"_water_detail_normal",
		"layer_a",
		"layer_b",
		"current_offset",
	]:
		assert_true(feature in source, "water detail layer must expose %s" % feature)
	assert_true(
		source.find("layer_a =") < source.find("layer_b ="),
		"the two detail layers must remain independently parameterized"
	)
	assert_true(
		source.find("world_normal = normalize(mix(world_normal, detail_normal") >= 0,
		"detail normals must affect shading without replacing the broad wave normal"
	)


func test_river_water_advects_detail_normals_without_changing_tide_logic() -> void:
	var source := MapViewMaterialShaders.WATER_SHADER_CODE
	var river := MapViewMaterials.water_surface(MapTypes.TERRAIN_RIVER_WATER)
	var sea := MapViewMaterials.water_surface(MapTypes.TERRAIN_SHALLOW_WATER)
	assert_eq(
		river.get_shader_parameter("flow_direction"),
		Vector2(0.0, -1.0),
		"river detail must follow Pirita flow",
	)
	assert_true(
		float(river.get_shader_parameter("flow_strength")) > 0.0,
		"river detail must be advected",
	)
	assert_eq(
		sea.get_shader_parameter("flow_direction"),
		Vector2(0.0, 0.0),
		"coastal water must remain still",
	)
	assert_eq(
		float(sea.get_shader_parameter("flow_strength")),
		0.0,
		"coastal water must not inherit river current",
	)
	assert_true(
		float(river.get_shader_parameter("detail_normal_scale"))
			> float(sea.get_shader_parameter("detail_normal_scale")),
		"river needs tighter detail",
	)
	assert_true(
		"flow_direction * (flow_strength * time" in source,
		"current must drive both detail layers",
	)
	assert_eq(
		float(river.get_shader_parameter("tide_height")),
		0.0,
		"river must remain outside coastal tide logic",
	)


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
	assert_true("twilight_water_light" in source, "water caustics must use a broad solar transition")
	assert_true("sun_height_stability" in source, "direct water lighting must stabilize at low sun angles")
	assert_true("direct_normal_relief" in source, "wave displacement must stay separate from low-sun shading relief")
	assert_true(
		"smoothstep(-0.25, 0.25, sun_direction.y)" in source,
		"sunrise and sunset must not switch animated water illumination on at the disk edge"
	)


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


func test_coastal_tide_changes_shore_and_depth_without_affecting_rivers() -> void:
	var source := MapViewMaterialShaders.WATER_SHADER_CODE
	for feature in ["tide_level", "tide_shore_retreat", "tide_optical_depth", "discard"]:
		assert_true(feature in source, "coastal water shader needs %s tide behavior" % feature)
	MapViewMaterials.apply_coastal_tide(-0.72)
	var shallow := MapViewMaterials.water_surface(MapTypes.TERRAIN_SHALLOW_WATER)
	var deep := MapViewMaterials.water_surface(MapTypes.TERRAIN_DEEP_WATER)
	var river := MapViewMaterials.water_surface(MapTypes.TERRAIN_WATER)
	assert_true(
		float(shallow.get_shader_parameter("tide_shore_retreat")) > 0.0,
		"shallow sea must expose its layered bed at low tide"
	)
	assert_true(
		float(deep.get_shader_parameter("tide_optical_depth")) > 0.0,
		"deep coastal water must change light attenuation with tide"
	)
	assert_eq(
		float(river.get_shader_parameter("tide_shore_retreat")),
		0.0,
		"river shorelines must not move with the coastal tide"
	)
	assert_eq(
		float(river.get_shader_parameter("tide_height")),
		0.0,
		"river levels must remain independent of the coastal tide"
	)
	for material: ShaderMaterial in [shallow, deep, river]:
		assert_true(
			is_equal_approx(float(material.get_shader_parameter("tide_level")), -0.72),
			"all cached water materials must receive one synchronized tide phase"
		)
	MapViewMaterials.apply_coastal_tide(0.0)
