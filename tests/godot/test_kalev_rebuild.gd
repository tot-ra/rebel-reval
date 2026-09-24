extends "res://tests/godot/test_case.gd"

const DIR := "res://assets/characters/kalev_fresh/"
var rig: SharedCharacterRig

func before_each() -> void:
	super.before_each()
	rig = load(DIR + "kalev_fresh.tscn").instantiate() as SharedCharacterRig
	(Engine.get_main_loop() as SceneTree).root.add_child(rig)

func after_each() -> void:
	SharedCharacterRig._detach_render_geometry(rig)
	rig.free()

func _visible(prefix: String) -> bool:
	for found: Node in rig.find_children("*", "MeshInstance3D", true, false):
		if String(found.name).begins_with(prefix):
			return (found as MeshInstance3D).visible
	fail("Missing body region: " + prefix)
	return false

func test_fresh_body_keeps_character_identity_and_all_runtime_motions() -> void:
	assert_eq(rig.variant_id(), &"char.kalev")
	assert_eq(rig.body_basename(), "kalev_fresh")
	assert_eq(rig.validation_errors(), [])
	for motion: StringName in rig.canonical_animation_names():
		rig.play_animation(motion, 0.0)
		var player := rig.animation_player()
		player.seek(player.current_animation_length * 0.4, true)
		assert_eq(rig.current_canonical_animation(), motion)
		for i: int in rig.skeleton().get_bone_count():
			var pose := rig.skeleton().get_bone_global_pose(i)
			assert_true(pose.is_finite(), "Finite pose: %s bone %d" % [motion, i])

func test_fitted_layers_swap_without_replacing_body_or_animation() -> void:
	var skeleton_id := rig.skeleton().get_instance_id()
	rig.play_animation(&"walk")
	for garment: String in ["linen_shirt", "wool_tunic", "mail_shirt"]:
		var wearable := load(DIR + garment + ".tres") as CharacterWearable
		assert_true(rig.equip_wearable(wearable))
		assert_eq(rig.equipped_wearable(&"torso"), wearable)
		assert_false(_visible("Anatomy_Torso"))
		assert_false(_visible("Anatomy_Arms"))
		assert_true(_visible("Anatomy_Hands"))
		assert_true(_visible("Anatomy_Head"))
		assert_eq(rig.skeleton().get_instance_id(), skeleton_id)
		assert_eq(rig.current_canonical_animation(), &"walk")
	rig.unequip_wearable(&"torso")
	assert_true(_visible("Anatomy_Torso"))
	assert_true(_visible("Anatomy_Arms"))

func test_overlap_coverage_and_invalid_fit_preserve_equipment() -> void:
	var hose := load(DIR + "hose.tres") as CharacterWearable
	var boots := load(DIR + "boots.tres") as CharacterWearable
	assert_true(rig.equip_wearable(hose))
	assert_true(rig.equip_wearable(boots))
	rig.unequip_wearable(&"legs")
	assert_false(_visible("Anatomy_Calves"), "Boots still cover lower calf")
	assert_true(_visible("Anatomy_Legs"))
	assert_true(_visible("Clothing_Braies"))
	var invalid := boots.duplicate() as CharacterWearable
	invalid.fitted_body = "different_body"
	assert_false(rig.equip_wearable(invalid))
	assert_eq(rig.equipped_wearable(&"feet"), boots)
	rig.unequip_wearable(&"feet")
	assert_true(_visible("Anatomy_Calves"))
	assert_true(_visible("Anatomy_Feet"))

func test_weapon_swaps_use_same_live_hand_socket() -> void:
	var first := rig.equip(&"right_hand", load(DIR + "hammer/hammer.glb") as PackedScene)
	assert_true(first != null)
	var socket := first.get_parent() as BoneAttachment3D
	assert_eq(socket.bone_name, "handslot.r")
	var second := rig.equip(&"right_hand", load(DIR + "sword/sword.glb") as PackedScene)
	assert_true(second != null)
	assert_eq(second.get_parent(), socket)
	assert_eq(rig.equipped(&"right_hand"), second)
	rig.unequip(&"right_hand")
	assert_eq(rig.equipped(&"right_hand"), null)

func test_wardrobe_meshes_have_identical_rest_skeleton_and_named_bindings() -> void:
	for garment: String in ["linen_shirt", "wool_tunic", "mail_shirt", "smith_apron", "hose", "boots"]:
		var source := (load(DIR + garment + "/" + garment + ".glb") as PackedScene).instantiate()
		var skeleton := rig._find_skeleton(source)
		assert_true(skeleton != null)
		assert_eq(skeleton.get_bone_count(), rig.skeleton().get_bone_count())
		for i: int in skeleton.get_bone_count():
			assert_eq(skeleton.get_bone_name(i), rig.skeleton().get_bone_name(i))
			assert_true(skeleton.get_bone_rest(i).is_equal_approx(rig.skeleton().get_bone_rest(i)))
		for found: Node in source.find_children("*", "MeshInstance3D", true, false):
			var mesh := found as MeshInstance3D
			assert_true(mesh.skin != null, "Skinned garment: " + garment)
		source.free()

func test_motion_tracks_change_pose_instead_of_only_carrying_clip_names() -> void:
	for motion: StringName in [&"walk", &"run", &"hammer_attack"]:
		rig.play_animation(motion, 0.0)
		var player := rig.animation_player()
		player.speed_scale = 0.0
		player.seek(0.12, true)
		player.advance(0.0)
		rig.skeleton().force_update_all_bone_transforms()
		var before: Array[Transform3D] = []
		for i: int in rig.skeleton().get_bone_count():
			before.append(rig.skeleton().get_bone_global_pose(i))
		player.seek(0.52, true)
		player.advance(0.0)
		rig.skeleton().force_update_all_bone_transforms()
		var changed := false
		for i: int in rig.skeleton().get_bone_count():
			if not before[i].is_equal_approx(rig.skeleton().get_bone_global_pose(i)):
				changed = true
		assert_true(changed, "Animated pose changes for " + String(motion))

func test_preview_keyboard_and_gamepad_equipment_paths() -> void:
	var preview := (load(DIR + "preview.tscn") as PackedScene).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(preview)
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_3
	preview._unhandled_input(key)
	assert_eq(preview.outfit_index, 2)
	assert_eq(preview.rig.equipped_wearable(&"torso").stable_id, &"wearable.kalev_fresh.wool_tunic")
	key.keycode = KEY_W
	preview._unhandled_input(key)
	assert_true(preview.rig.has_equipment())
	var button := InputEventJoypadButton.new()
	button.pressed = true
	button.button_index = JOY_BUTTON_A
	preview._unhandled_input(button)
	assert_eq(preview.outfit_index, 3)
	button.button_index = JOY_BUTTON_Y
	preview._unhandled_input(button)
	assert_eq(preview.weapon_index, 2)
	button.button_index = JOY_BUTTON_RIGHT_SHOULDER
	preview._unhandled_input(button)
	assert_eq(preview.rig.current_canonical_animation(), &"walk")
	SharedCharacterRig._detach_render_geometry(preview)
	preview.free()
