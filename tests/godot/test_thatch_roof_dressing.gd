extends "res://tests/godot/map_view_3d_test_base.gd"

## Reed/straw thatch roofs must read as layered coastal reed, not soft hay
## terrain, and wear soft ridge/eaves dressing instead of timber ridge boards.


func test_thatch_roofs_use_reed_pattern_and_soft_dressing() -> void:
	MapViewMaterials.reset()
	var thatch_mat := MapViewMaterials.roof_surface(&"thatch", MapViewMeshBuilderConfig.THATCH_TONE)
	var hay_mat := MapViewMaterials.role(&"hay")
	assert_true(
		thatch_mat.albedo_texture != hay_mat.albedo_texture,
		"thatch roofs must not reuse the soft hay/terrain straw pattern"
	)
	var thatch_uv := MapViewMaterials.building_uv_scale(
		MapViewMaterials.PATTERN_THATCH,
		MapViewMaterials.BUILDING_UV_REFERENCE_SIZE
	)
	assert_true(
		MapViewMaterials.BUILDING_UV_SCALE[MapViewMaterials.PATTERN_THATCH].y
			> MapViewMaterials.BUILDING_UV_SCALE[MapViewMaterials.PATTERN_STRAW].y,
		"thatch courses need denser along-slope UV repeats than field straw"
	)
	var definition := LowerTownSlice.create()
	var checked := 0
	for building in definition.buildings:
		if building.get("roof_material", &"") != &"thatch":
			continue
		var node := MapViewMeshBuilder.build_building(building, definition.cell_size)
		assert_true(node.has_node("ThatchRidge"), "%s: thatch needs a reed ridge roll" % building["id"])
		assert_true(
			node.has_node("ThatchEavesFringe_-1") or node.has_node("ThatchEavesFringe_1"),
			"%s: thatch needs an eaves fringe" % building["id"]
		)
		assert_false(node.has_node("RidgeBoard"), "%s: thatch must drop the timber ridge board" % building["id"])
		var roof := node.get_node("Roof") as MeshInstance3D
		var roof_mat := roof.material_override as StandardMaterial3D
		assert_true(roof_mat != null, "%s: thatch roof needs a material" % building["id"])
		assert_true(
			roof_mat.uv1_scale.is_equal_approx(thatch_uv),
			"%s: thatch roof must use the layered reed UV density" % building["id"]
		)
		checked += 1
		node.free()
		if checked >= 3:
			break
	assert_true(checked >= 3, "Lower Town slice must expose authored thatch roofs for this check")
