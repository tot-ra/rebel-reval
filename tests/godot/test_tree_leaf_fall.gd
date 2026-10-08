extends "res://tests/godot/test_case.gd"

## R-1187: melee strikes shake trees and knock leaves loose (presentation only).


func _tree_row(species: StringName, positions: Array[Vector3]) -> MultiMeshInstance3D:
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for position in positions:
		transforms.append(Transform3D(Basis(), position))
		colors.append(Color.WHITE)
	var instance := MapViewMeshBuilderPrimitives.multi_mesh(
		"Trees_Test",
		MapViewTreeMeshes.canopy_mesh(species),
		transforms,
		colors,
		MapViewMaterials.canopy_for_species(species),
		Vector3.ZERO,
		true
	)
	TreeLeafFall3D.tag_canopy(instance, species, transforms)
	return instance


func test_query_picks_nearest_tree_in_front_within_reach() -> void:
	var row := _tree_row(&"birch", [Vector3(1.0, 0, 0), Vector3(1.8, 0, 0), Vector3(-1.0, 0, 0)])
	var candidates: Array[Node] = [row]
	var hit := TreeLeafFall3D.find_struck_tree(candidates, Vector3.ZERO, Vector2.RIGHT, 1.2, 0.3)
	assert_false(hit.is_empty(), "a tree straight ahead in reach must be struck")
	assert_eq(int(hit["index"]), 0, "nearest tree wins")
	assert_eq(hit["species"], &"birch")
	assert_true(float(hit["crown_height"]) > 0.5)
	row.free()


func test_query_ignores_trees_behind_or_out_of_reach() -> void:
	var row := _tree_row(&"oak", [Vector3(-1.0, 0, 0), Vector3(4.0, 0, 0), Vector3(0, 0, 1.2)])
	var candidates: Array[Node] = [row]
	assert_true(
		TreeLeafFall3D.find_struck_tree(candidates, Vector3.ZERO, Vector2.RIGHT, 1.2, 0.3).is_empty(),
		"behind, far, and side trees must not be struck"
	)
	assert_true(
		TreeLeafFall3D.find_struck_tree(candidates, Vector3.ZERO, Vector2.ZERO, 1.2, 0.3).is_empty()
	)
	row.free()


func test_strike_shakes_crown_and_bursts_only_with_leaves() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var view := Node3D.new()
	tree.root.add_child(view)
	var row := _tree_row(&"maple", [Vector3(1.0, 0, 0)])
	view.add_child(row)
	var leaf_fall := TreeLeafFall3D.new()
	view.add_child(leaf_fall)
	var autumn := {"day": 5, "month": 10, "year": 1343}
	var hit := leaf_fall.strike(Vector3.ZERO, Vector2.RIGHT, 1.2, 0.3, 1.0, autumn)
	assert_false(hit.is_empty())
	assert_true(int(hit["leaves"]) > 0, "an autumn maple drops leaves")
	assert_eq(leaf_fall.active_shake_count(), 1)
	var winter := {"day": 10, "month": 1, "year": 1343}
	var bare := leaf_fall.strike(Vector3.ZERO, Vector2.RIGHT, 1.2, 0.3, 1.0, winter)
	assert_eq(int(bare["leaves"]), 0, "a bare winter tree drops nothing")
	assert_eq(leaf_fall.active_shake_count(), 1, "re-striking restarts the same shake")
	view.free()


func test_shake_rings_down_to_rest() -> void:
	var start := TreeLeafFall3D.shake_custom(Vector2.RIGHT, 1.0, 0.0)
	assert_true(start.r > 0.1, "first frame pushes the crown away from the blow")
	assert_true(start.b > 0.5, "leaves flutter on impact")
	var late := TreeLeafFall3D.shake_custom(Vector2.RIGHT, 1.0, 1.2)
	assert_true(Vector2(late.r, late.g).length() < Vector2(start.r, start.g).length() * 0.1)
	assert_eq(
		TreeLeafFall3D.shake_custom(Vector2.RIGHT, 1.0, TreeLeafFall3D.SHAKE_DURATION),
		Color(0, 0, 0, 0)
	)


