extends "res://tests/godot/test_case.gd"

## Trunks and branches sway with the crown; thin limbs carry more flex than the bole.


func test_wood_alpha_stores_limb_flexibility_thin_over_thick() -> void:
	var scale := CityVegetationBuilder.species_scale(&"oak", 1.0)
	var wood := MapViewTreeMeshes.city_wood_mesh(&"oak", scale, 0.6)
	var arrays := wood.surface_get_arrays(0)
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var min_flex := 1.0
	var max_flex := 0.0
	var low_flex_sum := 0.0
	var low_count := 0
	for i in colors.size():
		min_flex = minf(min_flex, colors[i].a)
		max_flex = maxf(max_flex, colors[i].a)
		if vertices[i].y < 0.3:
			low_flex_sum += colors[i].a
			low_count += 1
	assert_true(min_flex < 0.2, "trunk base is stiff (min %.2f)" % min_flex)
	assert_true(max_flex > 0.8, "twig tips are flexible (max %.2f)" % max_flex)
	assert_true(low_count > 0 and low_flex_sum / low_count < 0.3, "the bole near the ground is stiff")


func test_limb_flex_falls_with_radius() -> void:
	assert_true(MapViewTreeMeshes.limb_flex(0.003) > 0.99)
	assert_true(MapViewTreeMeshes.limb_flex(0.03) < MapViewTreeMeshes.limb_flex(0.01))
	assert_true(MapViewTreeMeshes.limb_flex(0.15) < 0.01)


func test_swaying_bark_material_uses_wind_shader_and_plate_textures() -> void:
	var material := MapViewMaterials.bark_plate_wind(&"grey")
	assert_true(material.shader != null)
	assert_true(material.get_shader_parameter("albedo_tex") != null, "plate albedo bound")
	assert_true(material.get_shader_parameter("normal_tex") != null, "plate normal bound")
	assert_eq(MapViewMaterials.bark_plate_wind(&"grey"), material, "cached per plate")
