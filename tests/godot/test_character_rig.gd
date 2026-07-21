extends "res://tests/godot/test_case.gd"

const KALEV_SCENE := preload("res://assets/characters/kalev/kalev.tscn")
const MART_SCENE := preload("res://assets/characters/variants/mart.tscn")
const INNKEEPER_SCENE := preload("res://assets/characters/variants/innkeeper.tscn")
const HENNING_SCENE := preload("res://assets/characters/variants/henning.tscn")
const TOWNSWOMAN_SCENE := preload("res://assets/characters/variants/townswoman.tscn")
const REQUIRED_ANIMATIONS: Array[StringName] = [
	&"idle",
	&"walk",
	&"run",
	&"forge_strike",
	&"hammer_attack",
	&"hammer_charged_attack",
	&"unarmed_attack",
	&"guard",
	&"hit",
	&"fall",
	&"pickup",
	&"talk_gesture",
	&"sit_down",
	&"sit_idle",
	&"sit_up",
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

func test_unarmed_attack_uses_punch_clip() -> void:
	var kalev := _instantiate(KALEV_SCENE)
	assert_true(kalev.play_animation(&"unarmed_attack"))
	assert_eq(
		kalev.animation_player().current_animation,
		&"Unarmed_Melee_Attack_Punch_A",
		"An empty-hand attack must visibly use the authored punch clip"
	)
	kalev.queue_free()

func test_pickup_uses_shared_retargeted_clip() -> void:
	var kalev := _instantiate(KALEV_SCENE)
	assert_true(kalev.play_animation(&"pickup"))
	assert_eq(kalev.animation_player().current_animation, &"PickUp")
	assert_eq(
		kalev.animation_player().get_animation(&"PickUp").loop_mode,
		Animation.LOOP_NONE,
		"pickup must be a one-shot shared-rig action"
	)
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
			start_left_hand_z < -0.10 and start_right_hand_z > 0.10,
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
			skeleton.get_bone_global_pose(left_hand).origin.z > 0.10
			and skeleton.get_bone_global_pose(right_hand).origin.z < -0.10,
			"arm swing must reverse during the second half of the stride"
		)
	kalev.queue_free()


func test_scale_contract_projects_to_sixty_four_pixels() -> void:
	assert_true(is_equal_approx(CharacterScale.VISIBLE_HEIGHT_WORLD, 2.0))
	assert_true(is_equal_approx(CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE, 33.75))
	assert_true(is_equal_approx(CharacterScale.projected_height_px(), 64.0))
	var kalev := _instantiate(KALEV_SCENE)
	assert_true(
		kalev.get_node("Model").scale.is_equal_approx(SharedCharacterRig.HEROIC_MODEL_SCALE),
		"runtime must retain the taller, narrower heroic model normalization"
	)
	kalev.queue_free()


func test_proportions_modifier_installed_and_neutral_by_default() -> void:
	var kalev := _instantiate(KALEV_SCENE)
	var modifier := kalev.skeleton().get_node_or_null("RealisticProportions")
	assert_true(modifier != null, "shared rig must install its per-variant proportions hook")
	if modifier != null:
		# Adult proportions are baked into the generated glb by
		# tools/build_heroic_humanoid_glb.py + tools/generate_hero_body.py;
		# the runtime modifier is a fine-tune hook and must default neutral.
		assert_true(is_equal_approx(modifier.head_scale, 1.0), "baked head needs no runtime correction")
		assert_true(is_equal_approx(modifier.leg_segment_scale, 1.0), "baked legs need no runtime correction")
		assert_true(is_equal_approx(modifier.arm_segment_scale, 1.0), "baked arms need no runtime correction")
		assert_true(is_equal_approx(modifier.torso_scale, 1.0), "baked torso needs no runtime correction")
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

func test_equipment_slots_mount_replace_and_clear_props() -> void:
	var kalev := _instantiate(KALEV_SCENE)
	var hammer_scene := load("res://assets/characters/shared/hammer.tscn") as PackedScene

	assert_true(kalev.equipped(&"right_hand") != null, "variant hammer must occupy the right hand slot")
	var left := kalev.equip(&"left_hand", hammer_scene)
	assert_true(left != null, "left hand slot must accept a prop")
	assert_eq(kalev.equipped(&"left_hand"), left)

	var replacement := kalev.equip(&"left_hand", hammer_scene)
	assert_true(replacement != null and replacement != left, "equipping again must replace the prop")

	kalev.unequip(&"left_hand")
	assert_eq(kalev.equipped(&"left_hand"), null, "unequip must clear the slot")
	assert_eq(kalev.equip(&"nonsense", hammer_scene), null, "unknown slots must be rejected")
	kalev.queue_free()

func test_skinned_garments_deform_with_the_shared_skeleton() -> void:
	var kalev := _instantiate(KALEV_SCENE)
	var mart := _instantiate(MART_SCENE)

	assert_true(kalev.has_garment(&"cape"), "Kalev variant must wear the generated cape")
	assert_false(kalev.has_garment(&"hat"), "Kalev variant must not wear the hat")
	assert_true(mart.has_garment(&"hat"), "Mart variant must wear the generated hat")

	var cape_meshes := kalev.skeleton().find_children("Garment_cape*", "MeshInstance3D", false, false)
	assert_true(cape_meshes.size() > 0, "cape meshes must mount under the skeleton")
	for mesh: MeshInstance3D in cape_meshes:
		assert_true(mesh.mesh.get_surface_count() > 0, "garment must carry visible surfaces")
		assert_true(mesh.skin != null, "garment must stay skinned so it deforms with the body")

	kalev.unequip_garment(&"cape")
	assert_false(kalev.has_garment(&"cape"), "garments must be removable")

	assert_true(
		kalev.equip_garment(&"hat", SharedCharacterRig.GARMENT_SCENES[&"hat"]),
		"garments must be equippable at runtime"
	)
	assert_true(kalev.has_garment(&"hat"))

	kalev.queue_free()
	mart.queue_free()

