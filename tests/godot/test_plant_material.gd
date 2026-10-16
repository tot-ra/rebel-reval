extends "res://tests/godot/test_case.gd"
## R-2131: the plant globals are registered and the shared include compiles in the forb shader.


func test_plant_globals_registered() -> void:
	# global_shader_parameter_get is editor-only; a set on an unregistered name would error.
	var names := ProjectSettings.get_setting("shader_globals/plant_weather_g", {}) as Dictionary
	assert_eq(names.get("type", ""), "vec4", "plant_weather_g registered as vec4")
	var season := ProjectSettings.get_setting("shader_globals/plant_season_g", {}) as Dictionary
	assert_eq(season.get("type", ""), "vec4", "plant_season_g registered as vec4")
	PlantMaterial.set_weather(0.5, 0.2, 0.0, 0.0)
	PlantMaterial.set_weather(0.0, 0.0, 0.0, 0.0)


func test_forb_shader_uses_include() -> void:
	var shader := load("res://scripts/city/city_forb.gdshader") as Shader
	assert_true(shader != null, "forb shader loads")
	assert_true(shader.code.contains("plant_common.gdshaderinc"), "forb shader includes plant_common")
