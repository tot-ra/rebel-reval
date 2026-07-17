extends "res://tests/godot/test_case.gd"

const CAT_SCENE := preload("res://assets/characters/cat/cat_rig.tscn")
const REQUIRED_ANIMATIONS: Array[StringName] = [
	&"idle",
	&"walk",
	&"sleep",
	&"lick",
	&"stretch",
]


func test_cat_rig_has_procedural_animations() -> void:
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
