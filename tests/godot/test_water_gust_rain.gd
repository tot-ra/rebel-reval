extends "res://tests/godot/test_case.gd"

# WR-8: gust front and rain on the open sea (docs/SYSTEMS/CITY_SEA.md).

const MaterialsFacade := preload("res://scripts/map/view3d/map_view_materials.gd")
const ShaderSources := preload("res://scripts/map/view3d/map_view_material_shaders.gd")
const MapTypesContract := preload("res://scripts/map/map_types.gd")


func test_gust_level_reaches_every_water_material() -> void:
	MaterialsFacade.reset()
	var source := ShaderSources.WATER_SHADER.code
	assert_true(
		source.contains("uniform float gust_level"), "shader declares the gust front uniform"
	)
	MaterialsFacade.apply_sea_gust(0.6)
	for terrain_id: StringName in MapTypesContract.WATER_TERRAINS:
		var material := MaterialsFacade.water_surface(terrain_id)
		assert_almost_eq(
			float(material.get_shader_parameter("gust_level")), 0.6, 0.0001,
			"%s carries the gust level" % terrain_id
		)
	MaterialsFacade.apply_sea_gust(3.0)
	var shallow := MaterialsFacade.water_surface(MapTypesContract.WATER_TERRAINS[0])
	assert_almost_eq(
		float(shallow.get_shader_parameter("gust_level")), 1.0, 0.0001, "gust level is clamped"
	)
	MaterialsFacade.apply_sea_gust(0.0)


func test_presentation_reports_gust_as_a_share_of_the_peak() -> void:
	var sky := SkyWeather3D.new()
	var idle := sky.presentation_snapshot(0.5, 1.0)
	assert_almost_eq(idle.wind_gust_level, 0.0, 0.0001, "no gust while no front is rolling in")
	sky.set_weather(SkyWeather3D.WEATHER_RAIN)
	sky.advance(SkyWeather3D.GUST_RISE_SECONDS)
	var peak := sky.presentation_snapshot(0.5, 1.0)
	assert_true(
		peak.wind_gust_level > 0.9 and peak.wind_gust_level <= 1.0, "rain front gust peaks near 1"
	)
	sky.free()


func test_rain_and_gust_shader_terms_stay_wired() -> void:
	var source := ShaderSources.WATER_SHADER.code
	# Rain: a third ring layer, the splash crown, damped capillaries, roughness and the grey far sea.
	for needle in [
		"layer < 3", "out float crown", "RAIN_CAPILLARY_KEEP", "RAIN_ROUGHNESS_VARIANCE", "rain_far",
		"gust_cell * gust_level", "out float cell, out float slick",
	]:
		assert_true(source.contains(needle), "water shader keeps %s" % needle)
