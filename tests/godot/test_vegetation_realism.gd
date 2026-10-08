extends "res://tests/godot/test_case.gd"


func test_grass_is_curved_rooted_and_bounded() -> void:
	var mesh := MapViewFoliageMeshes.grass_tuft_mesh()
	assert_true(mesh == MapViewFoliageMeshes.grass_tuft_mesh(), "tufts must share a cached mesh")
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	assert_true(vertices.size() / 3 <= 112, "fine grass must remain below 112 triangles per tuft")
	var cells: Dictionary = {}
	for tag: Vector2 in arrays[Mesh.ARRAY_TEX_UV2]:
		assert_eq(tag.y, 1.0, "tuft cards must opt into atlas sampling")
		cells[tag.x] = true
	assert_eq(cells.size(), 4, "each card must show a different blade-atlas cluster")
	var heights: Dictionary = {}
	for i in vertices.size():
		heights[uvs[i].y] = true
		if uvs[i].y == 0.0:
			assert_true(
				absf(vertices[i].y) < 0.00001, "wind weight zero must coincide with planted roots"
			)
	assert_true(heights.size() >= 5, "blade bends require intermediate rings")
	_check_mesh(mesh)


func test_grass_material_samples_blade_atlas_with_alpha() -> void:
	var material := MapViewMaterials.grass_blades()
	var atlas := material.get_shader_parameter("blade_atlas") as Texture2D
	assert_true(atlas != null, "grass material must bind the R-1103 blade atlas")
	var image := atlas.get_image()
	assert_eq(image.get_width(), 1024)
	assert_true(image.detect_alpha() != Image.ALPHA_NONE, "atlas needs alpha cut-outs")
	var code := FileAccess.get_file_as_string("res://scripts/map/view3d/map_view_grass.gdshader")
	for token in ["blade_atlas", "ALPHA_SCISSOR_THRESHOLD", "root_tint", "v_dry"]:
		assert_true(code.contains(token), "grass shader must declare %s" % token)


func test_tree_geometry_is_deterministic_finite_and_within_budget() -> void:
	for species in MapViewTreeSpecies.ALL_SPECIES:
		var mesh := MapViewTreeMeshes.canopy_mesh(species)
		var count := mesh.surface_get_array_len(0) / 3
		assert_true(count <= 24000, "%s canopy exceeds 24K triangle cap" % species)
		assert_eq(int(MapViewTreeMeshes.geometry_stats(species)["canopy_triangles"]), count)
		var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var tags: PackedVector2Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]
		assert_eq(tags.size(), vertices.size(), "all leaves must opt into petiole wind")
		for tag in tags:
			assert_eq(tag.x, 1.0)
		MapViewTreeMeshes.reset_cache()
		assert_eq(
			MapViewTreeMeshes.canopy_mesh(species).surface_get_arrays(0)[Mesh.ARRAY_VERTEX],
			vertices,
			"rebuilding %s must preserve geometry" % species
		)
		_check_mesh(mesh)


func test_tree_cards_keep_cluster_attributes_and_species_tiles() -> void:
	var LeafGeometry := preload("res://scripts/map/view3d/map_view_leaf_geometry.gd")
	for species in MapViewTreeSpecies.ALL_SPECIES:
		var mesh := MapViewTreeMeshes.canopy_mesh(species)
		assert_eq(mesh.get_surface_count(), 1, "cards must not add a draw surface")
		var arrays := mesh.surface_get_arrays(0)
		var tags: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		var custom: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM0]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var seeds: Dictionary = {}
		var card_vertices := 0
		var anchor := Vector4.ZERO
		for i in tags.size():
			if tags[i].y < 0.5:
				continue
			var data := Vector4(custom[i * 4], custom[i * 4 + 1],
				custom[i * 4 + 2], custom[i * 4 + 3])
			if card_vertices % 12 == 0:
				anchor = data
				seeds[data.w] = true
			assert_eq(data, anchor, "all four triangles must collapse to one petiole")
			assert_true(data.is_finite() and data.w > 0.0 and data.w < 1.0)
			assert_true(colors[i].a >= 0.47 and colors[i].a <= 1.0)
			card_vertices += 1
		assert_eq(card_vertices, int(MapViewTreeMeshes.geometry_stats(species)["card_count"]) * 12)
		assert_true(card_vertices > 1200, "every species needs a layered card crown")
		assert_true(seeds.size() > 100, "clusters must not all shed at once")
		var material := MapViewMaterials.canopy_for_species(species)
		assert_eq(material.get_shader_parameter("atlas_tile"), LeafGeometry.card_tile(species))
		assert_eq(material.get_shader_parameter("atlas_grid"), Vector2(4, 2))
		var atlas := material.get_shader_parameter("leaf_atlas") as Texture2D
		assert_true(atlas != null)
		assert_eq(atlas.get_size(), Vector2(2048, 1024))
		assert_true(atlas.get_image().detect_alpha() != Image.ALPHA_NONE, "atlas needs cut-outs")
	var shader := MapViewMaterialShaders.CANOPY_SHADER.code
	assert_true(shader.contains("ALPHA_SCISSOR_THRESHOLD = card_scissor"))
	assert_false(shader.contains("leaf_atlas : source_color"),
		"relative brightness atlas is linear data, not sRGB albedo")


func test_patch_density_is_continuous_and_seeded() -> void:
	for x in range(-10, 30):
		var spot := Vector2(float(x) * 4.7, 7.4)
		var a := MapViewTerrainDetails.patch_density(spot - Vector2(0.001, 0), 42)
		var b := MapViewTerrainDetails.patch_density(spot + Vector2(0.001, 0), 42)
		assert_true(absf(a - b) < 0.002, "patches must not jump at noise-cell boundaries")
		assert_true(a >= 0.0 and a <= 1.0)
	assert_ne(
		MapViewTerrainDetails.patch_density(Vector2(3, 8), 42),
		MapViewTerrainDetails.patch_density(Vector2(3, 8), 43)
	)


func test_legacy_bushes_keep_height_weighted_wind() -> void:
	var mesh := MapViewBushMeshes.mesh_for(MapViewBushSpecies.ALL_SPECIES[0])
	var arrays := mesh.surface_get_arrays(0)
	assert_true(
		arrays[Mesh.ARRAY_TEX_UV2] == null, "legacy bushes must not be tagged as petiole leaves"
	)
	var code := MapViewMaterialShaders.CANOPY_SHADER.code
	assert_true(
		code.contains("UV2.x > 0.5 ? UV.y * UV.y : clamp(VERTEX.y"),
		"shared canopy material must retain bush height weighting without leaf UVs"
	)


func _check_mesh(mesh: ArrayMesh) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in range(0, vertices.size(), 3):
		var area := (vertices[i + 1] - vertices[i]).cross(vertices[i + 2] - vertices[i]).length()
		assert_true(area > 0.00000001, "leaves and tips must not emit degenerate triangles")
		var front := (
			(vertices[i + 2] - vertices[i]).cross(vertices[i + 1] - vertices[i]).normalized()
		)
		assert_true(front.dot(normals[i]) > 0.0, "normals must face Godot clockwise fronts")
	for i in vertices.size():
		assert_true(vertices[i].is_finite())
		assert_true(normals[i].is_finite() and normals[i].length() > 0.98)
