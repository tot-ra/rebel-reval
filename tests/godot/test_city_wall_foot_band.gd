extends "res://tests/godot/test_case.gd"

## R-1931: the wall side of the wall foot. Every outdoor wall family runs the
## shared `wall_foot()` band measured from the local street (heightfield), and
## timber walls rot at the foot. Shaders do not compile under the headless
## dummy renderer, so the wiring is checked on materials and shader sources.

const WEATHERING := "res://scripts/city/city_weathering.gdshaderinc"


func before_each() -> void:
	super.before_each()
	CityBuildingBuilder.bind_ground(CityPlan.load_default())


func test_timber_walls_rot_and_stone_does_not() -> void:
	for family: StringName in [&"plank", &"log"]:
		var mat := CityBuildingBuilder.wall_material(family) as ShaderMaterial
		assert_eq(mat.get_shader_parameter("rot"), 1.0, "%s wall rots at the foot" % family)
	for family: StringName in [&"limestone", &"plaster"]:
		var mat := CityBuildingBuilder.wall_material(family) as ShaderMaterial
		assert_eq(mat.get_shader_parameter("rot"), 0.0, "%s wall does not rot" % family)


func test_walls_are_bound_to_the_local_ground() -> void:
	var walls := [
		CityBuildingBuilder.wall_material(&"plank") as ShaderMaterial,
		CityBuildingBuilder.outdoor_limewash_material() as ShaderMaterial,
	]
	for mat: ShaderMaterial in walls:
		assert_true(
			mat.get_shader_parameter("ground_height") is Texture2D,
			"%s reads the city heightfield" % mat.shader.resource_path
		)
		assert_ne(mat.get_shader_parameter("ground_rect"), Vector4(0, 0, 1, 1), "rect bound")
	var render := CityBuildingBuilder.outdoor_limewash_material() as ShaderMaterial
	assert_true(render.get_shader_parameter("outdoor"), "render is the outdoor wash")
	assert_eq(CitySiteKit.material_for("render"), render, "site kits share the bound render")


func test_every_wall_family_runs_the_shared_band() -> void:
	var inc := FileAccess.get_file_as_string(WEATHERING)
	assert_true(inc.contains("float wall_foot("), "one shared helper")
	for path: String in [
		"res://scripts/city/city_weathered_wall.gdshader",
		"res://scripts/city/city_limewash.gdshader",
	]:
		var src := FileAccess.get_file_as_string(path)
		assert_true(src.contains("wall_foot(col, rough, w_pos, w_nrm, above"), "%s calls it" % path)
		assert_true(src.contains("ground_at(w_pos.xz)"), "%s measures from local ground" % path)
