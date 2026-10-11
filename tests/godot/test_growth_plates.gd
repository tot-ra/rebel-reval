extends "res://tests/godot/test_case.gd"

## R-1684: plates must reach roofs and blueprint bark without changing placement.
const WindMaterials := preload("res://scripts/map/view3d/map_view_wind_materials.gd")
const MOSS := preload("res://assets/materials/pbr/wall_growth/wall_moss_albedo.png")
const NORMAL := preload("res://assets/materials/pbr/wall_growth/wall_moss_normal.png")
const LICHEN := preload("res://assets/materials/pbr/wall_growth/wall_lichen.png")
const GROWTH := "res://scripts/city/city_growth_plates.gdshaderinc"


func test_city_roof_and_wall_defaults_share_existing_plates() -> void:
	CityBuildingBuilder.bind_ground(CityPlan.load_default())
	for shader: Shader in [
		CityBuildingBuilder.WALL_SHADER, CityBuildingBuilder.LIMEWASH_SHADER,
		CityBuildingBuilder.ROOF_SHADER, CityBuildingBuilder.TILE_ROOF_SHADER,
	]:
		assert_eq(shader.get_default_texture_parameter("moss_tex"), MOSS)
		assert_eq(shader.get_default_texture_parameter("moss_normal_tex"), NORMAL)
		assert_eq(shader.get_default_texture_parameter("lichen_tex"), LICHEN)
	for family: StringName in [&"shingle", &"tile", &"thatch"]:
		var mat := CityBuildingBuilder.roof_material(family) as ShaderMaterial
		var expected: float = {&"shingle": 0.5, &"tile": 0.3, &"thatch": 0.2}[family]
		assert_almost_eq(float(mat.get_shader_parameter("moss")), expected, 0.0001)


func test_blueprint_bark_binds_plates_without_city_initialization() -> void:
	WindMaterials.reset()
	var mat := WindMaterials.bark_plate_wind(&"grey", &"birch")
	assert_eq(mat.get_shader_parameter("moss_tex"), MOSS)
	assert_eq(mat.get_shader_parameter("moss_normal_tex"), NORMAL)
	assert_eq(mat.get_shader_parameter("lichen_tex"), LICHEN)
	assert_eq(WindMaterials.bark_plate_wind(&"grey", &"birch"), mat)
	WindMaterials.reset()
	var recreated := WindMaterials.bark_plate_wind(&"grey", &"birch")
	assert_eq(recreated.get_shader_parameter("moss_tex"), MOSS)
	assert_eq(recreated.get_shader_parameter("lichen_tex"), LICHEN)


func test_growth_fallback_and_zero_coverage_contract() -> void:
	var code := FileAccess.get_file_as_string(GROWTH)
	assert_eq(code.count("hint_default_transparent"), 4, "missing albedo plates stay clean")
	assert_true(code.contains("step(0.0001, cover) * step(0.0001, height)"),
		"zero cover and transparent plates cannot grow even at threshold edges")
	assert_true(code.contains("nb.xy = transpose(rotation) * nb.xy"),
		"rotated normal plate must be expressed in the original tangent frame")
	assert_true(code.contains("rough = mix(rough, 0.97, moss)"))
	assert_true(code.contains("rough = mix(rough, 0.95, lichen)"))


func test_ecological_masks_remain_in_the_surface_shaders() -> void:
	var bark := FileAccess.get_file_as_string(
		"res://scripts/map/view3d/map_view_bark_wind.gdshader")
	for fragment: String in [
		"moss_amount * smoothstep(0.25, 0.75, bark_seed)",
		"mix(0.25, 2.6, north) * tree_moss",
		"bole * step(0.001, tree_moss)", "lichen_amount * smoothstep(0.15, 0.6",
		"UV * 0.55 + bark_seed", "NORMAL_MAP = nm",
	]:
		assert_true(bark.contains(fragment), "bark coverage contract: %s" % fragment)
	var roof := FileAccess.get_file_as_string("res://scripts/city/city_weathered_roof.gdshader")
	assert_true(roof.contains("patch + north * 0.2) * moss * age"))
	var tile := FileAccess.get_file_as_string("res://scripts/city/city_tile_roof.gdshader")
	assert_true(tile.contains("patch + north * 0.25) * wet_spot * moss * age"))
	assert_true(tile.contains("(1.0 - monk) * 0.6 + smoothstep(0.75, 1.0, cv) * 0.4"))
	assert_true(tile.contains("wnoise(uv * 9.0 + course)) * monk"))
