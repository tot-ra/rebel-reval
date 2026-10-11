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
		is_equal_approx(cat.animation_player().speed_scale, 2.0),
		"Double reference speed must play at 2x while under the locomotion cap"
	)
	cat.set_locomotion_speed(CatRig.WALK_REFERENCE_SPEED_WORLD * 10.0)
	assert_true(
		is_equal_approx(cat.animation_player().speed_scale, CatRig.LOCOMOTION_SPEED_SCALE_MAX),
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


func test_cat_coat_sizes_stay_in_range() -> void:
	for placement_seed in 8:
		var body_scale := CatCoatVariants.scale_for_seed(placement_seed * 31)
		assert_true(
			body_scale >= CatCoatVariants.SCALE_RANGE.x and body_scale <= CatCoatVariants.SCALE_RANGE.y,
			"cat size jitter must stay in range"
		)


func test_cat_rig_soles_stay_on_the_ground_across_clips() -> void:
	var cat := _instantiate_cat()
	cat._snap_model_to_ground()
	assert_true(
		cat.mesh_min_y() >= -0.02,
		"Idle soles must sit near the actor origin after ground snap, got %s" % cat.mesh_min_y()
	)
	for animation_name: StringName in [&"idle", &"sleep", &"lick", &"stretch", &"walk"]:
		assert_true(cat.play_animation(animation_name), "must play %s" % animation_name)
		var player := cat.animation_player()
		assert_true(player != null)
		var length := maxf(player.current_animation_length, 0.01)
		for t in [0.0, length * 0.35, length * 0.7]:
			player.seek(t, true)
			var min_y := cat.mesh_min_y()
			assert_true(
				min_y >= -0.03,
				"%s @ %.2fs must not bury the body (min_y=%s)" % [animation_name, t, min_y]
			)
			assert_true(
				min_y <= 0.08,
				"%s @ %.2fs must not hover far above the floor (min_y=%s)" % [animation_name, t, min_y]
			)
	cat.queue_free()


func test_town_cat_apply_coat_sets_meta_and_scale() -> void:
	var cat := _instantiate_cat()
	assert_true(cat.has_method("apply_coat"))
	var coat: StringName = cat.apply_coat(12345)
	assert_true(coat in CatCoatVariants.TOWN_COATS)
	assert_eq(cat.get_meta(&"cat_coat"), coat)
	assert_true(cat.scale.x >= CatCoatVariants.SCALE_RANGE.x)
	cat.queue_free()
