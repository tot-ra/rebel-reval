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


func test_wall_surface_families_keep_distinct_pattern_identity() -> void:
	MapViewMaterials.reset()
	var color := Color8(180, 157, 119)
	var size := Vector3(4.0, 3.0, 5.0)
	var families: Array[StringName] = [&"log", &"plank", &"plaster", &"limestone"]
	var textures: Dictionary = {}
	for family in families:
		var material := MapViewMaterials.wall_surface_for_building(
			StringName("family.%s" % String(family)),
			family,
			color,
			size
		)
		assert_true(material.albedo_texture != null, "%s walls need a procedural pattern" % family)
		textures[material.albedo_texture] = family
	assert_eq(
		textures.size(),
		families.size(),
		"log, plank, plaster, and limestone must resolve to distinct shared patterns"
	)


func test_roof_surface_families_keep_distinct_pattern_identity() -> void:
	MapViewMaterials.reset()
	var families: Array[StringName] = [&"tile", &"shingle", &"thatch"]
	var textures: Dictionary = {}
	for family in families:
		var material := MapViewMaterials.roof_surface_for_building(
			StringName("roof.%s" % String(family)),
			family,
			Color8(112, 83, 56)
		)
		assert_true(material.albedo_texture != null, "%s roofs need a procedural pattern" % family)
		textures[material.albedo_texture] = family
	assert_eq(
		textures.size(),
		families.size(),
		"tile, shingle, and thatch must resolve to distinct shared patterns"
	)


func test_weathering_variant_is_deterministic_per_building() -> void:
	var first := MapViewMaterials.surface_weathering_variant(&"brewery_yard")
	var second := MapViewMaterials.surface_weathering_variant(&"brewery_yard")
	assert_eq(first, second, "weathering band must be stable for one building ID")
	assert_true(
		MapViewMaterials.BUILDING_WEATHER_VARIANTS.has(first),
		"weathering band must be one of the documented variants"
	)


func test_all_weathering_variants_change_the_shared_pattern() -> void:
	var seed := 9042
	var fresh := MapViewMaterialPatterns.pattern_texture_weathered(
		MapViewMaterials.PATTERN_PLASTER,
		seed,
		MapViewMaterials.WEATHER_FRESH
	).get_image()
	for weathering in MapViewMaterials.BUILDING_WEATHER_VARIANTS:
		var image := MapViewMaterialPatterns.pattern_texture_weathered(
			MapViewMaterials.PATTERN_PLASTER,
			seed,
			weathering
		).get_image()
		if weathering == MapViewMaterials.WEATHER_FRESH:
			assert_eq(_mean_abs_delta(fresh, image), 0.0)
		else:
			assert_true(
				_mean_abs_delta(fresh, image) > 0.0,
				"%s state must be visible in the shared material" % weathering
			)


func _mean_abs_delta(first: Image, second: Image) -> float:
	var total := 0.0
	for y in first.get_height():
		for x in first.get_width():
			total += absf(first.get_pixel(x, y).r - second.get_pixel(x, y).r)
	return total / float(first.get_width() * first.get_height())


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
