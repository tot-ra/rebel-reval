extends "res://tests/godot/test_case.gd"

## ADR 0056 step 0: the human rig has a neck, collarbones and an upper spine joint
## (tools/assets/realistic_humans/rig_detail.py); the clips use them and the style layer
## drives them.

const LIVE_KALEV := preload("res://assets/characters/kalev/kalev.tscn")
const MotionStyleModifier := preload("res://scripts/characters/motion_style_modifier.gd")

var rig: SharedCharacterRig


func before_each() -> void:
	super.before_each()
	rig = LIVE_KALEV.instantiate() as SharedCharacterRig
	(Engine.get_main_loop() as SceneTree).root.add_child(rig)


func after_each() -> void:
	SharedCharacterRig._detach_render_geometry(rig)
	rig.free()
	super.after_each()


func _parent(bone: String) -> String:
	var skeleton := rig.skeleton()
	return skeleton.get_bone_name(skeleton.get_bone_parent(skeleton.find_bone(bone)))


func _clip(clip: String) -> String:
	for name: StringName in rig.animation_player().get_animation_list():
		if String(name).get_file() == clip or String(name).ends_with("/" + clip):
			return String(name)
	return ""


func test_detail_bones_split_the_trunk_neck_and_shoulders() -> void:
	assert_eq(_parent("spine_upper"), "spine")
	assert_eq(_parent("chest"), "spine_upper")
	assert_eq(_parent("neck"), "chest")
	assert_eq(_parent("head"), "neck")
	for side: String in ["l", "r"]:
		assert_eq(_parent("shoulder." + side), "chest")
		assert_eq(_parent("upperarm." + side), "shoulder." + side)


func test_raised_arms_lift_the_collarbones_in_the_clips() -> void:
	var skeleton := rig.skeleton()
	var player := rig.animation_player()
	var clip := _clip("Cheer")
	assert_ne(clip, "")
	var shoulder := skeleton.find_bone("shoulder.l")
	var hand := skeleton.find_bone("hand.l")
	# The frame with the highest left hand: the collarbone must have turned away from rest.
	var best_angle := 0.0
	var best_height := -INF
	var length := player.get_animation(clip).length
	for k in 12:
		player.play(clip)
		player.seek(length * k / 12.0, true)
		player.pause()
		skeleton.force_update_all_bone_transforms()
		var h := skeleton.get_bone_global_pose(hand).origin.y
		if h > best_height:
			best_height = h
			best_angle = skeleton.get_bone_pose_rotation(shoulder).get_angle()
	assert_true(
		best_angle > deg_to_rad(4.0),
		"collarbone %.1f deg at the raised arm" % rad_to_deg(best_angle)
	)


func test_style_shrug_lifts_the_shoulders() -> void:
	var skeleton := rig.skeleton()
	rig.play_animation(&"idle", 0.0)
	rig.animation_player().seek(0.0, true)
	rig.animation_player().pause()
	skeleton.force_update_all_bone_transforms()
	var arm := skeleton.find_bone("upperarm.l")
	var before := skeleton.get_bone_global_pose(arm).origin
	var modifier := MotionStyleModifier.new()
	skeleton.add_child(modifier)
	modifier.rig = rig
	modifier.style = {"shrug": 1.0}
	modifier._process_modification()
	var after := skeleton.get_bone_global_pose(arm).origin
	assert_true(after.y - before.y > 0.01, "shoulder rose %.3f m" % (after.y - before.y))
	modifier.queue_free()
