extends SkeletonModifier3D

## Condition-adaptive posture on the shared humanoid rig (ADR 0051, docs/SYSTEMS/MOTION_STYLE.md).
##
## Applies the style knobs of a `MotionStyleAgent` on top of whatever clip the AnimationPlayer
## plays:
## trunk pitch and roll (hunch, lean into the wind), crouch (knees bend, hips drop), head down,
## shoulders drawn up, arms held out for balance, an arm hugged across the chest, a hand pressed on
## the
## wound point, a limp (trunk leans off the sore leg while it carries) and shivering. Nothing here
## names a situation: ice, cold, a cut thigh or a gale differ only in the knob values the network
## gives.
##
## Rig space (the `rig` node's frame): +Y up, +Z the chest side (forward), +X the character's left,
## as in `SwimStrokeModifier`. `influence` fades the whole layer.

const LEFT := 1.0
const RIGHT := -1.0
const BONES: Array[String] = [
	"hips",
	"spine",
	"chest",
	"head",
	"upperarm.l",
	"lowerarm.l",
	"upperarm.r",
	"lowerarm.r",
	"upperleg.l",
	"lowerleg.l",
	"foot.l",
	"upperleg.r",
	"lowerleg.r",
	"foot.r",
]
const CROUCH_KNEE := 0.5
const TREMOR_RAD := 0.035

## Knob values {name: float}; usually `MotionStyleAgent.style` (shared, read every frame).
var style: Dictionary = {}
## Seated (a sit clip plays): the legs rest on the seat, so no crouch, stance or limp.
var seated := false
## The wound point in body coordinates (x front, y left, z 0..1 of the height), from the agent
## channels.
var wound := Vector3(0.0, 0.0, 0.5)
## The rig's Model node; its frame is rig space.
var rig: Node3D
## Share of `arm_out` applied, 0 standing .. 1 walking (MotionStylePresenter eases it by speed):
## arms go out to catch a slip in mid-stride; a person standing on ice keeps them down (R-2036).
## Starts at 0 so a rig spawned standing never flashes its arms out before the first ease.
var balance := 0.0
## A hand holding something (spear, sword, lantern, shield) keeps its clip pose instead of
## swinging out for balance; the prop would otherwise point sideways like a T-pose.
var held_l := false
var held_r := false

var _bones: Dictionary = {}
var _time := 0.0
var _height := 1.8


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or rig == null or style.is_empty():
		return
	if _bones.is_empty():
		_resolve_bones(skeleton)
		if _bones.is_empty():
			return
	_time += get_process_delta_time() if is_inside_tree() else 0.0
	var to_skel := (
		skeleton.global_transform.basis.orthonormalized().inverse()
		* rig.global_transform.basis.orthonormalized()
	)
	# Rig +X is the character's left; rotating about it pitches the trunk.
	var right_axis := to_skel * Vector3.RIGHT
	var fwd_axis := to_skel * Vector3.BACK  # rig +Z (forward)
	var up_axis := to_skel * Vector3.UP
	var pitch := float(style.get("trunk_pitch", 0.0))
	var roll := float(style.get("trunk_roll", 0.0))
	if not seated:
		roll += _limp_roll(skeleton, up_axis)
	var tremor := float(style.get("tremor", 0.0))
	var shiver := TREMOR_RAD * tremor
	# Trunk: half of the lean at the spine, half at the chest; positive pitch bows forward (about
	# +X).
	for b: String in ["spine", "chest"]:
		var tw := shiver * sin(_time * TAU * (9.0 if b == "spine" else 10.5))
		_rotate(skeleton, b, right_axis, 0.5 * pitch + tw)
		_rotate(skeleton, b, fwd_axis, -0.5 * roll)
	_rotate(
		skeleton,
		"head",
		right_axis,
		(
			0.45 * float(style.get("head_down", 0.0))
			+ 0.2 * float(style.get("shrug", 0.0))
			- 0.3 * pitch
		)
	)
	if not seated:
		_crouch(
			skeleton,
			right_axis,
			up_axis,
			float(style.get("crouch", 0.0)),
			float(style.get("width", 1.0)),
			fwd_axis
		)
	for side: float in [LEFT, RIGHT]:
		_arm(skeleton, side, to_skel, shiver)


func _resolve_bones(skeleton: Skeleton3D) -> void:
	for bone_name in BONES:
		var index := skeleton.find_bone(bone_name)
		if index < 0:
			_bones.clear()
			return
		_bones[bone_name] = index
	var head_y := skeleton.get_bone_global_rest(_bones["head"]).origin.y
	var foot_y := skeleton.get_bone_global_rest(_bones["foot.l"]).origin.y
	_height = maxf(0.3, (head_y - foot_y) * 1.08)


## Rotate a bone about a skeleton-space axis through its own origin, keeping its children attached.
func _rotate(skeleton: Skeleton3D, bone_name: String, axis: Vector3, angle: float) -> void:
	if absf(angle) < 1e-4:
		return
	var bone: int = _bones[bone_name]
	var global := skeleton.get_bone_global_pose(bone)
	var turned := Basis(axis.normalized(), angle) * global.basis.orthonormalized()
	_set_global_basis(skeleton, bone, turned)


func _set_global_basis(skeleton: Skeleton3D, bone: int, basis: Basis) -> void:
	var parent := skeleton.get_bone_parent(bone)
	var parent_basis := Basis.IDENTITY
	if parent >= 0:
		parent_basis = skeleton.get_bone_global_pose(parent).basis.orthonormalized()
	skeleton.set_bone_pose_rotation(
		bone, (parent_basis.inverse() * basis).get_rotation_quaternion()
	)


