extends "res://scripts/characters/motion_style_modifier.gd"

## Pose of a context-aware jump on the shared humanoid rig (ADR 0053, docs/SYSTEMS/LEAPING.md),
## over the Jump_Start / Jump_Idle / Jump_Land clips: the crouch before take-off, legs tucked in
## the air, both hands on the wall top or the edge (vault, pull-up, hanging before a drop), the
## landing that gives at the knees, arms out, and the lean back of a refusal. The amounts are the
## leap network's knobs (`PlayerLeap.pose()`); the bone helpers are MotionStyleModifier's.

const PlayerLeap := preload("res://scripts/player/player_leap.gd")

## {phase, t, knobs, hand_point (world), has_hand_point}; empty = no jump.
var leap: Dictionary = {}


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or rig == null or leap.is_empty():
		return
	if _bones.is_empty():
		_resolve_bones(skeleton)
		if _bones.is_empty():
			return
	var to_skel := (
		skeleton.global_transform.basis.orthonormalized().inverse()
		* rig.global_transform.basis.orthonormalized()
	)
	var right_axis := to_skel * Vector3.RIGHT
	var fwd_axis := to_skel * Vector3.BACK
	var up_axis := to_skel * Vector3.UP
	var kn: Dictionary = leap.get("knobs", {})
	var t := float(leap.get("t", 0.0))
	var bell := sin(PI * clampf(t, 0.0, 1.0))
	match int(leap.get("phase", PlayerLeap.Phase.NONE)):
		PlayerLeap.Phase.CROUCH:
			var c := 1.4 * smoothstep(0.0, 1.0, t)
			_crouch(skeleton, right_axis, up_axis, c, 1.0, fwd_axis)
			_trunk(skeleton, right_axis, 0.3 * c)
			_arms_swing(skeleton, right_axis, -0.7 * c)
		PlayerLeap.Phase.LOWER:
			_trunk(skeleton, right_axis, 0.15)
			_hands_to(skeleton, to_skel, 1.0)
		PlayerLeap.Phase.FLIGHT:
			var w := float(leap.get("hand_weight", 0.0))
			_tuck(skeleton, right_axis, maxf(float(kn.get("tuck", 0.0)) * bell, w))
			_trunk(skeleton, right_axis, float(kn.get("lean", 0.1)) * t)
			if w > 0.0:
				# Over a vault the body dives forward onto the hands.
				_trunk(skeleton, right_axis, 0.7 * w)
				_hands_to(skeleton, to_skel, w)
			else:
				_arms_swing(skeleton, right_axis, 1.1 * (1.0 - t))
			_arms_out(skeleton, fwd_axis, float(kn.get("arms_out", 0.0)) * t)
		PlayerLeap.Phase.LAND:
			if float(kn.get("roll", 0.0)) > 0.5:
				return
			var flex := float(kn.get("flex", 0.3))
			var c := (0.4 + 1.2 * flex) * (1.0 - smoothstep(0.3, 1.0, t)) * smoothstep(0.0, 0.15, t)
			_crouch(skeleton, right_axis, up_axis, c, 1.15, fwd_axis)
			_trunk(skeleton, right_axis, 0.25 * c + float(kn.get("lean", 0.1)) * (1.0 - t))
			_arms_out(skeleton, fwd_axis, (0.3 + float(kn.get("arms_out", 0.0))) * (1.0 - t))
		PlayerLeap.Phase.REFUSE:
			# A balk at the edge: weight back, arms forward and out.
			_crouch(skeleton, right_axis, up_axis, 0.3 * bell, 1.1, fwd_axis)
			_trunk(skeleton, right_axis, -0.25 * bell)
			_arms_swing(skeleton, right_axis, 0.9 * bell)
			_arms_out(skeleton, fwd_axis, 0.6 * bell)


func _trunk(skeleton: Skeleton3D, right_axis: Vector3, pitch: float) -> void:
	for b: String in ["spine", "chest"]:
		_rotate(skeleton, b, right_axis, 0.5 * pitch)


## Thighs up and knees bent (legs drawn up under the body in the air).
func _tuck(skeleton: Skeleton3D, right_axis: Vector3, amount: float) -> void:
	if amount < 0.01:
		return
	for side: String in ["l", "r"]:
		_rotate(skeleton, "upperleg." + side, right_axis, 1.1 * amount)
		_rotate(skeleton, "lowerleg." + side, right_axis, -1.7 * amount)


## Both arms swung forward (+) or back (-) about the shoulders.
func _arms_swing(skeleton: Skeleton3D, right_axis: Vector3, angle: float) -> void:
	for side: String in ["l", "r"]:
		_rotate(skeleton, "upperarm." + side, right_axis, angle)


## Both arms raised to the side.
func _arms_out(skeleton: Skeleton3D, fwd_axis: Vector3, amount: float) -> void:
	if amount < 0.01:
		return
	_rotate(skeleton, "upperarm.l", fwd_axis, -1.1 * amount)
	_rotate(skeleton, "upperarm.r", fwd_axis, 1.1 * amount)


## Both hands to the world hand point, a shoulder width apart, by two-bone reach.
func _hands_to(skeleton: Skeleton3D, to_skel: Basis, weight: float) -> void:
	if weight < 0.01 or not bool(leap.get("has_hand_point", false)):
		return
	var world: Vector3 = leap["hand_point"]
	var centre: Vector3 = skeleton.global_transform.affine_inverse() * world
	for side: float in [LEFT, RIGHT]:
		var s := "l" if side == LEFT else "r"
		var goal := centre + to_skel * Vector3(side * 0.2, 0.03, 0.0)
		_reach(skeleton, s, side, goal, to_skel, weight)


func _reach(
	skeleton: Skeleton3D, s: String, side: float, goal: Vector3, to_skel: Basis, weight: float
) -> void:
	var upper: int = _bones["upperarm." + s]
	var lower: int = _bones["lowerarm." + s]
	var shoulder := skeleton.get_bone_global_pose(upper).origin
	var elbow := skeleton.get_bone_global_pose(lower).origin
	var a_len := (elbow - shoulder).length()
	var b_len := a_len * 1.05
	var to_goal := goal - shoulder
	var dist := clampf(to_goal.length(), 0.05, (a_len + b_len) * 0.98)
	var dir := to_goal.normalized()
	var pole := (to_skel * Vector3(side * 0.7, -0.4, -0.6)).normalized()
	var cos_a := clampf(
		(a_len * a_len + dist * dist - b_len * b_len) / (2.0 * a_len * dist), -1.0, 1.0
	)
	var bend_axis := dir.cross(pole).normalized()
	if bend_axis.is_zero_approx():
		bend_axis = to_skel * Vector3.RIGHT
	var upper_dir := Basis(bend_axis, -acos(cos_a)) * dir
	var elbow_goal := shoulder + upper_dir * a_len
	var fore_dir := (shoulder + dir * dist - elbow_goal).normalized()
	_aim(skeleton, upper, upper_dir, weight)
	_aim(skeleton, lower, fore_dir, weight)
