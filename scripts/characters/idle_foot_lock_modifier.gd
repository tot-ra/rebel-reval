extends SkeletonModifier3D

## Plants both feet while a humanoid rig stands in its idle clip.
##
## WHY: the shared Idle clip was retargeted with tracks only on the hips and the
## spine. The legs had no keys, so they rode the swaying pelvis as one rigid
## piece: one foot slid ~10 cm sideways and the other lifted off the floor, and
## the character read as hovering. This modifier solves a two-bone IK per leg
## (upperleg -> lowerleg -> foot) toward the foot's rest transform, which is the
## idle stance at frame 0, and keeps the foot sole at its rest orientation. When
## the clip lifts the pelvis past full leg reach (a few millimetres at the top of
## the breath), the pelvis is lowered by that excess so the soles stay down.
##
## The rig sets `target_weight` (1 in idle, 0 otherwise); `influence` follows it
## over `blend_sec` so the lock fades in and out with the animation cross-fade.

## Per leg: thigh, shin and foot bone names (left leg first).
const LEGS: Array[Array] = [
	["upperleg.l", "lowerleg.l", "foot.l"],
	["upperleg.r", "lowerleg.r", "foot.r"],
]
const HIPS_BONE := "hips"
## The solve keeps the knee this far (skeleton units) short of full extension so
## the bend plane, and with it the knee direction, stays stable.
const REACH_MARGIN := 0.002
## Knees bend toward the character's front; the imported rig faces +Z.
const KNEE_POLE := Vector3(0.0, 0.0, 1.0)

var target_weight := 0.0:
	set(value):
		target_weight = value
		# Only tick while fading; idle crowds settle and stop processing.
		set_process(not is_equal_approx(influence, value))
var blend_sec := 0.18

var _hips := -1
var _legs: Array[PackedInt32Array] = []
var _anchors: Array[Transform3D] = []
var _resolved := false


func _ready() -> void:
	influence = 0.0
	active = false
	set_process(not is_equal_approx(influence, target_weight))


func _process(delta: float) -> void:
	if blend_sec <= 0.0:
		influence = target_weight
	else:
		influence = move_toward(influence, target_weight, delta / blend_sec)
	# Inactive modifiers cost nothing; walking crowds never run the solve.
	active = influence > 0.0
	if is_equal_approx(influence, target_weight):
		set_process(false)


## Jumps straight to `weight` (used when the rig snaps a clip with zero blend).
func snap_to(weight: float) -> void:
	influence = weight
	target_weight = weight
	active = weight > 0.0


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	if not _resolved:
		_resolve(skeleton)
	if _legs.is_empty():
		return
	_lower_hips_to_reach(skeleton)
	for side: int in _legs.size():
		_solve_leg(skeleton, _legs[side], _anchors[side])


func _resolve(skeleton: Skeleton3D) -> void:
	_resolved = true
	_hips = skeleton.find_bone(HIPS_BONE)
	if _hips < 0:
		return
	for names: Array in LEGS:
		var bones := PackedInt32Array()
		for bone_name: String in names:
			var index := skeleton.find_bone(bone_name)
			if index < 0:
				_legs.clear()
				_anchors.clear()
				return
			bones.append(index)
		_legs.append(bones)
		var rest := skeleton.get_bone_global_rest(bones[2])
		_anchors.append(Transform3D(rest.basis.orthonormalized(), rest.origin))


## Pelvis drop (skeleton space) needed so the farther foot anchor is reachable.
func _lower_hips_to_reach(skeleton: Skeleton3D) -> void:
	var excess := 0.0
	for side: int in _legs.size():
		var bones := _legs[side]
		var hip := skeleton.get_bone_global_pose(bones[0]).origin
		var knee := skeleton.get_bone_global_pose(bones[1]).origin
		var ankle := skeleton.get_bone_global_pose(bones[2]).origin
		var reach := (knee - hip).length() + (ankle - knee).length() - REACH_MARGIN
		var offset := _anchors[side].origin - hip
		var horizontal := Vector2(offset.x, offset.z).length()
		if horizontal >= reach:
			continue
		# Height the hip may sit above the anchor with the leg at full reach.
		var allowed := sqrt(reach * reach - horizontal * horizontal)
		excess = maxf(excess, offset.y * -1.0 - allowed)
	if excess <= 0.0:
		return
	var parent := skeleton.get_bone_parent(_hips)
	var parent_pose := Transform3D.IDENTITY
	if parent >= 0:
		parent_pose = skeleton.get_bone_global_pose(parent)
	var hips_origin := skeleton.get_bone_global_pose(_hips).origin - Vector3(0.0, excess, 0.0)
	skeleton.set_bone_pose_position(_hips, parent_pose.affine_inverse() * hips_origin)


func _solve_leg(skeleton: Skeleton3D, bones: PackedInt32Array, anchor: Transform3D) -> void:
	var hip := skeleton.get_bone_global_pose(bones[0]).origin
	var knee := skeleton.get_bone_global_pose(bones[1]).origin
	var ankle := skeleton.get_bone_global_pose(bones[2]).origin
	var thigh := (knee - hip).length()
	var shin := (ankle - knee).length()
	var to_target := anchor.origin - hip
	if thigh <= 0.0 or shin <= 0.0 or to_target.is_zero_approx():
		return
	var direction := to_target.normalized()
	var distance := clampf(
		to_target.length(), absf(thigh - shin) + REACH_MARGIN, thigh + shin - REACH_MARGIN
	)
	var bend := KNEE_POLE - direction * KNEE_POLE.dot(direction)
	if bend.is_zero_approx():
		return
	bend = bend.normalized()
	# Law of cosines: angle at the hip between the hip->ankle line and the thigh.
	var cos_hip := clampf(
		(thigh * thigh + distance * distance - shin * shin) / (2.0 * thigh * distance), -1.0, 1.0
	)
	var solved_knee := (
		hip + direction * (thigh * cos_hip) + bend * (thigh * sqrt(1.0 - cos_hip * cos_hip))
	)
	var solved_ankle := hip + direction * distance
	_aim(skeleton, bones[0], solved_knee - hip)
	_aim(skeleton, bones[1], solved_ankle - solved_knee)
	# Sole flat at its rest orientation regardless of the new shin angle.
	var shin_basis := skeleton.get_bone_global_pose(bones[1]).basis.orthonormalized()
	skeleton.set_bone_pose_rotation(
		bones[2], (shin_basis.inverse() * anchor.basis).get_rotation_quaternion()
	)


## Aims the bone's +Y (toward its child joint) along `direction`, keeping its
## twist (same contract as SwimStrokeModifier._aim).
func _aim(skeleton: Skeleton3D, bone: int, direction: Vector3) -> void:
	var global := skeleton.get_bone_global_pose(bone)
	var current := global.basis.y.normalized()
	var wanted := direction.normalized()
	if current.is_zero_approx() or wanted.is_zero_approx():
		return
	var aimed := Basis(Quaternion(current, wanted)) * global.basis.orthonormalized()
	var parent := skeleton.get_bone_parent(bone)
	var parent_basis := Basis.IDENTITY
	if parent >= 0:
		parent_basis = skeleton.get_bone_global_pose(parent).basis.orthonormalized()
	skeleton.set_bone_pose_rotation(
		bone, (parent_basis.inverse() * aimed).get_rotation_quaternion()
	)
