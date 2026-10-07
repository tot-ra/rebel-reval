extends "res://tests/godot/test_case.gd"

const WATCHMAN := preload("res://assets/characters/variants/watchman.tscn")


## The retargeted Death_A hips track used to end ~0.75 m up while the IK limb targets
## lay on the floor; the clip itself must now end with the hips at lying height.
func test_fall_clip_ends_with_hips_near_ground() -> void:
	var rig := WATCHMAN.instantiate() as SharedCharacterRig
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(rig)
	await tree.process_frame
	rig.play_animation(&"fall", 0.0)
	var player := rig.animation_player()
	player.seek(player.current_animation_length, true)
	var skeleton := rig.skeleton()
	skeleton.force_update_all_bone_transforms()
	var hips := skeleton.find_bone(&"hips")
	var hips_y := (skeleton.global_transform * skeleton.get_bone_global_pose(hips)).origin.y
	assert_true(hips_y < 0.3, "fallen hips should rest near the ground, got %.2f" % hips_y)
	rig.queue_free()
