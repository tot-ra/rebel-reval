extends "res://tests/godot/test_case.gd"

## R-2036: a census watchman (kettle hat, spear) stood in a T-pose on icy ground outside the
## walls. The rig did play Idle; the motion style layer (ADR 0051) held both arms out for balance
## on ice although he stood still, swinging the spear hand sideways. Every armed kit must show its
## idle arms within a few frames of spawn, on ice as on dry ground.

const MotionEnvironment := preload("res://scripts/motion/motion_environment.gd")
const MotionStylePresenter := preload("res://scripts/motion/motion_style_presenter.gd")
const BODY := "citizen_m_adult_average"
const KITS: Array[String] = ["watch", "crown", "sergeant"]
## Frames after spawn by which the idle pose must hold (well under a second at 60 fps).
const SETTLE_FRAMES := 30
const FRAME_DT := 1.0 / 60.0

var _rigs: Array[SharedCharacterRig] = []


func after_each() -> void:
	for rig in _rigs:
		SharedCharacterRig._detach_render_geometry(rig)
		rig.free()
	_rigs.clear()
	MotionEnvironment.set_current(null)
	super.after_each()


func _icy_ground() -> RefCounted:
	var env: RefCounted = MotionEnvironment.new()
	env.air_temp_c = -6.0
	env.puddle_wetness = 0.9
	return env


func _spawn(kit: String) -> SharedCharacterRig:
	var scene := load("res://assets/characters/variants/%s.tscn" % BODY) as PackedScene
	var rig := scene.instantiate() as SharedCharacterRig
	(Engine.get_main_loop() as SceneTree).root.add_child(rig)
	_rigs.append(rig)
	if not kit.is_empty():
		CitizenGear.arm(rig, {"body": BODY, "wear": [], "duty": {"kit": kit}})
	return rig


## Skeleton-space hand positions after the modifier pass of the next frames, as the city does it:
## the presenter runs every frame with the resident standing (speed 0).
func _settle(rigs: Array[SharedCharacterRig], styled: Array[bool]) -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	for frame in SETTLE_FRAMES:
		for i in rigs.size():
			if styled[i]:
				MotionStylePresenter.humanoid(rigs[i], FRAME_DT, 0.0)
		await tree.process_frame
	# Modified poses exist only between the modifier pass and the next frame: read on the signal.
	var hands: Array = []
	hands.resize(rigs.size())
	var reads: Array[Callable] = []
	for i in rigs.size():
		var sk := rigs[i].skeleton()
		var read := func() -> void:
			hands[i] = [
				sk.get_bone_global_pose(sk.find_bone("hand.l")).origin,
				sk.get_bone_global_pose(sk.find_bone("hand.r")).origin,
			]
		sk.skeleton_updated.connect(read)
		reads.append(read)
	for frame in 2:
		for i in rigs.size():
			if styled[i]:
				MotionStylePresenter.humanoid(rigs[i], FRAME_DT, 0.0)
		await tree.process_frame
	for i in rigs.size():
		rigs[i].skeleton().skeleton_updated.disconnect(reads[i])
	return hands


func test_every_armed_kit_plays_idle_after_spawn() -> void:
	for kit in KITS:
		var rig := _spawn(kit)
		assert_true(rig.equipped(&"right_hand") != null, "%s: weapon mounted" % kit)
	await _settle(_rigs, [true, true, true])
	for i in KITS.size():
		var rig := _rigs[i]
		var player := rig.animation_player()
		assert_eq(rig.current_canonical_animation(), &"idle", "%s: canonical idle" % KITS[i])
		assert_true(player != null and player.is_playing(), "%s: AnimationPlayer runs" % KITS[i])
		assert_eq(
			StringName(player.current_animation),
			rig.source_animation_name(&"idle"),
			"%s: Idle clip assigned" % KITS[i]
		)


func test_armed_kit_standing_on_ice_keeps_the_idle_arms() -> void:
	MotionEnvironment.set_current(_icy_ground())
	# One styled resident per kit next to an unstyled reference body that plays the same Idle.
	var rigs: Array[SharedCharacterRig] = []
	var styled: Array[bool] = []
	for kit in KITS:
		rigs.append(_spawn(kit))
		styled.append(true)
	rigs.append(_spawn(""))
	styled.append(false)
	var hands: Array = await _settle(rigs, styled)
	var reference: Array = hands[KITS.size()]
	var sk := rigs[0].skeleton()
	var arm := (
		sk.get_bone_global_rest(sk.find_bone("hand.r")).origin
		- sk.get_bone_global_rest(sk.find_bone("upperarm.r")).origin
	).length()
	for i in KITS.size():
		var own: Array = hands[i]
		for side in 2:
			var drift := (own[side] as Vector3).distance_to(reference[side])
			assert_true(
				drift < 0.1 * arm,
				"%s %s hand at idle on ice: %.3f off (arm %.3f)"
					% [KITS[i], "left" if side == 0 else "right", drift, arm]
			)
		var modifier: Object = rigs[i].get_meta(MotionStylePresenter.MODIFIER_META)
		assert_true(bool(modifier.get(&"held_r")), "%s: weapon hand marked as held" % KITS[i])
