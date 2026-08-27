extends "res://tests/godot/test_case.gd"

const MapTypesContract := preload("res://scripts/map/map_types.gd")
const MaterialsFacade := preload("res://scripts/map/view3d/map_view_materials.gd")
const ShaderSources := preload("res://scripts/map/view3d/map_view_material_shaders.gd")


func test_all_water_ids_use_one_approved_shader_family() -> void:
	MaterialsFacade.reset()
	assert_eq(
		MaterialsFacade.WATER_TERRAINS,
		MapTypesContract.WATER_TERRAINS,
		"the public facade must cover every stable water terrain ID",
	)
	var source := ShaderSources.WATER_SHADER_CODE
	var shared_shader: Shader = null
	for terrain_id: StringName in MapTypesContract.WATER_TERRAINS:
		var material := MaterialsFacade.water_surface(terrain_id)
		assert_true(
			material is ShaderMaterial,
			"%s must resolve to a ShaderMaterial" % terrain_id,
		)
		if not material is ShaderMaterial:
			continue
		var water_material := material as ShaderMaterial
		assert_true(
			water_material.shader != null,
			"%s must have a water shader" % terrain_id,
		)
		if water_material.shader == null:
			continue
		if shared_shader == null:
			shared_shader = water_material.shader
		else:
			assert_eq(
				water_material.shader,
				shared_shader,
				"%s must use the shared water shader resource" % terrain_id,
			)
		assert_eq(
			water_material.shader.code,
			source,
			"%s must use the approved water shader source" % terrain_id,
		)


func test_water_profiles_keep_optical_flow_and_tide_roles_distinct() -> void:
	MaterialsFacade.reset()
	var shallow := MaterialsFacade.water_surface(MapTypesContract.TERRAIN_SHALLOW_WATER)
	var deep := MaterialsFacade.water_surface(MapTypesContract.TERRAIN_DEEP_WATER)
	var enclosed := MaterialsFacade.water_surface(MapTypesContract.TERRAIN_WATER)
	var river := MaterialsFacade.water_surface(MapTypesContract.TERRAIN_RIVER_WATER)

	var shallow_optical := float(shallow.get_shader_parameter("optical_depth"))
	var deep_optical := float(deep.get_shader_parameter("optical_depth"))
	var enclosed_optical := float(enclosed.get_shader_parameter("optical_depth"))
	var river_optical := float(river.get_shader_parameter("optical_depth"))
	assert_true(shallow_optical < river_optical, "shallow water needs the shortest optical column")
	assert_true(river_optical < enclosed_optical, "river water needs a distinct optical column")
	assert_true(enclosed_optical < deep_optical, "deep water needs the longest optical column")

	assert_eq(
		river.get_shader_parameter("flow_direction"),
		Vector2(0.0, -1.0),
		"river current must follow the authored Pirita direction",
	)
	assert_true(
		float(river.get_shader_parameter("flow_strength")) > 0.0,
		"river water must expose a non-zero current",
	)
	for still_material: ShaderMaterial in [shallow, deep, enclosed]:
		assert_eq(
			still_material.get_shader_parameter("flow_direction"),
			Vector2.ZERO,
			"coastal and enclosed water must remain still",
		)
		assert_eq(
			float(still_material.get_shader_parameter("flow_strength")),
			0.0,
			"non-river water must not inherit river current",
		)

	assert_true(
		float(shallow.get_shader_parameter("tide_shore_retreat")) > 0.0,
		"shallow coastal water must expose shoreline tide response",
	)
	assert_true(
		float(deep.get_shader_parameter("tide_optical_depth")) > 0.0,
		"deep coastal water must expose optical tide response",
	)
	for river_tide_parameter: String in ["tide_height", "tide_shore_retreat", "tide_optical_depth"]:
		assert_eq(
			float(river.get_shader_parameter(river_tide_parameter)),
			0.0,
			"river water must keep %s outside coastal tide logic" % river_tide_parameter,
		)


func test_water_shader_declares_reflection_inputs_and_safe_compatibility_fallbacks() -> void:
	var source := ShaderSources.WATER_SHADER_CODE
	for feature in [
		"hint_screen_texture",
		"hint_depth_texture",
		"optical_depth",
		"foam_intensity",
		"wave_height",
		"flow_direction",
		"flow_strength",
		"tide_level",
		"tide_height",
		"star_map",
		"sun_direction",
		"moon_direction",
		"observer_latitude",
		"sidereal_angle",
		"fresnel",
	]:
		assert_true(feature in source, "water shader must retain %s" % feature)
	assert_true("render_mode blend_mix" in source, "water must use a GL-compatible spatial blend")
	assert_true(
		"refracted_uv = SCREEN_UV" in source,
		"invalid depth samples need a screen-space fallback",
	)
	assert_true(
		"vec2(0.001)" in source,
		"screen UV distortion must be clamped away from texture edges",
	)
	assert_true(
		"max(geometric_depth, terrain_optical_depth)" in source,
		"water needs a safe optical depth floor",
	)
	assert_false(
		"planar_reflection" in source.to_lower(),
		"water must not depend on a planar reflection pass",
	)
