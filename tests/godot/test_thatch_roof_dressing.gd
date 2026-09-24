extends "res://tests/godot/map_view_3d_test_base.gd"

## Reed/straw thatch uses a thick packed shell plus overlapping bundle courses.
## Gable ends expose recessed timber infill and framing instead of flat thatch
## triangles or the former cylinder rolls that projected like purposeless poles.


func test_thatch_roofs_use_slope_reeds_and_framed_gables() -> void:
	MapViewMaterials.reset()
	var thatch_mat := MapViewMaterials.roof_surface(&"thatch", MapViewMeshBuilderConfig.THATCH_TONE)
	var hay_mat := MapViewMaterials.role(&"hay")
	assert_true(
		thatch_mat.albedo_texture != hay_mat.albedo_texture,
		"thatch roofs must not reuse the soft hay/terrain straw pattern"
	)
	var thatch_box_uv := MapViewMaterials.building_uv_scale(
		MapViewMaterials.PATTERN_THATCH,
		MapViewMaterials.BUILDING_UV_REFERENCE_SIZE
	)
	var thatch_world_uv := MapViewMaterials.roof_cover_world_density(
		MapViewMaterials.PATTERN_THATCH
	)
	assert_true(
		MapViewMaterials.BUILDING_UV_SCALE[MapViewMaterials.PATTERN_THATCH].y
			> MapViewMaterials.BUILDING_UV_SCALE[MapViewMaterials.PATTERN_STRAW].y,
		"thatch courses need denser along-slope UV repeats than field straw"
	)
	assert_true(
		MapViewMeshBuilderConfig.THATCH_ROOF_PITCH >= 1.0,
		"Baltic thatch needs a rain- and snow-shedding pitch of at least 45 degrees"
	)
	assert_true(
		MapViewMeshBuilderConfig.THATCH_COVER_THICKNESS >= 0.25,
		"Estonian thatch must keep its documented circa 10-inch packed depth"
	)
	assert_true(
		MapViewMeshBuilderConfig.THATCH_ROOF_OVERHANG > MapViewMeshBuilderConfig.ROOF_OVERHANG,
		"thatch needs deeper protective eaves than tile or shingle"
	)

	var definition := LowerTownSlice.create()
	var checked := 0
	for building in definition.buildings:
		if building.get("roof_material", &"") != &"thatch":
			continue
		var node := MapViewMeshBuilder.build_building(building, definition.cell_size)
		var house_id: String = building["id"]
		assert_true(node.has_node("ThatchRidge"), "%s: thatch needs a flush reed ridge" % house_id)
		assert_true(
			node.has_node("ThatchEavesFringe_-1"),
			"%s: thatch needs relief on the first slope" % house_id
		)
		assert_true(
			node.has_node("ThatchEavesFringe_1"),
			"%s: thatch needs relief on the second slope" % house_id
		)
		assert_true(
			node.has_node("ThatchGableInfill"),
			"%s: thatch needs recessed timber gable infill" % house_id
		)
		assert_true(
			node.has_node("ThatchGableTieBeam_-1"),
			"%s: thatch gables need a structural tie beam" % house_id
		)
		assert_true(
			node.has_node("ThatchGableKingPost_1"),
			"%s: thatch gables need a king post" % house_id
		)
		assert_true(
			node.has_node("ThatchVergeBoard_-1_-1"),
			"%s: thatch gables need flat verge boards" % house_id
		)
		assert_false(
			node.has_node("ThatchEdge_-1_-1"),
			"%s: thatch must not emit pole-like cylinder edges" % house_id
		)
		assert_false(
			node.has_node("RidgeBoard"), "%s: thatch must drop the timber ridge board" % house_id
		)

		var roof := node.get_node("Roof") as MeshInstance3D
		var roof_mat := roof.material_override as StandardMaterial3D
		assert_true(roof_mat != null, "%s: thatch roof needs a material" % house_id)
		assert_true(
			roof_mat.uv1_scale.is_equal_approx(thatch_world_uv),
			"%s: thatch roof must use world-unit reed density" % house_id
		)
		var ridge := node.get_node("ThatchRidge") as MeshInstance3D
		var ridge_mat := ridge.material_override as StandardMaterial3D
		assert_true(
			ridge_mat.uv1_scale.is_equal_approx(thatch_box_uv),
			"%s: thatch ridge keeps the 0-1 plate scale" % house_id
		)
		var fringe := node.get_node("ThatchEavesFringe_-1") as MeshInstance3D
		var fringe_mat := fringe.material_override as StandardMaterial3D
		assert_true(
			fringe_mat.uv1_scale.is_equal_approx(thatch_box_uv),
			"%s: thatch eaves keep the 0-1 plate scale" % house_id
		)
		# Open thatch roofs contain only the two slope quads. Their front/back
		# triangles are replaced by the separate wooden gable mesh.
		assert_eq(
			roof.mesh.get_faces().size(),
			12,
			"%s: thatch base roof must leave its gables open" % house_id
		)

		var along_ridge_x := MapViewMeshBuilderBuildingFacade.ridge_along_x(
			building,
			building["footprint"].size * MapViewBridge.world_scale(definition.cell_size)
		)
		var ridge_direction := Vector3.RIGHT if along_ridge_x else Vector3.FORWARD
		for side in [-1, 1]:
			var relief := node.get_node("ThatchEavesFringe_%d" % side) as MeshInstance3D
			assert_true(
				relief.mesh is ArrayMesh,
				"%s: each slope must be one merged packed-thatch mesh" % house_id
			)
			assert_true(
				float(relief.get_meta("cover_thickness", 0.0)) >= 0.25,
				"%s: each slope needs a visibly thick packed cover" % house_id
			)
			assert_true(
				int(relief.get_meta("course_count", 0)) >= 4,
				"%s: each slope needs several overlapping reed courses" % house_id
			)
			assert_true(
				int(relief.get_meta("stem_count", 0)) >= 48,
				"%s: each slope needs a dense mass of reed bundles" % house_id
			)
			var stem_direction: Vector3 = relief.get_meta("stem_direction", Vector3.ZERO)
			assert_true(
				stem_direction.y < -0.6,
				"%s: stems must descend from ridge to eave" % house_id
			)
			assert_true(
				absf(stem_direction.dot(ridge_direction)) < 0.01,
				"%s: stems must cross the ridge, not run lengthwise along it" % house_id
			)
		checked += 1
		node.free()
		if checked >= 3:
			break
	assert_true(checked >= 3, "Lower Town slice must expose authored thatch roofs for this check")