## Bend hips, knees and ankles by the same small angles so the feet keep their orientation, and drop
## the
## hips by what the bent legs lose in height. Width turns the thighs out a little.
func _crouch(
	skeleton: Skeleton3D,
	right_axis: Vector3,
	up_axis: Vector3,
	crouch: float,
	width: float,
	fwd_axis: Vector3
) -> void:
	if crouch < 0.01 and absf(width - 1.0) < 0.02:
		return
	var a := CROUCH_KNEE * crouch
	var thigh := (
		(
			skeleton.get_bone_global_rest(_bones["lowerleg.l"]).origin
			- skeleton.get_bone_global_rest(_bones["upperleg.l"]).origin
		)
		. length()
	)
	var shin := (
		(
			skeleton.get_bone_global_rest(_bones["foot.l"]).origin
			- skeleton.get_bone_global_rest(_bones["lowerleg.l"]).origin
		)
		. length()
	)
	var drop := (thigh + shin) * (1.0 - cos(a))
	var hips: int = _bones["hips"]
	var pose := skeleton.get_bone_pose_position(hips)
	var parent := skeleton.get_bone_parent(hips)
	var down := -up_axis
	if parent >= 0:
		down = skeleton.get_bone_global_pose(parent).basis.orthonormalized().inverse() * down
	skeleton.set_bone_pose_position(hips, pose + down * drop)
	var splay := 0.12 * (width - 1.0)
	for side: String in ["l", "r"]:
		var s := 1.0 if side == "l" else -1.0
		_rotate(skeleton, "upperleg." + side, right_axis, a)
		_rotate(skeleton, "upperleg." + side, fwd_axis, -s * splay)
		_rotate(skeleton, "lowerleg." + side, right_axis, -2.0 * a)
		_rotate(skeleton, "foot." + side, right_axis, a)


## While the sore leg carries (its foot is the lower one), the trunk leans away from it.
func _limp_roll(skeleton: Skeleton3D, up_axis: Vector3) -> float:
	var limp := float(style.get("limp", 0.0))
	if absf(limp) < 0.05:
		return 0.0
	var yl := skeleton.get_bone_global_pose(_bones["foot.l"]).origin.dot(up_axis)
	var yr := skeleton.get_bone_global_pose(_bones["foot.r"]).origin.dot(up_axis)
	var left_carries := clampf((yr - yl) / maxf(0.04 * _height, 1e-3), -1.0, 1.0)
	# limp > 0: the left side is sore; lean right (negative roll) while the left leg carries.
	return -0.12 * limp * maxf(0.0, left_carries if limp > 0.0 else -left_carries)


## Two-bone reach of one arm toward the blend of its goals (wound, hug, out), weighted by the knobs.
func _arm(skeleton: Skeleton3D, side: float, to_skel: Basis, shiver: float) -> void:
	var s := "l" if side == LEFT else "r"
	var press := float(style.get("press_" + ("L" if side == LEFT else "R"), 0.0))
	var hug := float(style.get("hug_" + ("L" if side == LEFT else "R"), 0.0))
	var held := held_l if side == LEFT else held_r
	var out := 0.0 if held else float(style.get("arm_out", 0.0)) * balance
	var wsum := press + hug + 0.8 * out
	var upper: int = _bones["upperarm." + s]
	var lower: int = _bones["lowerarm." + s]
	if wsum < 0.03:
		if shiver > 0.0:
			_rotate(
				skeleton,
				"upperarm." + s,
				to_skel * Vector3.BACK,
				shiver * sin(_time * TAU * 11.0 + side)
			)
		return
	var weight := minf(1.0, wsum)
	var from_rig := to_skel.inverse()
	var shoulder := skeleton.get_bone_global_pose(upper).origin
	var elbow := skeleton.get_bone_global_pose(lower).origin
	var a_len := (elbow - shoulder).length()
	var b_len := a_len * 1.05
	var h := _height
	var hips_o := skeleton.get_bone_global_pose(_bones["hips"]).origin
	var foot_y := (from_rig * skeleton.get_bone_global_pose(_bones["foot.l"]).origin).y
	# Goals in rig space, relative to the hips point.
	var base := from_rig * hips_o
	var sh_r := from_rig * shoulder
	var wound_r := Vector3(
		base.x + wound.y * 0.11 * h,
		foot_y + wound.z * h,
		base.z + maxf(wound.x, -0.6) * 0.09 * h + 0.03 * h
	)
	var chest_r := from_rig * skeleton.get_bone_global_pose(_bones["chest"]).origin
	var hug_r := chest_r + Vector3(-side * 0.09 * h, -0.04 * h, 0.12 * h)
	var out_r := (
		sh_r
		+ Vector3(side * 0.75 * (a_len + b_len), -0.3 * (a_len + b_len), 0.15 * (a_len + b_len))
	)
	var goal_r := (press * wound_r + hug * hug_r + 0.8 * out * out_r) / wsum
	var goal := to_skel * goal_r
	var to_goal := goal - shoulder
	var dist := clampf(to_goal.length(), 0.05, (a_len + b_len) * 0.98)
	var dir := to_goal.normalized()
	# Elbow out to the side and back, away from the body.
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


## Turn the bone's +Y (toward its child) toward `direction` by `weight`, keeping its twist.
func _aim(skeleton: Skeleton3D, bone: int, direction: Vector3, weight: float) -> void:
	var global := skeleton.get_bone_global_pose(bone)
	var current := global.basis.y.normalized()
	if current.is_zero_approx() or direction.is_zero_approx():
		return
	var full := Quaternion(current, direction.normalized())
	var turn := Basis(Quaternion.IDENTITY.slerp(full, clampf(weight, 0.0, 1.0)))
	_set_global_basis(skeleton, bone, turn * global.basis.orthonormalized())
