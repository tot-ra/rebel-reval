extends "res://tests/godot/test_case.gd"

const KALEV_SCENE := preload("res://assets/characters/kalev/kalev.tscn")
const MART_SCENE := preload("res://assets/characters/variants/mart.tscn")
const INNKEEPER_SCENE := preload("res://assets/characters/variants/innkeeper.tscn")
const HENNING_SCENE := preload("res://assets/characters/variants/henning.tscn")
const AITA_SCENE := preload("res://assets/characters/variants/aita.tscn")
const KAJA_SCENE := preload("res://assets/characters/variants/kaja.tscn")
const JURGEN_SCENE := preload("res://assets/characters/variants/jurgen.tscn")
const ELLEN_SCENE := preload("res://assets/characters/variants/ellen.tscn")
const TOWNSWOMAN_SCENE := preload("res://assets/characters/variants/townswoman.tscn")
const WATCHMAN_SCENE := preload("res://assets/characters/variants/watchman.tscn")
const SERGEANT_SCENE := preload("res://assets/characters/variants/sergeant.tscn")
const DANISH_WARRIOR_SCENE := preload("res://assets/characters/variants/danish_warrior.tscn")
const REQUIRED_ANIMATIONS: Array[StringName] = [
	&"idle",
	&"walk",
	&"run",
	&"forge_strike",
	&"hammer_attack",
	&"sword_attack",
	&"hammer_charged_attack",
	&"unarmed_attack",
	&"guard",
	&"dodge_left",
	&"dodge_right",
	&"dodge_forward",
	&"dodge_backward",
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

func test_directional_dodges_use_non_looping_shared_clips() -> void:
	var kalev := _instantiate(KALEV_SCENE)
	var expected := {
		&"dodge_left": &"Dodge_Left",
		&"dodge_right": &"Dodge_Right",
		&"dodge_forward": &"Dodge_Forward",
		&"dodge_backward": &"Dodge_Backward",
	}
	for canonical_name: StringName in expected:
		assert_true(kalev.play_animation(canonical_name, 0.0))
		var source_name: StringName = expected[canonical_name]
		assert_eq(kalev.animation_player().current_animation, source_name)
		assert_eq(
			kalev.animation_player().get_animation(source_name).loop_mode,
			Animation.LOOP_NONE,
			"Directional dodge clips must remain one-shot actions"
		)
	kalev.queue_free()


func test_sword_attack_uses_diagonal_slice_clip() -> void:
	var kalev := _instantiate(KALEV_SCENE)
	assert_true(kalev.play_animation(&"sword_attack"))
	assert_eq(kalev.animation_player().current_animation, &"1H_Melee_Attack_Slice_Diagonal")
	assert_eq(
		kalev.animation_player().get_animation(&"1H_Melee_Attack_Slice_Diagonal").loop_mode,
		Animation.LOOP_NONE,
		"Sword light attack must remain a one-shot shared-rig action"
	)
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


func test_locomotion_speed_and_foot_plants_follow_the_authored_gait() -> void:
	var kalev := _instantiate(KALEV_SCENE)
	assert_true(kalev.play_animation(&"walk", 0.0))
	kalev.set_locomotion_speed(3.125)
	assert_true(
		is_equal_approx(kalev.animation_player().speed_scale, 3.125 / 1.4),
		"walk playback must scale with actual world speed instead of capping below the player"
	)

	var player := kalev.animation_player()
	var animation := player.get_animation(&"Walking_A")
	player.seek(0.0, true)
	assert_eq(kalev.consume_foot_plant(), SharedCharacterRig.LEFT_FOOT_BONE)
	assert_eq(kalev.consume_foot_plant(), &"", "one planted foot must emit only one contact")
	player.seek(animation.length * 0.5, true)
	assert_eq(kalev.consume_foot_plant(), SharedCharacterRig.RIGHT_FOOT_BONE)
	var right_foot := kalev.foot_world_position(SharedCharacterRig.RIGHT_FOOT_BONE)
	assert_true(
		right_foot.distance_to(kalev.global_position) > 0.1,
		"foot contact position must come from the animated bone, not the actor pivot"
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


func test_view_glyph_height_clears_posed_crown() -> void:
	var kalev := _instantiate(KALEV_SCENE)
	var innkeeper := _instantiate(INNKEEPER_SCENE)
	var henning := _instantiate(HENNING_SCENE)

	assert_true(
		kalev.view_glyph_height() > CharacterScale.VISIBLE_HEIGHT_WORLD,
		"Hero talk glyph must clear the 2.0 crown contract"
	)
	assert_true(
		henning.view_glyph_height() > CharacterScale.VISIBLE_HEIGHT_WORLD,
		"Helmeted bodies still clear their posed head"
	)
	assert_true(
		innkeeper.view_glyph_height() < kalev.view_glyph_height(),
		"Shorter authored bodies must place the talk glyph lower"
	)
	kalev.queue_free()
	innkeeper.queue_free()
	henning.queue_free()


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


func test_mart_has_a_named_body_on_the_shared_animation_contract() -> void:
	var kalev := _instantiate(KALEV_SCENE)
	var mart := _instantiate(MART_SCENE)

	assert_eq(mart.validation_errors(), [], "Mart's body must preserve the rig contract")
	assert_eq(mart.variant_id(), &"char.mart")
	assert_false(mart.has_equipment(), "Mart must not inherit Kalev's hammer")
	assert_eq(mart.skeleton().get_bone_count(), kalev.skeleton().get_bone_count())
	assert_eq(mart.canonical_animation_names(), kalev.canonical_animation_names())
	assert_false(is_same(
		mart.animation_player().get_animation_library(&""),
		kalev.animation_player().get_animation_library(&""),
	), "a named body carries clips retargeted to its own proportions")
	var kalev_head := kalev.skeleton().get_bone_global_rest(kalev.skeleton().find_bone("head")).origin.y
	var mart_head := mart.skeleton().get_bone_global_rest(mart.skeleton().find_bone("head")).origin.y
	assert_true(mart_head < kalev_head, "the 16-year-old apprentice must read shorter than Kalev")

	kalev.queue_free()
	mart.queue_free()

func test_approved_hero_cast_uses_one_shared_animation_and_lod_contract() -> void:
	var reference := _instantiate(KALEV_SCENE)
	var cases: Array[Dictionary] = [
		{"scene": MART_SCENE, "id": &"char.mart"},
		{"scene": AITA_SCENE, "id": &"char.aita"},
		{"scene": KAJA_SCENE, "id": &"char.kaja"},
		{"scene": HENNING_SCENE, "id": &"char.henning"},
		{"scene": JURGEN_SCENE, "id": &"char.jurgen"},
		{"scene": ELLEN_SCENE, "id": &"char.ellen"},
	]
	for entry: Dictionary in cases:
		var character := _instantiate(entry["scene"] as PackedScene)
		assert_eq(character.validation_errors(), [], "%s must satisfy the shared rig contract" % character.name)
		assert_eq(character.variant_id(), entry["id"])
		assert_eq(character.skeleton().get_bone_count(), reference.skeleton().get_bone_count())
		assert_eq(character.canonical_animation_names(), REQUIRED_ANIMATIONS)
		for animation_name: StringName in REQUIRED_ANIMATIONS:
			assert_true(character.has_animation(animation_name), "%s needs %s" % [character.name, animation_name])
		assert_true(character.lod_visibility_configured(), "%s must mount distance LODs" % character.name)
		assert_true(character.lod_mesh_count(1) > 0 and character.lod_mesh_count(2) > 0)
		character.queue_free()
	reference.queue_free()

func test_hero_cast_silhouettes_are_distinct_without_color_cues() -> void:
	var scenes: Array[PackedScene] = [
		MART_SCENE,
		AITA_SCENE,
		KAJA_SCENE,
		HENNING_SCENE,
		JURGEN_SCENE,
		ELLEN_SCENE,
	]
	var signatures := {}
	for scene: PackedScene in scenes:
		var character := _instantiate(scene)
		var skeleton := character.skeleton()
		var head_y := skeleton.get_bone_global_rest(skeleton.find_bone("head")).origin.y
		var hand_x := absf(
			skeleton.get_bone_global_rest(skeleton.find_bone("hand.l")).origin.x
		)
		var hip_x := absf(
			skeleton.get_bone_global_rest(skeleton.find_bone("upperleg.l")).origin.x
		)
		# WHY: Bone-space stature, arm breadth, and hip breadth survive grayscale and
		# material swaps, so this signature rejects color-only cast differentiation.
		var signature := Vector3(
			snappedf(head_y, 0.001),
			snappedf(hand_x, 0.001),
			snappedf(hip_x, 0.001)
		)
		assert_false(
			signatures.has(signature),
			"%s duplicates %s's silhouette" % [
				character.name,
				signatures.get(signature, ""),
			]
		)
		signatures[signature] = character.name
		character.queue_free()
	assert_eq(
		signatures.size(),
		scenes.size(),
		"all six named cast silhouettes must remain geometrically distinct"
	)


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

func test_sword_scene_mounts_with_grip_origin_and_blade_away_from_hand() -> void:
	var kalev := _instantiate(KALEV_SCENE)
	var sword_scene := load("res://assets/characters/shared/sword.tscn") as PackedScene
	var sword := kalev.equip(&"right_hand", sword_scene)
	assert_true(sword != null)
	assert_eq(sword.name, "PlainCruciformSword")
	assert_true(sword.get_node_or_null("Grip") != null)
	assert_true(sword.get_node_or_null("Crossguard") != null)
	assert_true(sword.get_node_or_null("Blade") != null)
	assert_true(sword.get_node_or_null("BladeTip") != null)
	assert_true(
		(sword.get_node("BladeTip") as Node3D).position.y > (sword.get_node("Crossguard") as Node3D).position.y,
		"Blade must extend away from the grip instead of into the wrist"
	)
	assert_true((sword.get_node("Blade") as MeshInstance3D).get_aabb().size.y > 0.65)
	assert_true((sword.get_node("Crossguard") as MeshInstance3D).get_aabb().size.x > 0.25)
	kalev.queue_free()


func test_sword_blade_points_away_from_torso_in_idle_and_attack() -> void:
	var kalev := _instantiate(KALEV_SCENE)
	var sword_scene := load("res://assets/characters/shared/sword.tscn") as PackedScene
	var sword := kalev.equip(&"right_hand", sword_scene)
	var chest_index := kalev.skeleton().find_bone("chest")
	assert_true(chest_index >= 0)
	for pose: Dictionary in [
		{"animation": &"idle", "time": 0.0},
		{"animation": &"sword_attack", "time": 0.38},
	]:
		assert_true(kalev.play_animation(pose["animation"], 0.0))
		kalev.animation_player().seek(float(pose["time"]), true)
		kalev.skeleton().force_update_all_bone_transforms()
		var grip_world := sword.to_global(Vector3.ZERO)
		var tip_world := (sword.get_node("BladeTip") as Node3D).to_global(Vector3(0.0, 0.06, 0.0))
		var chest_world := kalev.skeleton().to_global(
			kalev.skeleton().get_bone_global_pose(chest_index).origin
		)
		assert_true(
			tip_world.distance_to(chest_world) > grip_world.distance_to(chest_world),
			"%s blade tip must extend away from the torso" % String(pose["animation"])
		)
		assert_true(
			grip_world.distance_to(chest_world) > 0.12,
			"%s grip must stay outside the torso" % String(pose["animation"])
		)
	kalev.queue_free()


func test_map_view_runtime_hot_swaps_hammer_sword_and_empty_hand_visuals() -> void:
	var db := ContentDB.new()
	assert_true(db.load_from_directories(SessionState.DEMO_CONTENT_DIRS))
	var state := GameState.new()
	state.bag.set_content_db(db)
	var kalev := _instantiate(KALEV_SCENE)
	var actors := MapViewRuntimeActors.new()
	actors.configure(null, null, null, kalev, null, Callable(), Callable())
	actors.bind_equipment_state(state, db)
	assert_eq(kalev.equipped(&"right_hand"), null)

	assert_eq(state.bag.try_add(&"item.forge_hammer"), InventoryBag.AddResult.OK)
	assert_true(state.equip_from_bag(&"right_hand", &"item.forge_hammer"))
	assert_true(kalev.equipped(&"right_hand").get_node_or_null("Handle") != null)
	assert_true(kalev.equipped(&"right_hand").get_node_or_null("Head") != null)

	assert_eq(state.bag.try_add(&"item.plain_sword"), InventoryBag.AddResult.OK)
	assert_true(state.equip_from_bag(&"right_hand", &"item.plain_sword"))
	assert_true(kalev.equipped(&"right_hand").get_node_or_null("Blade") != null)
	assert_true(kalev.equipped(&"right_hand").get_node_or_null("Crossguard") != null)

	assert_true(state.unequip_to_bag(&"right_hand"))
	assert_eq(kalev.equipped(&"right_hand"), null)
	actors.disconnect_equipment_state()
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
	assert_false(mart.has_garment(&"hat"), "Mart keeps his generated adolescent silhouette unobstructed")

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


func test_watchman_and_sergeant_are_distinguishable_without_color_cues() -> void:
	var henning := _instantiate(HENNING_SCENE)
	var watchman := _instantiate(WATCHMAN_SCENE)
	var sergeant := _instantiate(SERGEANT_SCENE)

	assert_eq(watchman.validation_errors(), [], "watchman must satisfy the shared rig contract")
	assert_eq(sergeant.validation_errors(), [], "sergeant must satisfy the shared rig contract")
	assert_eq(watchman.variant_id(), &"char.watchman")
	assert_eq(sergeant.variant_id(), &"char.sergeant")
	assert_true(watchman.has_equipment(), "watchman carries a spear for gameplay-scale read")
	assert_false(sergeant.has_equipment(), "sergeant relies on pauldrons and helmet, not a polearm")
	assert_true(sergeant.has_garment(&"hat"), "sergeant wears the generated helmet garment")

	var watchman_shoulders := _shoulder_span(watchman)
	var sergeant_shoulders := _shoulder_span(sergeant)
	assert_true(
		sergeant_shoulders > watchman_shoulders,
		"sergeant shoulders must read broader than the watchman at gameplay scale (%.3f vs %.3f)"
		% [sergeant_shoulders, watchman_shoulders]
	)

	var henning_head := henning.skeleton().get_bone_global_rest(henning.skeleton().find_bone("head")).origin.y
	var sergeant_head := sergeant.skeleton().get_bone_global_rest(sergeant.skeleton().find_bone("head")).origin.y
	assert_true(
		sergeant_head < henning_head,
		"sergeant must stay visually subordinate to Captain Henning"
	)

	assert_true(watchman.play_animation(&"walk"))
	assert_eq(watchman.animation_player().current_animation, &"Walking_C")
	assert_true(sergeant.play_animation(&"walk"))
	assert_eq(sergeant.animation_player().current_animation, &"Walking_B")

	var watch_profile := EnemyArchetype.watchman()
	var sarge_profile := EnemyArchetype.sergeant()
	assert_true(watch_profile.shows_spear and not watch_profile.shows_pauldrons)
	assert_true(sarge_profile.shows_pauldrons and not sarge_profile.shows_spear)
	assert_true(sarge_profile.body_half_width > watch_profile.body_half_width)

	henning.queue_free()
	watchman.queue_free()
	sergeant.queue_free()


func test_all_humanoids_use_anatomical_body_clothing_and_muscle_system() -> void:
	var scenes: Array[PackedScene] = [
		KALEV_SCENE,
		MART_SCENE,
		INNKEEPER_SCENE,
		HENNING_SCENE,
		TOWNSWOMAN_SCENE,
		WATCHMAN_SCENE,
		SERGEANT_SCENE,
		DANISH_WARRIOR_SCENE,
	]
	for scene: PackedScene in scenes:
		var character := _instantiate(scene)
		assert_eq(character.validation_errors(), [], "%s must preserve the shared rig contract" % character.name)
		assert_true(
			character.skeleton().has_node("AnatomicalMuscles"),
			"%s must install pose-driven muscle response" % character.name
		)
		var has_anatomy := false
		var has_clothing := false
		for found: Node in character.get_node("Model").find_children("*", "MeshInstance3D", true, false):
			has_anatomy = has_anatomy or found.name.begins_with("Anatomy_")
			has_clothing = has_clothing or found.name.begins_with("Clothing_")
		assert_true(has_anatomy, "%s needs a bone-derived anatomical envelope" % character.name)
		assert_true(has_clothing, "%s needs clothing outside the body envelope" % character.name)
		character.queue_free()


func test_danish_warrior_is_a_distinct_animated_spear_variant() -> void:
	var warrior := _instantiate(DANISH_WARRIOR_SCENE)
	assert_eq(warrior.variant_id(), &"char.danish_warrior")
	assert_true(warrior.has_equipment(), "Danish garrison warrior needs a spear silhouette")
	assert_true(warrior.play_animation(&"walk"))
	assert_eq(warrior.animation_player().current_animation, &"Walking_B")
	assert_true(warrior.has_animation(&"guard"))
	warrior.queue_free()


func test_shared_rig_distance_lods_mount_with_visibility_ranges() -> void:
	var kalev := _instantiate(KALEV_SCENE)
	assert_true(kalev.lod_visibility_configured(), "Kalev must mount LOD1/LOD2 meshes with distance fades")
	assert_true(kalev.lod_mesh_count(1) > 0, "LOD1 meshes must exist on the live skeleton")
	assert_true(kalev.lod_mesh_count(2) > 0, "LOD2 meshes must exist on the live skeleton")
	for lod_level: int in [1, 2]:
		for lod_mesh: MeshInstance3D in kalev.skeleton().get_children().filter(func(child: Node) -> bool:
			return child is MeshInstance3D and String(child.name).begins_with("LOD%d_" % lod_level)
		):
			assert_false(
				String(lod_mesh.name).contains("Icosphere"),
				"LOD%d must not mount helper Icospheres that default to white" % lod_level
			)
			assert_eq(
				lod_mesh.visibility_range_fade_mode,
				GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED,
				"LOD fade must stay disabled on GL Compatibility to avoid bright double-draws"
			)
			match lod_level:
				1:
					assert_eq(lod_mesh.visibility_range_begin, SharedCharacterRig.LOD1_VISIBILITY_BEGIN)
					assert_eq(lod_mesh.visibility_range_begin_margin, SharedCharacterRig.LOD1_VISIBILITY_MARGIN)
					assert_eq(lod_mesh.visibility_range_end, SharedCharacterRig.LOD1_VISIBILITY_END)
					assert_eq(lod_mesh.visibility_range_end_margin, SharedCharacterRig.LOD1_VISIBILITY_MARGIN)
				2:
					assert_eq(lod_mesh.visibility_range_begin, SharedCharacterRig.LOD2_VISIBILITY_BEGIN)
					assert_eq(lod_mesh.visibility_range_begin_margin, SharedCharacterRig.LOD1_VISIBILITY_MARGIN)
			for surface_index: int in lod_mesh.mesh.get_surface_count():
				var surface_material := lod_mesh.mesh.surface_get_material(surface_index)
				assert_true(
					surface_material != null,
					"LOD%d surfaces must retain their authored materials instead of defaulting white" % lod_level
				)
	var lod0_sample: MeshInstance3D = null
	for found: Node in kalev.get_node("Model").find_children("*", "MeshInstance3D", true, false):
		lod0_sample = found as MeshInstance3D
		break
	assert_true(lod0_sample != null, "LOD0 body mesh must exist")
	assert_eq(
		lod0_sample.visibility_range_fade_mode,
		GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED,
		"LOD0 fade must stay disabled on GL Compatibility"
	)
	assert_eq(lod0_sample.visibility_range_end, SharedCharacterRig.LOD0_VISIBILITY_END)
	assert_eq(
		lod0_sample.visibility_range_end_margin,
		SharedCharacterRig.LOD0_VISIBILITY_MARGIN,
		"LOD0 end margin must preserve the one-unit hysteresis contract"
	)
	assert_eq(
		SharedCharacterRig.LOD0_VISIBILITY_END,
		SharedCharacterRig.LOD1_VISIBILITY_BEGIN,
		"LOD ranges must abut so Compatibility hard-cuts do not double-draw"
	)
	assert_eq(
		SharedCharacterRig.LOD1_VISIBILITY_END,
		SharedCharacterRig.LOD2_VISIBILITY_BEGIN,
		"LOD1/LOD2 ranges must abut so Compatibility hard-cuts do not double-draw"
	)
	var manifest := FileAccess.open(
		"res://assets/characters/shared/character_lod_manifest.json",
		FileAccess.READ
	)
	assert_true(manifest != null, "character LOD manifest must be present")
	var parsed: Variant = JSON.parse_string(manifest.get_as_text())
	assert_true(parsed is Dictionary, "character LOD manifest must parse")
	var bodies: Array = parsed.get("bodies", [])
	assert_false(bodies.is_empty(), "character LOD manifest must list generated bodies")
	var heroic: Dictionary = {}
	for body_entry: Variant in bodies:
		if body_entry is Dictionary and body_entry.get("body", "") == "heroic_humanoid.glb":
			heroic = body_entry
			break
	assert_false(heroic.is_empty(), "heroic_humanoid LOD report must exist")
	var lod1: Dictionary = heroic.get("levels", {}).get("lod1", {})
	var lod2: Dictionary = heroic.get("levels", {}).get("lod2", {})
	var lod1_fraction := float(lod1.get("fraction_of_lod0", 0.0))
	var lod2_fraction := float(lod2.get("fraction_of_lod0", 1.0))
	assert_true(lod1_fraction >= 0.40, "LOD1 should retain roughly half of LOD0 triangles")
	assert_true(lod1_fraction <= 0.60, "LOD1 should stay near the 50% decimation target")
	assert_true(lod2_fraction <= 0.30, "LOD2 should stay near the 20% decimation target")
	kalev.queue_free()




func test_hero_cast_carries_pbr_maps_at_the_tier_zero_contract() -> void:
	var characters: Array[Node] = [
		_instantiate(MART_SCENE),
		_instantiate(AITA_SCENE),
		_instantiate(KAJA_SCENE),
		_instantiate(HENNING_SCENE),
		_instantiate(JURGEN_SCENE),
		_instantiate(ELLEN_SCENE),
	]
	var all_families := {}
	for character: Node in characters:
		var character_families := {}
		for found: Node in character.get_node("Model").find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := found as MeshInstance3D
			if mesh_instance == null or mesh_instance.mesh == null:
				continue
			for surface_index: int in mesh_instance.mesh.get_surface_count():
				var material := mesh_instance.mesh.surface_get_material(surface_index) as StandardMaterial3D
				if material == null or material.albedo_texture == null:
					continue
				var albedo_path := material.albedo_texture.resource_path
				var marker := "_hero_tex_"
				var marker_index := albedo_path.find(marker)
				if marker_index < 0:
					continue
				var family := albedo_path.substr(marker_index + marker.length()).split("_")[0]
				character_families[family] = true
				all_families[family] = true
				assert_true(
					material.normal_enabled and material.normal_texture != null,
					"%s needs a normal map" % family
				)
				assert_true(material.roughness_texture != null, "%s needs a roughness map" % family)
				assert_true(material.ao_texture != null, "%s needs an AO map" % family)
				_assert_maps_not_degenerate(material, family)
		for required_family: String in ["skin", "cloth", "leather", "hair"]:
			assert_true(
				character_families.has(required_family),
				"%s Tier-0 body needs the %s PBR family" % [character.name, required_family]
			)
		character.queue_free()
	for required_family: String in ["skin", "cloth", "leather", "metal", "hair"]:
		assert_true(
			all_families.has(required_family),
			"%s must be represented in the cast material contract" % required_family
		)


func _assert_maps_not_degenerate(material: StandardMaterial3D, family: String) -> void:
	# Constant ORM (G=0) and black normals made characters mirror-smooth and
	# bloom-haloed under MapViewLighting. Sample the authored PNG path because
	# VRAM-compressed textures often return null from Texture2D.get_image().
	var roughness_path := material.roughness_texture.resource_path
	var normal_path := material.normal_texture.resource_path
	assert_true(
		roughness_path.ends_with(".png") and FileAccess.file_exists(roughness_path),
		"%s roughness sidecar must remain a readable PNG" % family
	)
	assert_true(
		normal_path.ends_with(".png") and FileAccess.file_exists(normal_path),
		"%s normal sidecar must remain a readable PNG" % family
	)
	var roughness_image := Image.new()
	assert_eq(roughness_image.load(roughness_path), OK, "%s roughness map must decode" % family)
	var roughness_sample := roughness_image.get_pixel(
		roughness_image.get_width() / 2, roughness_image.get_height() / 2
	)
	assert_true(
		roughness_sample.g > 0.05,
		"%s ORM must carry roughness in G (got %s)" % [family, roughness_sample]
	)
	var normal_image := Image.new()
	assert_eq(normal_image.load(normal_path), OK, "%s normal map must decode" % family)
	var normal_sample := normal_image.get_pixel(
		normal_image.get_width() / 2, normal_image.get_height() / 2
	)
	assert_true(
		normal_sample.b > 0.4,
		"%s normal map must not be solid black (got %s)" % [family, normal_sample]
	)


func test_shared_character_hair_and_beard_shader_follow_material_names_across_lods() -> void:
	var kalev := _instantiate(KALEV_SCENE)
	var checked_hair := 0
	var checked_beard := 0
	for found: Node in kalev.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := found as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		for surface_index: int in mesh_instance.mesh.get_surface_count():
			var source_material := mesh_instance.mesh.surface_get_material(surface_index)
			if source_material == null:
				continue
			var material_name := StringName(source_material.resource_name)
			if material_name not in SharedCharacterRig.HAIR_MATERIAL_NAMES:
				continue
			var active := mesh_instance.get_active_material(surface_index)
			assert_true(
				active is ShaderMaterial,
				"%s hair surface must use the anisotropic hair shader" % mesh_instance.name
			)
			if active is not ShaderMaterial:
				continue
			var shader_material := active as ShaderMaterial
			assert_eq(shader_material.shader, SharedCharacterRig.HAIR_MATERIAL_SHADER)
			assert_true(
				shader_material.get_shader_parameter("albedo_texture") != null,
				"%s must preserve its albedo map" % material_name
			)
			assert_true(
				shader_material.get_shader_parameter("normal_texture") != null,
				"%s must preserve its normal map" % material_name
			)
			assert_true(
				shader_material.get_shader_parameter("roughness_texture") != null,
				"%s must preserve its roughness map" % material_name
			)
			var anisotropy_strength: Variant = shader_material.get_shader_parameter(
				"anisotropy_strength"
			)
			assert_true(
				anisotropy_strength is float
				and anisotropy_strength >= 0.25
				and anisotropy_strength <= 0.50,
				"%s must use a restrained directional fibre response" % material_name
			)
			var normal_strength: Variant = shader_material.get_shader_parameter("normal_strength")
			assert_true(
				normal_strength is float and normal_strength <= 0.40,
				"%s normal detail must break up clumps without " % material_name
				+ "embossing plastic grooves"
			)
			var alpha_cutoff: Variant = shader_material.get_shader_parameter("alpha_cutoff")
			assert_true(
				alpha_cutoff is float and alpha_cutoff > 0.0,
				"%s must expose alpha cutout for hair cards" % material_name
			)
			if material_name == &"hero_hair":
				checked_hair += 1
			else:
				checked_beard += 1
	assert_true(checked_hair > 0, "hero hair must use the shared hair shader")
	assert_true(checked_beard > 0, "hero beard must use the shared hair shader")
	assert_true(kalev.lod_mesh_count(1) > 0 and kalev.lod_mesh_count(2) > 0)
	kalev.queue_free()


func test_shared_character_material_profiles_separate_cloth_leather_and_metal() -> void:
	var kalev := _instantiate(KALEV_SCENE)
	var henning := _instantiate(HENNING_SCENE)
	var profiles := {}
	for character: Node in [kalev, henning]:
		for found: Node in character.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := found as MeshInstance3D
			if mesh_instance == null or mesh_instance.mesh == null:
				continue
			for surface_index: int in mesh_instance.mesh.get_surface_count():
				var source_material := mesh_instance.mesh.surface_get_material(surface_index)
				if source_material == null:
					continue
				var material_name := StringName(source_material.resource_name)
				var active := mesh_instance.get_active_material(surface_index)
				if not (active is BaseMaterial3D) or not SharedCharacterRig.CHARACTER_PBR_MATERIAL_PROFILES.has(material_name):
					continue
				var material := active as BaseMaterial3D
				assert_ne(
					material.shading_mode,
					BaseMaterial3D.SHADING_MODE_UNSHADED,
					"%s must receive dynamic lighting" % material_name
				)
				var profile: Dictionary = SharedCharacterRig.CHARACTER_PBR_MATERIAL_PROFILES[material_name]
				var expected_roughness: float = profile["roughness"]
				var expected_metallic: float = profile["metallic"]
				assert_true(is_equal_approx(material.roughness, expected_roughness))
				assert_true(is_equal_approx(material.metallic, expected_metallic))
				profiles[profile["family"]] = material
				assert_true(material.albedo_texture != null, "%s must preserve its albedo map" % material_name)
				assert_true(material.normal_texture != null, "%s must preserve its normal map" % material_name)
				assert_true(material.roughness_texture != null, "%s must preserve its roughness map" % material_name)
	assert_true(profiles.has("cloth"), "cloth profile must be present")
	assert_true(profiles.has("leather"), "leather profile must be present")
	assert_true(profiles.has("metal"), "metal profile must be present")
	assert_true(profiles["cloth"].roughness > profiles["leather"].roughness)
	assert_true(profiles["leather"].roughness > profiles["metal"].roughness)
	assert_eq(profiles["cloth"].metallic, 0.0)
	assert_eq(profiles["leather"].metallic, 0.0)
	assert_true(profiles["metal"].metallic > 0.9)
	kalev.queue_free()
	henning.queue_free()


func test_shared_character_no_body_material_is_unshaded() -> void:
	var kalev := _instantiate(KALEV_SCENE)
	for found: Node in kalev.get_node("Model").find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := found as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		for surface_index: int in mesh_instance.mesh.get_surface_count():
			var active := mesh_instance.get_active_material(surface_index)
			if active is BaseMaterial3D:
				assert_ne(
					(active as BaseMaterial3D).shading_mode,
					BaseMaterial3D.SHADING_MODE_UNSHADED,
					"%s surface %d must not be unshaded" % [mesh_instance.name, surface_index]
				)
	kalev.queue_free()


func test_anatomical_muscle_volume_responds_to_joint_bend() -> void:
	var warrior := _instantiate(DANISH_WARRIOR_SCENE)
	var skeleton := warrior.skeleton()
	var muscles := skeleton.get_node("AnatomicalMuscles")
	var elbow := skeleton.find_bone("lowerarm.l")
	var upper_arm := skeleton.find_bone("upperarm.l")
	skeleton.set_bone_pose_rotation(elbow, Quaternion(Vector3.FORWARD, deg_to_rad(90.0)))
	muscles.call("_process_modification")
	var contracted := skeleton.get_bone_pose_scale(upper_arm)
	assert_true(
		contracted.x > 1.02 and contracted.z > 1.02,
		"bent arm must gain transverse muscle volume"
	)
	assert_true(contracted.y < 1.0, "bent arm muscle must shorten along the bone")
	warrior.queue_free()


func _shoulder_span(character: SharedCharacterRig) -> float:
	var skeleton := character.skeleton()
	var left := skeleton.get_bone_global_rest(skeleton.find_bone("upperarm.l")).origin
	var right := skeleton.get_bone_global_rest(skeleton.find_bone("upperarm.r")).origin
	return right.distance_to(left)


func _instantiate(scene: PackedScene) -> SharedCharacterRig:
	var character := scene.instantiate() as SharedCharacterRig
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(character)
	# Instanced rig scenes can receive their CharacterVariant export after _ready;
	# refresh materials once the export is present without remounting distance LODs.
	if character.variant != null:
		character._apply_material_stack(character.get_node("Model"), character.variant.material_tint)
	return character
