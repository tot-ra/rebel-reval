extends "res://tests/godot/test_case.gd"

## tools/assets/realistic_humans/run_cycle.py replaced the inherited run, whose
## feet landed ~23 cm off the midline and whose fists pumped mostly up and down.

const KALEV_SCENE := preload("res://assets/characters/kalev/kalev.tscn")
const FRAMES := 16
## The right foot carries the body from phase 0 to 0.27 (run_cycle.STANCE).
const RIGHT_STANCE_END := 0.25


func test_run_keeps_a_narrow_track_and_fore_aft_arm_swing() -> void:
	var kalev := KALEV_SCENE.instantiate() as SharedCharacterRig
	(Engine.get_main_loop() as SceneTree).root.add_child(kalev)
	var skeleton := kalev.skeleton()
	var player := kalev.animation_player()
	var animation := player.get_animation(&"Running_B")
	var hips := skeleton.find_bone("hips")
	var right_foot := skeleton.find_bone("foot.r")
	var right_hand := skeleton.find_bone("hand.r")
	var up := _rest(skeleton, "head") - _rest(skeleton, "hips")
	up = up.normalized()
	var forward := _rest(skeleton, "toes.r") - _rest(skeleton, "foot.r")
	forward = (forward - up * forward.dot(up)).normalized()
	var lateral := up.cross(forward).normalized()
	assert_true(kalev.play_animation(&"run", 0.0))

	var hand_forward: Array[float] = []
	var hand_up: Array[float] = []
	var stance_forward: Array[float] = []
	for frame: int in FRAMES:
		var phase := float(frame) / FRAMES
		player.seek(animation.length * phase, true)
		player.advance(0.0)
		skeleton.force_update_all_bone_transforms()
		var hips_pose := skeleton.get_bone_global_pose(hips).origin
		var foot := skeleton.get_bone_global_pose(right_foot).origin
		var hand := skeleton.get_bone_global_pose(right_hand).origin - hips_pose
		hand_forward.append(hand.dot(forward))
		hand_up.append(hand.dot(up))
		if phase < RIGHT_STANCE_END:
			var off_midline := (foot - hips_pose).dot(lateral)
			assert_true(
				absf(off_midline) < 0.10,
				"stance foot must land near the midline (%.3f m)" % off_midline
			)
			stance_forward.append(foot.dot(forward))
	var fore_aft: float = hand_forward.max() - hand_forward.min()
	var vertical: float = hand_up.max() - hand_up.min()
	assert_true(
		vertical < 0.6 * fore_aft,
		"hands must swing mostly fore-aft (%.2f m up vs %.2f m)" % [vertical, fore_aft]
	)

	# The stance foot's backward slide is the clip's true ground speed; the rig's
	# playback reference must match it or the feet skate at runtime.
	var slide := (stance_forward[0] - stance_forward[-1]) * kalev.model_scale.x
	var slide_sec := animation.length * (stance_forward.size() - 1) / FRAMES
	var reference := kalev.locomotion_reference_speed(&"run")
	assert_true(
		absf(slide / slide_sec - reference) < 0.08 * reference,
		"run reference %.2f must match the foot slide %.2f" % [reference, slide / slide_sec]
	)
	SharedCharacterRig._detach_render_geometry(kalev)
	kalev.free()


func _rest(skeleton: Skeleton3D, bone: String) -> Vector3:
	return skeleton.get_bone_global_rest(skeleton.find_bone(bone)).origin
