extends "res://tests/godot/test_case.gd"

const KALEV_SCENE := preload("res://assets/characters/kalev/kalev.tscn")
const MART_SCENE := preload("res://assets/characters/variants/mart.tscn")
const REQUIRED_ANIMATIONS: Array[StringName] = [
	&"idle",
	&"walk",
	&"run",
	&"forge_strike",
	&"hammer_attack",
	&"guard",
	&"hit",
	&"fall",
]

func test_kalev_rig_has_required_skeleton_animations_and_hammer() -> void:
	var kalev := _instantiate(KALEV_SCENE)

	assert_eq(kalev.validation_errors(), [], "Kalev rig contract must be complete")
	assert_eq(kalev.variant_id(), &"char.kalev")
	assert_true(kalev.has_equipment(), "Kalev variant must attach the hammer by bone")
	for animation_name: StringName in REQUIRED_ANIMATIONS:
		assert_true(kalev.has_animation(animation_name), "Missing canonical animation %s" % animation_name)
		assert_true(kalev.play_animation(animation_name), "Animation %s must play" % animation_name)

	kalev.queue_free()

func test_facing_is_transform_driven_without_direction_assets() -> void:
	var kalev := _instantiate(KALEV_SCENE)
	var source_clips: Array[StringName] = []
	for direction: Vector2 in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		kalev.set_facing(direction)
		assert_true(kalev.play_animation(&"walk"))
		source_clips.append(kalev.animation_player().current_animation)

	assert_eq(source_clips, [&"Walking_A", &"Walking_A", &"Walking_A", &"Walking_A"])
	assert_true(is_equal_approx(kalev.rotation.y, -PI / 2.0))
	kalev.queue_free()

func test_running_uses_contralateral_arm_swing() -> void:
	var kalev := _instantiate(KALEV_SCENE)
	assert_true(kalev.play_animation(&"run"))
	assert_eq(
		kalev.animation_player().current_animation,
		&"Running_B",
		"run must use the vendor clip with a clear forward/backward arm swing"
	)

	var animation := kalev.animation_player().get_animation(&"Running_B")
	var skeleton := kalev.skeleton()
	var modifier := skeleton.get_node("RealisticProportions")
	var left_hand := skeleton.find_bone("hand.l")
	var right_hand := skeleton.find_bone("hand.r")
	var left_foot := skeleton.find_bone("foot.l")
	var right_foot := skeleton.find_bone("foot.r")
	assert_true(
		left_hand >= 0 and right_hand >= 0 and left_foot >= 0 and right_foot >= 0,
		"run verification requires both hands and feet"
	)
	if left_hand >= 0 and right_hand >= 0 and left_foot >= 0 and right_foot >= 0:
		kalev.animation_player().play(&"Running_B", 0.0)
		kalev.animation_player().seek(0.0, true)
		modifier.call("_process_modification")
		skeleton.force_update_all_bone_transforms()
		var start_left_hand_z := skeleton.get_bone_global_pose(left_hand).origin.z
		var start_right_hand_z := skeleton.get_bone_global_pose(right_hand).origin.z
		var start_left_foot_z := skeleton.get_bone_global_pose(left_foot).origin.z
		var start_right_foot_z := skeleton.get_bone_global_pose(right_foot).origin.z
		assert_true(
			start_left_hand_z < -0.25 and start_right_hand_z > 0.25,
			"hands must visibly swing to opposite sides of the torso"
		)
		assert_true(
			start_left_hand_z * start_left_foot_z < 0.0
			and start_right_hand_z * start_right_foot_z < 0.0,
			"each arm must counter-swing against the leg on the same side"
		)

		kalev.animation_player().seek(animation.length * 0.5, true)
		modifier.call("_process_modification")
		skeleton.force_update_all_bone_transforms()
		assert_true(
			skeleton.get_bone_global_pose(left_hand).origin.z > 0.25
			and skeleton.get_bone_global_pose(right_hand).origin.z < -0.25,
			"arm swing must reverse during the second half of the stride"
		)
	kalev.queue_free()


