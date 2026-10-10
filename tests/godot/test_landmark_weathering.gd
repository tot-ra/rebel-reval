extends "res://tests/godot/test_case.gd"

const Wear := preload("res://scripts/map/view3d/map_view_landmark_weathering.gd")
const Hall := preload("res://scripts/map/view3d/map_view_town_hall_model.gd")
const Materials := preload("res://scripts/map/view3d/map_view_building_materials.gd")
const Olaf := preload("res://scripts/map/view3d/map_view_st_olaf_model.gd")
const BUILDING := {"id": &"town_hall_mass", "primitive": &"town_hall_1343"}


func test_box_wear_preserves_legacy_geometry_and_random_sequence() -> void:
	var root := Node3D.new()
	var rng := _rng(123)
	var expected_rng := _rng(123)
	Wear.add_box_wear(root, rng, Vector2(26.0, 7.0), 5.0)
	var faces := [
		["N", 26.0, Vector3(0, 0, -3.5), PI],
		["S", 26.0, Vector3(0, 0, 3.5), 0.0],
		["E", 7.0, Vector3(13, 0, 0), PI * 0.5],
		["W", 7.0, Vector3(-13, 0, 0), -PI * 0.5],
	]
	for face: Array in faces:
		var span: float = face[1]
		var yaw: float = face[3]
		var normal := Vector3(sin(yaw), 0, cos(yaw))
		var base: Vector3 = face[2] + normal * 0.015
		var damp := root.get_node("TownHallDamp%s" % face[0]) as MeshInstance3D
		assert_eq(damp.position, base + Vector3(0, 1.37, 0))
		assert_eq((damp.mesh as QuadMesh).size, Vector2(span, 1.5))
		var count := int(span / 0.9)
		for index in count:
			var width := expected_rng.randf_range(0.25, 0.8)
			var length := expected_rng.randf_range(0.5, 2.1)
			var t := (float(index) + expected_rng.randf_range(0.2, 0.8)) / count - 0.5
			var strength := snappedf(expected_rng.randf_range(0.2, 0.4), 0.05)
			var node := root.get_node(
				"TownHallEaveStreak%s%02d" % [face[0], index]
			) as MeshInstance3D
			assert_eq((node.mesh as QuadMesh).size, Vector2(width, length))
			assert_eq(node.position, base + Vector3(cos(yaw), 0, -sin(yaw))
				* (t * span) + Vector3(0, 5.0 - length * 0.5, 0))
			assert_eq(node.material_override, Wear.grime_material(strength, true, true))
	assert_eq(root.get_child_count(), 74)
	assert_eq(rng.state, expected_rng.state)
	root.free()


func test_sill_legacy_offsets_keep_north_face_world_x_and_rng_order() -> void:
	var root := Node3D.new()
	var rng := _rng(456)
	var expected_rng := _rng(456)
	Wear.add_sill_streaks(root, rng, "Window", Vector3(4, 2, -3.5), 0.86, PI, true)
	for index in 3:
		var length := expected_rng.randf_range(0.5, 1.4)
		var x := 4.0 + (float(index) - 1) * 0.86 * 0.34
		x += expected_rng.randf_range(-0.06, 0.06)
		var width := expected_rng.randf_range(0.14, 0.3)
		var strength := snappedf(expected_rng.randf_range(0.35, 0.6), 0.05)
		var node := root.get_node("WindowStreak%d" % index) as MeshInstance3D
		assert_eq(node.position, Vector3(x, 2.0 - 0.12 - length * 0.5, -3.53))
		assert_eq((node.mesh as QuadMesh).size, Vector2(width, length))
		assert_eq(node.material_override, Wear.grime_material(strength, true, true))
	assert_eq(rng.state, expected_rng.state)
	root.free()


func test_sill_default_follows_the_face_tangent() -> void:
	var root := Node3D.new()
	Wear.add_sill_streaks(root, _rng(456), "Window", Vector3(4, 2, 0), 1, PI * 0.5)
	for node: MeshInstance3D in root.get_children():
		assert_almost_eq(node.position.x, 4.03, 0.00001)
	root.free()


