extends "res://tests/godot/test_case.gd"

const LIVE_KALEV := preload("res://assets/characters/kalev/kalev.tscn")
const FRESH_DIR := "res://assets/characters/kalev_rebuild/"

var rig: SharedCharacterRig


func before_each() -> void:
	super.before_each()
	rig = LIVE_KALEV.instantiate() as SharedCharacterRig
	(Engine.get_main_loop() as SceneTree).root.add_child(rig)


func after_each() -> void:
	SharedCharacterRig._detach_render_geometry(rig)
	rig.free()


func test_stable_live_scene_uses_fresh_body_and_identity() -> void:
	assert_eq(rig.variant_id(), &"char.kalev")
	assert_eq(rig.body_basename(), "kalev_fresh")
	assert_eq(rig.validation_errors(), [])
	assert_true(rig.get_node_or_null("HealthRing") != null)
	for old_path: String in [
		"res://assets/storybook/kalev.glb",
		"res://assets/characters/shared/heroic_humanoid.glb",
	]:
		assert_false(_live_scene_source().contains(old_path), "Live scene must not reference " + old_path)


func test_live_kalev_starts_in_fitted_forge_outfit() -> void:
	var expected := {
		&"torso": &"wearable.kalev_fresh.linen_shirt",
		&"outerwear": &"wearable.kalev_fresh.smith_apron",
		&"legs": &"wearable.kalev_fresh.hose",
		&"feet": &"wearable.kalev_fresh.boots",
	}
	for slot: StringName in expected:
		var wearable := rig.equipped_wearable(slot)
		assert_true(wearable != null, "Live outfit must fill %s" % slot)
		assert_eq(wearable.stable_id, expected[slot])
		assert_eq(wearable.fitted_body, "kalev_fresh")


func test_live_outfit_survives_animation_and_weapon_hot_swap() -> void:
	var skeleton_id := rig.skeleton().get_instance_id()
	assert_true(rig.play_animation(&"run", 0.0))
	var hammer := rig.equip(&"right_hand", load(FRESH_DIR + "hammer.glb") as PackedScene)
	assert_true(hammer != null)
	assert_eq(rig.equipped_wearable(&"torso").stable_id, &"wearable.kalev_fresh.linen_shirt")
	var sword := rig.equip(&"right_hand", load(FRESH_DIR + "sword.glb") as PackedScene)
	assert_true(sword != null)
	assert_eq(rig.equipped(&"right_hand"), sword)
	assert_eq(rig.skeleton().get_instance_id(), skeleton_id)
	assert_eq(rig.current_canonical_animation(), &"run")
	assert_eq((sword.get_parent() as BoneAttachment3D).bone_name, "handslot.r")


func test_fresh_walk_and_run_emit_one_contact_per_half_cycle() -> void:
	for motion: StringName in [&"walk", &"run"]:
		assert_true(rig.play_animation(motion, 0.0))
		var player := rig.animation_player()
		var contacts: Array[StringName] = []
		for phase: float in [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9]:
			player.seek(player.current_animation_length * phase, true)
			var contact := rig.consume_foot_plant()
			if not contact.is_empty():
				contacts.append(contact)
		assert_eq(
			contacts,
			[SharedCharacterRig.RIGHT_FOOT_BONE, SharedCharacterRig.LEFT_FOOT_BONE],
			"%s must emit exactly one contact per half-cycle" % motion
		)
		assert_true(rig.play_animation(&"idle", 0.0))
		assert_eq(rig.consume_foot_plant(), &"", "leaving locomotion clears contact state")


func _live_scene_source() -> String:
	return FileAccess.get_file_as_string("res://assets/characters/kalev/kalev.tscn")