func test_ambient_rate_follows_season_wind_and_trees() -> void:
	var october := {"day": 10, "month": 10, "year": 1343}
	var july := {"day": 10, "month": 7, "year": 1343}
	var january := {"day": 10, "month": 1, "year": 1343}
	assert_eq(TreeLeafFall3D.ambient_rate(&"birch", october, 0.3, 0), 0.0, "no trees, no leaves")
	assert_eq(TreeLeafFall3D.ambient_rate(&"birch", january, 1.0, 10), 0.0, "bare trees")
	assert_true(
		TreeLeafFall3D.ambient_rate(&"birch", october, 0.3, 10)
		> TreeLeafFall3D.ambient_rate(&"birch", july, 0.3, 10)
	)
	assert_true(
		TreeLeafFall3D.ambient_rate(&"birch", july, 0.95, 10)
		> TreeLeafFall3D.ambient_rate(&"birch", july, 0.2, 10),
		"storms shake summer leaves loose"
	)


func test_season_reaches_species_canopy_materials() -> void:
	var material := MapViewMaterials.canopy_for_species(&"birch")
	MapViewMaterials.apply_vegetation_season({"day": 15, "month": 1, "year": 1343})
	assert_eq(float(material.get_shader_parameter("leaf_density")), 0.0)
	MapViewMaterials.apply_vegetation_season({"day": 15, "month": 7, "year": 1343})
	assert_eq(float(material.get_shader_parameter("leaf_density")), 1.0)
	var fruit := MapViewMaterials.tree_fruit_for_species(&"apple")
	assert_eq(fruit.albedo_color.a, 0.0, "apples are not ripe in July")
	MapViewMaterials.apply_vegetation_season({"day": 15, "month": 9, "year": 1343})
	assert_eq(fruit.albedo_color.a, 1.0)
	MapViewMaterials.apply_vegetation_season(GameCalendar.DEFAULT_DATE)


func test_canopy_leaves_carry_seasonal_contract() -> void:
	var arrays := MapViewTreeMeshes.canopy_mesh(&"birch").surface_get_arrays(0)
	var custom: Variant = arrays[Mesh.ARRAY_CUSTOM0]
	assert_true(custom is PackedFloat32Array, "leaves must carry petiole + seed in CUSTOM0")
	var packed := custom as PackedFloat32Array
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_eq(packed.size(), vertices.size() * 4)
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var min_alpha := 1.0
	for i in vertices.size():
		var seed := packed[i * 4 + 3]
		assert_true(seed >= 0.0 and seed <= 1.0)
		min_alpha = minf(min_alpha, colors[i].a)
	assert_true(min_alpha < 0.8, "inner crown leaves are occluded")


func test_gust_leaf_rate_needs_leaves_trees_and_strong_local_wind() -> void:
	var july := {"day": 10, "month": 7, "year": 1343}
	var january := {"day": 10, "month": 1, "year": 1343}
	assert_eq(
		TreeLeafFall3D.gust_leaf_rate(&"birch", july, 0.5, 10), 0.0, "a breeze keeps its leaves"
	)
	assert_eq(
		TreeLeafFall3D.gust_leaf_rate(&"birch", january, 2.5, 10), 0.0, "bare trees shed nothing"
	)
	assert_eq(TreeLeafFall3D.gust_leaf_rate(&"birch", july, 2.5, 0), 0.0, "no trees, no leaves")
	assert_true(
		TreeLeafFall3D.gust_leaf_rate(&"birch", july, 2.5, 10)
		> TreeLeafFall3D.gust_leaf_rate(&"birch", july, 1.3, 10),
		"a storm front tears off more than a strong gust"
	)