func test_innkeeper_body_spec_fulfills_the_rig_contract() -> void:
	var kalev := _instantiate(KALEV_SCENE)
	var innkeeper := _instantiate(INNKEEPER_SCENE)

	assert_eq(innkeeper.validation_errors(), [], "generated body specs must satisfy the rig contract")
	assert_eq(innkeeper.variant_id(), &"char.innkeeper")
	assert_eq(
		innkeeper.skeleton().get_bone_count(),
		kalev.skeleton().get_bone_count(),
		"all generated bodies share the retargeted skeleton layout"
	)
	assert_eq(innkeeper.canonical_animation_names(), kalev.canonical_animation_names())
	assert_false(is_same(
		innkeeper.animation_player().get_animation_library(&""),
		kalev.animation_player().get_animation_library(&""),
	), "a body spec carries its own retargeted clips, proportioned to its skeleton")

	kalev.queue_free()
	innkeeper.queue_free()


func test_henning_body_has_an_authoritative_silhouette_and_social_animations() -> void:
	var kalev := _instantiate(KALEV_SCENE)
	var henning := _instantiate(HENNING_SCENE)

	assert_eq(henning.validation_errors(), [], "Henning must satisfy the shared rig contract")
	assert_eq(henning.variant_id(), &"char.henning")
	var kalev_head := kalev.skeleton().get_bone_global_rest(kalev.skeleton().find_bone("head")).origin.y
	var henning_head := henning.skeleton().get_bone_global_rest(henning.skeleton().find_bone("head")).origin.y
	assert_true(
		henning_head > kalev_head,
		"Henning's generated skeleton must read taller than Kalev"
	)
	for animation_name: StringName in [&"walk", &"idle", &"talk_gesture", &"sit_down", &"sit_idle", &"sit_up"]:
		assert_true(henning.has_animation(animation_name), "Henning needs %s" % animation_name)

	kalev.queue_free()
	henning.queue_free()


func test_variants_walk_with_their_own_gait_overrides() -> void:
	var kalev := _instantiate(KALEV_SCENE)
	var henning := _instantiate(HENNING_SCENE)
	var innkeeper := _instantiate(INNKEEPER_SCENE)

	assert_true(kalev.play_animation(&"walk"))
	assert_eq(kalev.animation_player().current_animation, &"Walking_A",
		"a variant without overrides keeps the shared default gait")
	assert_true(henning.play_animation(&"walk"))
	assert_eq(henning.animation_player().current_animation, &"Walking_B",
		"Henning's override must select his disciplined march clip")
	assert_true(innkeeper.play_animation(&"walk"))
	assert_eq(innkeeper.animation_player().current_animation, &"Walking_C",
		"the innkeeper's override must select his heavier walk clip")
	assert_eq(innkeeper.current_canonical_animation(), &"walk",
		"an overridden clip must still resolve to its canonical name")
	assert_true(innkeeper.play_animation(&"run"))
	assert_eq(innkeeper.animation_player().current_animation, &"Running_A")

	kalev.queue_free()
	henning.queue_free()
	innkeeper.queue_free()


func test_animation_override_validation_rejects_unknown_names() -> void:
	var henning := _instantiate(HENNING_SCENE)
	assert_eq(henning.validation_errors(), [], "authored overrides must validate cleanly")

	var broken := CharacterVariant.new()
	broken.stable_id = &"char.test_broken"
	broken.animation_overrides = {&"walk": &"No_Such_Clip", &"saunter": &"Walking_B"}
	henning.variant = broken
	var errors := henning.validation_errors()
	assert_true(
		errors.any(func(error: String) -> bool: return error.contains("No_Such_Clip")),
		"an override pointing at a missing clip must fail validation"
	)
	assert_true(
		errors.any(func(error: String) -> bool: return error.contains("saunter")),
		"an override for an unknown canonical animation must fail validation"
	)
	henning.queue_free()


func test_townswoman_body_spec_fulfills_the_rig_contract() -> void:
	var kalev := _instantiate(KALEV_SCENE)
	var townswoman := _instantiate(TOWNSWOMAN_SCENE)

	assert_eq(townswoman.validation_errors(), [], "the townswoman must satisfy the shared rig contract")
	assert_eq(townswoman.variant_id(), &"char.townswoman")
	assert_eq(
		townswoman.skeleton().get_bone_count(),
		kalev.skeleton().get_bone_count(),
		"all generated bodies share the retargeted skeleton layout"
	)
	var kalev_head := kalev.skeleton().get_bone_global_rest(kalev.skeleton().find_bone("head")).origin.y
	var townswoman_head := townswoman.skeleton().get_bone_global_rest(townswoman.skeleton().find_bone("head")).origin.y
	assert_true(
		townswoman_head < kalev_head,
		"the townswoman's generated skeleton must read shorter than Kalev"
	)
	assert_true(townswoman.play_animation(&"walk"))
	assert_eq(townswoman.animation_player().current_animation, &"Walking_B")

	kalev.queue_free()
	townswoman.queue_free()


func _instantiate(scene: PackedScene) -> SharedCharacterRig:
	var character := scene.instantiate() as SharedCharacterRig
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(character)
	return character
