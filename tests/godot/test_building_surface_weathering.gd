extends "res://tests/godot/test_case.gd"

## P0-053: ordinary houses must not share one baked wall/roof albedo map.


func test_adjacent_houses_get_distinct_wall_textures() -> void:
	MapViewMaterials.reset()
	var size := Vector3(4.0, 3.0, 5.0)
	var color := Color8(180, 157, 119)
	var wall_a := MapViewMaterials.wall_surface_for_building(&"house.alpha", &"plaster", color, size)
	var wall_b := MapViewMaterials.wall_surface_for_building(&"house.beta", &"plaster", color, size)
	assert_true(
		wall_a.albedo_texture != wall_b.albedo_texture,
		"adjacent plaster houses must not share an identical pattern texture"
	)


func test_weathering_variant_is_deterministic_per_building() -> void:
	var first := MapViewMaterials.surface_weathering_variant(&"brewery_yard")
	var second := MapViewMaterials.surface_weathering_variant(&"brewery_yard")
	assert_eq(first, second, "weathering band must be stable for one building ID")
	assert_true(
		MapViewMaterials.BUILDING_WEATHER_VARIANTS.has(first),
		"weathering band must be one of the documented variants"
	)


func test_weathering_variants_change_pattern_grayscale() -> void:
	MapViewMaterials.reset()
	var seed := 9042
	var fresh := MapViewMaterialPatterns.pattern_texture_weathered(
		MapViewMaterials.PATTERN_PLASTER,
		seed,
		MapViewMaterials.WEATHER_FRESH
	).get_image()
	var worn := MapViewMaterialPatterns.pattern_texture_weathered(
		MapViewMaterials.PATTERN_PLASTER,
		seed,
		MapViewMaterials.WEATHER_WORN
	).get_image()
	assert_ne(
		fresh.get_pixel(8, 8).r,
		worn.get_pixel(8, 8).r,
		"worn plaster must diverge from the fresh baseline"
	)


func test_lower_town_houses_emit_weathered_wall_materials() -> void:
	const LowerTownSlice := preload(
		"res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd"
	)
	const MapViewMeshBuilder := preload("res://scripts/map/view3d/map_view_mesh_builder.gd")

	MapViewMaterials.reset()
	var definition := LowerTownSlice.create()
	var textures: Dictionary = {}
	for building in definition.buildings:
		if building.get("kind", &"") != MapTypes.BUILDING_KIND_HOUSE:
			continue
		var node := MapViewMeshBuilder.build_building(building, definition.cell_size)
		var walls := node.get_node_or_null("Walls") as MeshInstance3D
		if walls == null:
			node.free()
			continue
		var material := walls.material_override as StandardMaterial3D
		assert_true(material != null, "%s: house walls need a material override" % building["id"])
		var texture := material.albedo_texture
		assert_false(
			textures.has(texture),
			"%s: must not reuse another house's wall texture" % building["id"]
		)
		textures[texture] = building["id"]
		node.free()

	assert_true(textures.size() >= 3, "Lower Town slice must expose multiple distinct house wall textures")
