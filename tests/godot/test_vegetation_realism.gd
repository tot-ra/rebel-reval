extends "res://tests/godot/test_case.gd"


func test_grass_is_curved_rooted_and_bounded() -> void:
	var mesh := MapViewFoliageMeshes.grass_tuft_mesh()
	assert_true(mesh == MapViewFoliageMeshes.grass_tuft_mesh(), "tufts must share a cached mesh")
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	assert_true(vertices.size() / 3 <= 112, "fine grass must remain below 112 triangles per tuft")
	var heights: Dictionary = {}
	for i in vertices.size():
		heights[uvs[i].y] = true
		if uvs[i].y == 0.0:
			assert_true(
				absf(vertices[i].y) < 0.00001, "wind weight zero must coincide with planted roots"
			)
	assert_true(heights.size() >= 5, "blade bends require intermediate rings")
	_check_mesh(mesh)


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


func test_cover_rebuild_and_split_chunks_preserve_every_instance() -> void:
	var definition := LowerTownSliceDefinition.create()
	var grid := MapBuilder.build(definition)
	var fingerprint := grid.fingerprint()
	var whole := MapViewTerrainDetails.build_chunk(definition, grid, Rect2i(7, 73, 9, 14), true)
	var left := MapViewTerrainDetails.build_chunk(definition, grid, Rect2i(7, 73, 4, 14), true)
	var right := MapViewTerrainDetails.build_chunk(definition, grid, Rect2i(11, 73, 5, 14), true)
	var split := _instances(left)
	split.append_array(_instances(right))
	split.sort()
	assert_eq(_instances(whole), split, "chunk partition cannot change placement, tint or scale")
	assert_true(split.size() > 0)
	assert_true(split.size() <= 126 * 12, "near detail remains bounded per cell")
	assert_eq(
		grid.fingerprint(), fingerprint, "decorative detail must not mutate terrain semantics"
	)
	for part in [whole, left, right]:
		part.free()


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


func _instances(root: Node3D) -> Array[String]:
	var result: Array[String] = []
	var blocked := MapViewMeshBuilderPrimitives.building_cell_rects(
		LowerTownSliceDefinition.create()
	)
	for node: MultiMeshInstance3D in root.find_children("*", "MultiMeshInstance3D", true, false):
		assert_eq(node.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		var multi := node.multimesh
		for i in multi.instance_count:
			var transform := multi.get_instance_transform(i)
			var cell := Vector2i(floori(transform.origin.x), floori(transform.origin.z))
			# Dummy renderer discards MultiMesh buffers; the rendered suite verifies positions.
			if DisplayServer.get_name() != "headless":
				assert_false(
					MapViewMeshBuilderPrimitives.cell_blocked(cell, blocked),
					"cover must respect buildings: %s" % cell
				)
			result.append("%s:%s:%s" % [node.name, transform, multi.get_instance_color(i)])
	result.sort()
	return result


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
