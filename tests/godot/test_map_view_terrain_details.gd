extends "res://tests/godot/map_view_3d_test_base.gd"

## Camera-dependent paving detail: packed cobbles and first-person LOD toggle.


func test_cobble_road_packs_multiple_stones_per_cell() -> void:
	var mesh := MapViewTerrainDetails.cobble_mesh()
	assert_true(mesh.get_surface_count() > 0, "cobble mesh must be generated geometry")
	var definition := LowerTownSlice.create()
	var grid := MapBuilder.build(definition)
	var chunk := MapViewTerrainDetails.build_chunk(
		definition,
		grid,
		Rect2i(Vector2i(59, 112), Vector2i(2, 2))
	)
	var top_down := chunk.get_node("TopDown/Cobbles") as MultiMeshInstance3D
	assert_true(top_down != null, "paving cells need a batched cobble layer")
	var expected := (
		MapViewMeshBuilderConfig.TOP_DOWN_COBBLE_GRID.x
		* MapViewMeshBuilderConfig.TOP_DOWN_COBBLE_GRID.y
		* 4
	)
	assert_eq(
		top_down.multimesh.instance_count,
		expected,
		"top-down cobbles must tile every paving cell in the chunk bounds"
	)
	chunk.free()


func test_first_person_swaps_to_denser_packed_cobbles() -> void:
	var definition := LowerTownSlice.create()
	var grid := MapBuilder.build(definition)
	var chunk := MapViewTerrainDetails.build_chunk(
		definition,
		grid,
		Rect2i(Vector2i(0, 51), Vector2i(4, 2))
	)
	var top_down := chunk.get_node("TopDown") as Node3D
	var first_person := chunk.get_node("FirstPerson") as Node3D
	assert_true(top_down.visible, "top-down detail starts visible")
	assert_false(first_person.visible, "first-person detail starts hidden")
	MapViewTerrainDetails.set_first_person(chunk, true)
	assert_false(top_down.visible)
	assert_true(first_person.visible)
	var fp_cobbles := first_person.get_node("Cobbles") as MultiMeshInstance3D
	var td_cobbles := top_down.get_node("Cobbles") as MultiMeshInstance3D
	assert_true(
		fp_cobbles.multimesh.instance_count > td_cobbles.multimesh.instance_count,
		"first-person paving should carry more packed stones than top-down"
	)
	chunk.free()


func test_runtime_camera_toggle_switches_terrain_detail_lod() -> void:
	var definition := LowerTownSlice.create()
	var view := MapView3D.create(definition, MapBuilder.build(definition))
	view.activate_all_chunks()
	assert_false(view.uses_first_person_terrain_detail())
	view.set_terrain_detail_for_first_person(true)
	assert_true(view.uses_first_person_terrain_detail())
	view.set_terrain_detail_for_first_person(false)
	assert_false(view.uses_first_person_terrain_detail())
	view.free()
