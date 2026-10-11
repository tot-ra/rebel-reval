class_name SwimStrokeModifier
extends SkeletonModifier3D

## Procedural swim pose for the shared humanoid rig (ADR 0021). The library has no
## swim clips, so limb directions are solved here on top of the AnimationPlayer
## pose: each arm and leg bone is aimed along a direction that comes from a stroke
## phase, keeping the clip's own twist by rotating with the shortest arc.
##
## Directions are in rig space before the presenter pitches the body: +Y is toward
## the head (forward while swimming prone), +Z is the chest side (down into the
## water while prone), -Z is the back (up out of the water), +X is the character's
## left. `influence` (SkeletonModifier3D) blends the whole pose in and out.

enum Style { CRAWL, TREAD }

const LEFT := 1.0
const RIGHT := -1.0
## Kick amplitude in radians and the fraction the shin lags behind the thigh.
const KICK_AMPLITUDE := 0.42
const SHIN_LAG := 0.9
## Crawl arm sweep: how far the elbow rises above the shoulder during recovery.
const RECOVERY_ELBOW_BEND := 1.25
const PULL_ELBOW_BEND := 0.35

var style: Style = Style.CRAWL
## Stroke phase in radians. The owner advances it at the current stroke rate.
var phase := 0.0
## The rig's Model node: its frame is the "rig space" above (it carries the pitch, so
## directions stay pre-pitch); skeleton space is derived from it.
var rig: Node3D

var _bones: Dictionary = {}


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or rig == null:
		return
	if _bones.is_empty():
		_resolve_bones(skeleton)
		if _bones.is_empty():
			return
	# Rig-space direction -> skeleton-space direction.
	var to_skeleton := (
		skeleton.global_transform.basis.orthonormalized().inverse()
		* rig.global_transform.basis.orthonormalized()
	)
	for side: float in [LEFT, RIGHT]:
		var suffix := "l" if side == LEFT else "r"
		var arm := _arm_directions(side)
		_aim(skeleton, _bones["upperarm." + suffix], to_skeleton * arm[0])
		_aim(skeleton, _bones["lowerarm." + suffix], to_skeleton * arm[1])
		var leg := _leg_directions(side)
		_aim(skeleton, _bones["upperleg." + suffix], to_skeleton * leg[0])
		_aim(skeleton, _bones["lowerleg." + suffix], to_skeleton * leg[1])


func _resolve_bones(skeleton: Skeleton3D) -> void:
	for bone_name: String in [
		"upperarm.l", "lowerarm.l", "upperarm.r", "lowerarm.r",
		"upperleg.l", "lowerleg.l", "upperleg.r", "lowerleg.r",
	]:
		var index := skeleton.find_bone(bone_name)
		if index < 0:
			_bones.clear()
			return
		_bones[bone_name] = index


## Aims the bone's +Y (toward its child joint) along `direction`, keeping its twist.
func _aim(skeleton: Skeleton3D, bone: int, direction: Vector3) -> void:
	var global := skeleton.get_bone_global_pose(bone)
	var current := global.basis.y.normalized()
	var wanted := direction.normalized()
	if current.is_zero_approx() or wanted.is_zero_approx():
		return
	var turn := Basis(Quaternion(current, wanted))
	var aimed := turn * global.basis.orthonormalized()
	var parent := skeleton.get_bone_parent(bone)
	var parent_basis := Basis.IDENTITY
	if parent >= 0:
		parent_basis = skeleton.get_bone_global_pose(parent).basis.orthonormalized()
	skeleton.set_bone_pose_rotation(bone, (parent_basis.inverse() * aimed).get_rotation_quaternion())


## Upper-arm and forearm directions (rig space) for one side.
func _arm_directions(side: float) -> Array[Vector3]:
	if style == Style.TREAD:
		# Sculling: forearms sweep out and in a little in front of the chest.
		var scull := sin(phase * 2.0 + (0.0 if side == LEFT else PI))
		var upper := Vector3(side * (0.55 + 0.12 * scull), -0.72, 0.42)
		var lower := Vector3(side * (0.75 + 0.3 * scull), -0.3, 0.75)
		return [upper, lower]
	# Crawl: the two arms are half a cycle apart. phi 0 = hand overhead, pull under
	# the chest (through +Z) to the hip at PI, then the elbow-high recovery over the
	# back (through -Z) back to the head.
	var phi := phase + (0.0 if side == LEFT else PI)
	var recovering := maxf(-sin(phi), 0.0)
	var reach := Vector3(side * (0.14 + 0.32 * recovering), cos(phi), sin(phi))
	var bend := lerpf(PULL_ELBOW_BEND, RECOVERY_ELBOW_BEND, recovering)
	var fore_phi := phi - bend
	var fore := Vector3(side * (0.10 + 0.25 * recovering), cos(fore_phi), sin(fore_phi))
	return [reach, fore]


## Thigh and shin directions (rig space) for one side.
func _leg_directions(side: float) -> Array[Vector3]:
	var kick_phase := phase * 3.0 + (0.0 if side == LEFT else PI)
	if style == Style.TREAD:
		# Slow bicycle kick, knees forward (+Z) and back.
		var swing := 0.55 * sin(phase * 1.5 + (0.0 if side == LEFT else PI))
		var thigh := Vector3(side * 0.12, -cos(swing), sin(swing))
		var shin_swing := swing - 0.7 + 0.45 * sin(phase * 1.5 + 1.2)
		return [thigh, Vector3(side * 0.10, -cos(shin_swing), sin(shin_swing))]
	# Flutter kick: a positive angle lifts the leg toward the back (-Z, up while prone).
	var angle := KICK_AMPLITUDE * sin(kick_phase)
	var shin_angle := angle * 1.3 + 0.18 * sin(kick_phase - SHIN_LAG)
	return [
		Vector3(side * 0.07, -cos(angle), -sin(angle)),
		Vector3(side * 0.05, -cos(shin_angle), -sin(shin_angle)),
	]