func test_grime_cache_keys_fades_and_shadow_policy() -> void:
	var top := Wear.grime_material(0.5, true, true)
	assert_eq(top, Wear.grime_material(0.5, true, true))
	assert_ne(top, Wear.grime_material(0.5, false, true))
	assert_ne(top, Wear.grime_material(0.5, true, false))
	assert_ne(top, Wear.grime_material(0.4, true, true))
	var image := top.albedo_texture.get_image()
	assert_true(image.get_pixel(8, 0).a > image.get_pixel(8, 63).a)
	assert_true(image.get_pixel(8, 0).a > image.get_pixel(0, 0).a)
	var bottom := Wear.grime_material(0.5, false, false).albedo_texture.get_image()
	assert_true(bottom.get_pixel(8, 0).a < bottom.get_pixel(8, 63).a)
	var root := Node3D.new()
	Wear.decal(root, "Stain", Vector2.ONE, Vector3.ZERO, 0, 0.51, true)
	var node := root.get_child(0) as MeshInstance3D
	assert_eq(node.material_override, top)
	assert_eq(node.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	root.free()


func test_toning_is_idempotent_and_survives_quality_toggle() -> void:
	var old_quality := Materials.anti_tiling_enabled()
	var wall := Hall.wall_material(BUILDING, Vector3(26, 5, 7))
	var color := wall.albedo_color
	var base: Color = wall.get_meta(&"ar03_base_tint")
	assert_true(wall.has_meta(&"landmark_toned"))
	assert_false(wall.has_meta(&"town_hall_toned"))
	assert_eq(Hall.wall_material(BUILDING, Vector3(26, 5, 7)), wall)
	assert_eq(wall.albedo_color, color)
	Materials.set_anti_tiling_enabled(false)
	assert_eq(wall.albedo_color, base)
	Materials.set_anti_tiling_enabled(true)
	var lifted := base * Materials.ANTI_TILING_EXPOSURE_LIFT
	lifted.a = base.a
	assert_eq(wall.albedo_color, lifted)
	Materials.set_anti_tiling_enabled(old_quality)
	assert_true(Hall.roof_material(BUILDING).has_meta(&"landmark_toned"))


func test_town_hall_rebuild_keeps_gables_separate_from_dark_plinth() -> void:
	var first := Node3D.new()
	var second := Node3D.new()
	Hall.add_details(first, BUILDING, Vector2(26, 7), 5)
	Hall.add_details(second, BUILDING, Vector2(26, 7), 5)
	assert_eq(first.get_child_count(), 332)
	assert_eq(first.get_child_count(), second.get_child_count())
	for index in first.get_child_count():
		var a := first.get_child(index) as MeshInstance3D
		var b := second.get_child(index) as MeshInstance3D
		assert_eq(a.name, b.name)
		assert_eq(a.position, b.position)
		assert_eq(a.rotation, b.rotation)
		assert_eq(a.mesh.get_aabb(), b.mesh.get_aabb())
	var wall := Hall.wall_material(BUILDING, Vector3(26, 5, 7))
	var gable := first.get_node("TownHallGableE") as MeshInstance3D
	var plinth := first.get_node("TownHallPlinthN") as MeshInstance3D
	var gable_mat := gable.material_override as StandardMaterial3D
	var plinth_mat := plinth.material_override as StandardMaterial3D
	assert_eq(gable_mat.albedo_color, wall.albedo_color)
	assert_eq(plinth_mat.albedo_color, wall.albedo_color.darkened(0.28))
	assert_ne(gable_mat, plinth_mat)
	assert_eq(Wear.triplanar(wall, Hall.WALL_STEM), gable_mat)
	assert_true(gable_mat.uv1_triplanar)
	assert_eq(gable_mat.uv1_scale, Materials.library_world_uv_density(Hall.WALL_STEM))
	first.free()
	second.free()


func test_st_olaf_still_builds_with_shared_kit() -> void:
	var root := Node3D.new()
	Olaf.add_details(root, {"id": &"st_olaf_silhouette"}, 12)
	assert_true(root.get_child_count() > 0)
	root.free()


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng
