extends "res://tests/godot/test_case.gd"

## IdleFootLock: the shared Idle clip sways the pelvis with unkeyed legs, so
## without the lock one foot slid ~10 cm and the other lifted. Both feet must
## stay on their rest stance through the whole clip, and the lock must release
## for walking.

const RIGS: Array[PackedScene] = [
	preload("res://assets/characters/kalev/kalev.tscn"),
	preload("res://assets/characters/variants/apprentice.tscn"),
]
## Rig-space tolerance: 1 cm sideways, 4 mm vertical (clip breathing lifts the
## pelvis a few millimetres beyond full leg reach before the pelvis drop).
const SLIDE_TOLERANCE := 0.01
const LIFT_TOLERANCE := 0.004
const SAMPLES := 12


func test_feet_stay_planted_through_idle() -> void:
	for scene: PackedScene in RIGS:
		var rig := scene.instantiate() as SharedCharacterRig
		(Engine.get_main_loop() as SceneTree).root.add_child(rig)
		assert_true(rig.play_animation(&"idle", 0.0))
		assert_almost_eq(rig.idle_foot_lock_weight(), 1.0, 0.001)
		var player := rig.animation_player()
		var length := player.current_animation_length
		var start: Dictionary = {}
		for sample: int in SAMPLES + 1:
			var feet := _sample_feet(rig, length * sample / SAMPLES)
			if sample == 0:
				start = feet
				continue
			for foot: StringName in feet:
				var moved: Vector3 = feet[foot] - start[foot]
				assert_true(
					Vector2(moved.x, moved.z).length() < SLIDE_TOLERANCE,
					(
						"%s %s slid %.3f at sample %d"
						% [scene.resource_path, foot, Vector2(moved.x, moved.z).length(), sample]
					)
				)
				assert_true(
					absf(moved.y) < LIFT_TOLERANCE,
					"%s %s lifted %.3f at sample %d" % [scene.resource_path, foot, moved.y, sample]
				)
		SharedCharacterRig._detach_render_geometry(rig)
		rig.free()


func test_lock_releases_for_walking() -> void:
	var rig := RIGS[0].instantiate() as SharedCharacterRig
	(Engine.get_main_loop() as SceneTree).root.add_child(rig)
	assert_true(rig.play_animation(&"walk", 0.0))
	assert_almost_eq(rig.idle_foot_lock_weight(), 0.0, 0.001)
	assert_true(rig.play_animation(&"idle", 0.0))
	assert_almost_eq(rig.idle_foot_lock_weight(), 1.0, 0.001)
	SharedCharacterRig._detach_render_geometry(rig)
	rig.free()


## Foot bone origins in rig space after the skeleton modifiers ran at `time`.
## WHY the signal: since Godot 4.3 the modified pose is only readable inside
## skeleton_updated; afterwards the skeleton restores the animated pose.
func _sample_feet(rig: SharedCharacterRig, time: float) -> Dictionary:
	var player := rig.animation_player()
	player.seek(time, true)
	player.advance(0.0)
	var skeleton := rig.skeleton()
	skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	var feet := {}
	var capture := func() -> void:
		for foot: StringName in [
			SharedCharacterRig.LEFT_FOOT_BONE, SharedCharacterRig.RIGHT_FOOT_BONE
		]:
			var index := skeleton.find_bone(String(foot))
			feet[foot] = rig.to_local(
				skeleton.to_global(skeleton.get_bone_global_pose(index).origin)
			)
	skeleton.skeleton_updated.connect(capture)
	skeleton.advance(0.0)
	skeleton.skeleton_updated.disconnect(capture)
	return feet
