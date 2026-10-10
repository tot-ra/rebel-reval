extends "res://tests/godot/test_case.gd"

## R-1516: district-map puddle decals show as cracked crust in a drought and hide
## between the soaked and the baked states.

const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")


func test_puddle_node_is_visible_in_drought() -> void:
	var sky = SkyWeather.new()
	sky.auto_weather = false
	sky.set_weather(SkyWeather.WEATHER_CLOUDLESS)
	sky.start_drought(600.0)
	sky.advance(SkyWeather.TRANSITION_SECONDS)
	for step in 400:
		sky.advance(1.0)
	assert_true(
		sky.ground_dryness() > MapView3D.PUDDLE_CRUST_DRYNESS, "drought must bake the ground"
	)
	assert_eq(sky.puddle_wetness(), 0.0)
	var view := _view_with_puddles(sky)
	var puddles := view.get_node("Scatter/Chunk/Puddles") as Node3D
	view._sync_puddle_visibility(true)
	assert_true(puddles.visible, "drought crust must reveal the puddle decals")
	var material := MapViewMaterials.WATER_MATERIALS.puddle_surface()
	assert_almost_eq(
		float(material.get_shader_parameter("ground_dryness")), sky.ground_dryness(), 0.0001
	)
	assert_eq(float(material.get_shader_parameter("puddle_wetness")), 0.0)
	assert_true(
		material.get_shader_parameter("cracked_albedo") is Texture2D, "crust needs the crack plate"
	)
	view.free()
	sky.free()


func test_fair_dust_hides_puddles_and_rain_shows_water() -> void:
	assert_false(MapView3D.puddle_layer_visible(0.0, 0.0), "fresh dry map shows no basins")
	assert_false(
		MapView3D.puddle_layer_visible(0.0, SkyWeather.DRYNESS_FAIR_CAP),
		"a fair spell dusts the ground but never cracks it"
	)
	assert_true(MapView3D.puddle_layer_visible(0.0, 0.9), "drought crust")
	assert_true(MapView3D.puddle_layer_visible(0.3, 0.0), "standing water")


func _view_with_puddles(sky) -> MapView3D:
	var view := MapView3D.new()
	var scatter := Node3D.new()
	scatter.name = "Scatter"
	view.add_child(scatter)
	var chunk := Node3D.new()
	chunk.name = "Chunk"
	scatter.add_child(chunk)
	var puddles := Node3D.new()
	puddles.name = "Puddles"
	puddles.visible = false
	chunk.add_child(puddles)
	view._scatter_root = scatter
	view._sky_weather = sky
	return view