func test_scale_contract_projects_to_sixty_four_pixels() -> void:
	assert_true(is_equal_approx(CharacterScale.VISIBLE_HEIGHT_WORLD, 2.0))
	assert_true(is_equal_approx(CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE, 28.125))
	assert_true(is_equal_approx(CharacterScale.projected_height_px(), 64.0))


func test_realistic_proportions_modifier_retargets_vendor_rig() -> void:
	var kalev := _instantiate(KALEV_SCENE)
	var modifier := kalev.skeleton().get_node_or_null("RealisticProportions")
	assert_true(modifier != null, "shared rig must install its animated proportions modifier")
	if modifier != null:
		assert_true(is_equal_approx(modifier.head_scale, 0.64), "head must use the approved realistic scale")
		assert_true(
			is_equal_approx(modifier.leg_segment_scale, 1.30),
			"legs must lengthen toward realistic proportions"
		)
		assert_true(
			is_equal_approx(modifier.arm_segment_scale, 1.24),
			"arms must lengthen toward realistic proportions"
		)
		modifier.call("_process_modification")
		var head_bone := kalev.skeleton().find_bone("head")
		assert_true(head_bone >= 0, "vendor rig must expose the head bone")
		if head_bone >= 0:
			assert_true(
				kalev.skeleton().get_bone_pose_scale(head_bone).is_equal_approx(Vector3.ONE * 0.64),
				"head pose scale must survive animation updates"
			)
		var upper_leg := kalev.skeleton().find_bone("upperleg.l")
		assert_true(upper_leg >= 0, "vendor rig must expose leg bones")
		if upper_leg >= 0:
			assert_true(
				kalev.skeleton().get_bone_pose_scale(upper_leg).is_equal_approx(Vector3(1.0, 1.30, 1.0)),
				"leg pose scale must survive animation updates"
			)
	kalev.queue_free()


func test_mart_is_a_data_only_swap_on_the_shared_rig() -> void:
	var kalev := _instantiate(KALEV_SCENE)
	var mart := _instantiate(MART_SCENE)

	assert_eq(mart.validation_errors(), [], "Second variant must preserve the rig contract")
	assert_eq(mart.variant_id(), &"char.mart")
	assert_false(mart.has_equipment(), "Mart variant must swap out Kalev's hammer")
	assert_eq(mart.skeleton().get_bone_count(), kalev.skeleton().get_bone_count())
	assert_eq(mart.canonical_animation_names(), kalev.canonical_animation_names())
	assert_true(is_same(
		mart.animation_player().get_animation_library(&""),
		kalev.animation_player().get_animation_library(&""),
	), "Variants must reuse one imported animation library")

	kalev.queue_free()
	mart.queue_free()

func test_occlusion_ghost_overlays_every_mesh_and_clears() -> void:
	var kalev := _instantiate(KALEV_SCENE)
	var mesh_instances := kalev.find_children("*", "MeshInstance3D", true, false)
	assert_true(mesh_instances.size() > 0, "Rig must expose mesh instances to overlay")
	assert_false(kalev.occlusion_ghost_enabled(), "Ghost must start disabled")

	kalev.set_occlusion_ghost(true)
	for mesh_instance: MeshInstance3D in mesh_instances:
		var overlay := mesh_instance.material_overlay as ShaderMaterial
		assert_true(
			overlay != null and overlay.shader == SharedCharacterRig.OCCLUDED_SILHOUETTE_SHADER,
			"%s must carry the occlusion silhouette overlay" % mesh_instance.name
		)

	kalev.set_occlusion_ghost(false)
	for mesh_instance: MeshInstance3D in mesh_instances:
		assert_eq(mesh_instance.material_overlay, null, "%s must drop the overlay when visible" % mesh_instance.name)

	kalev.queue_free()

func _instantiate(scene: PackedScene) -> SharedCharacterRig:
	var character := scene.instantiate() as SharedCharacterRig
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(character)
	return character
