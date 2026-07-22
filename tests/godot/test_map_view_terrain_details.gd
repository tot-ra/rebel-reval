extends "res://tests/godot/map_view_3d_test_base.gd"

## Cobblestone stays part of the continuous terrain surface in every camera mode;
## first-person chunk detail is reserved for genuinely silhouette-bearing plants.


func test_cobblestone_never_builds_per_stone_geometry() -> void:
	var definition := LowerTownSlice.create()
	var grid := MapBuilder.build(definition)
	var bounds := Rect2i(Vector2i(0, 51), Vector2i(4, 2))
	for first_person in [false, true]:
		var chunk := MapViewTerrainDetails.build_chunk(definition, grid, bounds, first_person)
		assert_eq(
			chunk.find_children("Cobbles", "MultiMeshInstance3D", true, false).size(),
			0,
			"paving must remain one terrain mesh instead of per-stone instances"
		)
		chunk.free()


func test_cobblestone_surface_texture_is_dense_earth_filled_and_shallow() -> void:
	var image := MapViewMaterialPatterns.cobble_surface_texture(8219).get_image()
	var stone_pixels := 0
	var joint_pixels := 0
	var strongest_slope := 0.0
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.b > 0.5:
				stone_pixels += 1
			else:
				joint_pixels += 1
			var normal_xy := Vector2(pixel.r, pixel.g) * 2.0 - Vector2.ONE
			strongest_slope = maxf(strongest_slope, normal_xy.length())
	var coverage := float(stone_pixels) / float(stone_pixels + joint_pixels)
	assert_true(coverage > 0.78, "stones need tight packing with only narrow earth joints")
	assert_true(coverage < 0.96, "compacted ground must remain visible between stones")
	assert_true(strongest_slope < 0.4, "normal relief must keep paving visibly embedded, not pillow-like")


func test_top_down_detail_root_stays_geometry_free() -> void:
	var definition := LowerTownSlice.create()
	var grid := MapBuilder.build(definition)
	var chunk := MapViewTerrainDetails.build_chunk(
		definition,
		grid,
		Rect2i(Vector2i(59, 112), Vector2i(2, 2))
	)
	assert_true(chunk.get_node_or_null("TopDown") != null)
	assert_eq(chunk.find_children("*", "GeometryInstance3D", true, false).size(), 0)
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
	assert_true(first_person_roots.size() > 0, "first-person must build nearby vegetation detail roots")
	assert_eq(view.find_children("Cobbles", "MultiMeshInstance3D", true, false).size(), 0)
	assert_eq(view.find_children("TopDown", "Node3D", true, false).size(), 0)
	view.set_terrain_detail_for_first_person(false)
	assert_false(view.uses_first_person_terrain_detail())
	assert_eq(view.find_children("FirstPerson", "Node3D", true, false).size(), 0)
	view.free()
