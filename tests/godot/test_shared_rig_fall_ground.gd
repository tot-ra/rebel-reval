extends "res://tests/godot/test_case.gd"

const WATCHMAN := preload("res://assets/characters/variants/watchman.tscn")


## Death_A ends with the hips ~0.75 m up; the rig must sink the model so the dead
## body lies on the ground instead of hovering.
func test_fallen_body_rests_near_ground() -> void:
	var rig := WATCHMAN.instantiate() as SharedCharacterRig
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(rig)
	await tree.process_frame
	rig.play_animation(&"fall", 0.0)
	var player := rig.animation_player()
	player.seek(player.current_animation_length, true)
	rig._sync_fall_ground_offset()
	rig._sync_fall_ground_offset()
	var hips := rig.skeleton().find_bone(&"hips")
	var skeleton := rig.skeleton()
	var hips_y := (skeleton.global_transform * skeleton.get_bone_global_pose(hips)).origin.y
	assert_true(hips_y < 0.3, "fallen hips should rest near the ground, got %.2f" % hips_y)
	rig.play_animation(&"idle", 0.0)
	rig._sync_fall_ground_offset()
	assert_true(is_zero_approx(rig.get_node("Model").position.y), "idle restores model offset")
	rig.queue_free()
