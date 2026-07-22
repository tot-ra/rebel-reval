extends "res://tests/godot/map_view_3d_test_base.gd"

## Camera-dependent city terrain detail: dense Tallinn paving near eye level,
## material-only top-down rendering, and bounded runtime generation.


func test_cobble_mesh_is_rounded_rectangular_and_within_triangle_budget() -> void:
	var mesh := MapViewTerrainDetails.cobble_mesh()
	assert_true(mesh.get_surface_count() > 0, "cobble mesh must be generated geometry")
	var vertices := mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var triangles := vertices.size() / 3
	var stones_per_cell := (
		MapViewMeshBuilderConfig.FIRST_PERSON_COBBLE_GRID.x
		* MapViewMeshBuilderConfig.FIRST_PERSON_COBBLE_GRID.y
	)
	assert_true(MapViewTerrainDetails.COBBLE_LENGTH > MapViewTerrainDetails.COBBLE_WIDTH)
	assert_true(MapViewTerrainDetails.COBBLE_RADIUS > 0.0, "corners must stay rounded")
	assert_true(MapViewTerrainDetails.COBBLE_HEIGHT > 0.05, "street-level stones need visible relief")
	assert_true(
		triangles * stones_per_cell
		<= MapViewMeshBuilderConfig.FIRST_PERSON_COBBLE_TRIANGLE_BUDGET_PER_CELL,
		"denser paving must stay inside the per-cell triangle budget"
	)


func test_top_down_uses_material_instead_of_hidden_cobble_instances() -> void:
	var definition := LowerTownSlice.create()
	var grid := MapBuilder.build(definition)
	var chunk := MapViewTerrainDetails.build_chunk(
		definition,
		grid,
		Rect2i(Vector2i(59, 112), Vector2i(2, 2))
	)
	assert_true(chunk.get_node_or_null("TopDown") != null)
	assert_true(
		chunk.get_node_or_null("TopDown/Cobbles") == null,
		"top-down must rely on the seamless material, not duplicate cobble geometry"
	)
	chunk.free()


func test_first_person_packs_narrow_running_bond_joints() -> void:
	var definition := LowerTownSlice.create()
	var grid := MapBuilder.build(definition)
	var cell_count := 8
	var chunk := MapViewTerrainDetails.build_chunk(
		definition,
		grid,
		Rect2i(Vector2i(0, 51), Vector2i(4, 2)),
		true
	)
	var cobbles := chunk.get_node("FirstPerson/Cobbles") as MultiMeshInstance3D
	var grid_size := MapViewMeshBuilderConfig.FIRST_PERSON_COBBLE_GRID
	assert_eq(cobbles.multimesh.instance_count, grid_size.x * grid_size.y * cell_count)
	var length_joint := 1.0 / float(grid_size.x) - MapViewTerrainDetails.COBBLE_LENGTH
	var course_joint := 1.0 / float(grid_size.y) - MapViewTerrainDetails.COBBLE_WIDTH
	assert_true(length_joint >= 0.0 and length_joint <= 0.02, "stone ends need narrow mortar joints")
	assert_true(course_joint >= 0.0 and course_joint <= 0.02, "courses must no longer have broad gutters")
	assert_eq(cobbles.visibility_range_end, MapViewMeshBuilderConfig.FIRST_PERSON_DETAIL_RANGE)
	assert_true(
		float(grid_size.x * grid_size.y)
		* pow(MapViewMeshBuilderConfig.FIRST_PERSON_DETAIL_RANGE, 2.0)
		<= MapViewMeshBuilderConfig.FIRST_PERSON_COBBLE_INSTANCE_AREA_BUDGET,
		"density and culling range must stay within the previous weighted instance budget"
	)
	chunk.free()


func test_first_person_ground_cover_has_distinct_vegetation_families() -> void:
	var definition := LowerTownSlice.create()
	var grid := MapBuilder.build(definition)
	var chunk := MapViewTerrainDetails.build_chunk(
		definition,
		grid,
		Rect2i(Vector2i(7, 73), Vector2i(9, 14)),
		true
	)
	var detail := chunk.get_node("FirstPerson") as Node3D
	var present := 0
	for layer_name in ["MeadowGrass", "DryGrass", "Clover", "Ferns"]:
		if detail.get_node_or_null(layer_name) != null:
			present += 1
	assert_true(present >= 3, "grass terrain needs multiple non-flat vegetation silhouettes")
	chunk.free()


func test_runtime_camera_toggle_builds_only_selected_lod() -> void:
	var definition := LowerTownSlice.create()
	var view := MapView3D.create(definition, MapBuilder.build(definition))
	assert_false(view.uses_first_person_terrain_detail())
	view.set_terrain_detail_for_first_person(true)
	view.update_terrain_detail_focus(Vector3(60.0, 1.65, 114.0))
	assert_true(view.uses_first_person_terrain_detail())
	var first_person_roots := view.find_children("FirstPerson", "Node3D", true, false)
	assert_true(first_person_roots.size() > 0, "first-person must build nearby detail")
	assert_eq(view.find_children("TopDown", "Node3D", true, false).size(), 0)
	view.set_terrain_detail_for_first_person(false)
	assert_false(view.uses_first_person_terrain_detail())
	assert_eq(view.find_children("FirstPerson", "Node3D", true, false).size(), 0)
	view.free()
