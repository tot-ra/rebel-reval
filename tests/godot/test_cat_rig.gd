extends "res://tests/godot/test_case.gd"

const CAT_SCENE := preload("res://assets/characters/cat/cat_rig.tscn")
const REQUIRED_ANIMATIONS: Array[StringName] = [
	&"idle",
	&"walk",
	&"sleep",
	&"lick",
	&"stretch",
]


func test_cat_rig_has_production_animations() -> void:
	var cat := _instantiate_cat()

	assert_eq(cat.validation_errors(), [], "Cat rig must report no validation errors")
	for animation_name: StringName in REQUIRED_ANIMATIONS:
		assert_true(cat.has_animation(animation_name), "Missing cat animation %s" % animation_name)
		assert_true(cat.play_animation(animation_name), "Animation %s must play" % animation_name)
		assert_eq(cat.current_canonical_animation(), animation_name)

	cat.queue_free()


func test_cat_rig_faces_without_direction_assets() -> void:
	var cat := _instantiate_cat()

	for direction: Vector2 in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		cat.set_facing(direction)
		var expected := atan2(direction.x, direction.y)
		assert_true(
			is_equal_approx(cat.rotation.y, expected),
			"Cat must face logic direction %s" % direction
		)

	cat.queue_free()


func test_cat_rig_walk_speed_scales_around_reference() -> void:
	var cat := _instantiate_cat()

	assert_true(cat.play_animation(&"walk"))
	cat.set_locomotion_speed(0.0)
	assert_true(
		is_equal_approx(cat.animation_player().speed_scale, 0.7),
		"Zero speed must clamp to the minimum walk scale"
	)

	cat.set_locomotion_speed(CatRig.WALK_REFERENCE_SPEED_WORLD)
	assert_true(
		is_equal_approx(cat.animation_player().speed_scale, 1.0),
		"Reference speed must play the walk cycle at authored rate"
	)

	cat.set_locomotion_speed(CatRig.WALK_REFERENCE_SPEED_WORLD * 2.0)
	assert_true(
		is_equal_approx(cat.animation_player().speed_scale, 1.5),
		"Excess speed must clamp to the maximum walk scale"
	)

	cat.play_animation(&"idle")
	cat.set_locomotion_speed(CatRig.WALK_REFERENCE_SPEED_WORLD * 2.0)
	assert_true(
		is_equal_approx(cat.animation_player().speed_scale, 1.0),
		"Non-locomotion animations must ignore speed"
	)

	cat.queue_free()


func _instantiate_cat() -> CatRig:
	var cat := CAT_SCENE.instantiate() as CatRig
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(cat)
	return cat


func test_cat_coats_vary_by_seed_and_reserve_the_forge_coat() -> void:
	var seen: Dictionary = {}
	for placement_seed in 24:
		var coat := CatCoatVariants.coat_for_seed(placement_seed * 7919)
		assert_true(coat in CatCoatVariants.TOWN_COATS, "town cats must draw from the town coats")
		assert_true(coat != CatCoatVariants.COAT_FORGE, "the forge coat stays Kalev's")
		seen[coat] = true
	assert_true(seen.size() >= 3, "seeded coats must actually vary, got %d" % seen.size())


func test_cat_coat_textures_and_sizes_exist() -> void:
	for coat: StringName in CatCoatVariants.TOWN_COATS:
		var path := CatCoatVariants.coat_texture_path(coat)
		assert_true(ResourceLoader.exists(path), "missing baked coat texture %s" % path)
		assert_true(CatCoatVariants.build_material(coat) != null, "coat %s must build a material" % coat)
	for placement_seed in 8:
		var body_scale := CatCoatVariants.scale_for_seed(placement_seed * 31)
		assert_true(
			body_scale >= CatCoatVariants.SCALE_RANGE.x and body_scale <= CatCoatVariants.SCALE_RANGE.y,
			"cat size jitter must stay in range"
		)


func test_town_cat_wears_a_coat_over_the_production_rig() -> void:
	var cat := _instantiate_cat()
	var coat := CatCoatVariants.apply(cat, 12345)

	assert_true(coat in CatCoatVariants.TOWN_COATS)
	var bodies := CatCoatVariants.body_meshes(cat)
	assert_true(bodies.size() > 0, "production cat must carry a fur mesh")
	for mesh in bodies:
		assert_true(
			mesh.material_override != null,
			"coat variant must override the embedded forge fur"
		)

	var faces := 0
	for mesh in cat.find_children("*", "MeshInstance3D", true, false):
		if not String(mesh.name).begins_with(CatCoatVariants.FACE_MESH_PREFIX):
			continue
		faces += 1
		# Eyes, pupils, nose leather and whiskers keep their own materials; a
		# coat swap that painted them fur-coloured would erase the face.
		assert_true(
			(mesh as MeshInstance3D).material_override == null,
			"face parts must not be repainted by a coat swap"
		)
	assert_eq(faces, 1, "production cat must carry its eyes/whiskers face mesh")
	cat.queue_free()
