extends SkeletonModifier3D

## Condition-adaptive posture for the city's skinned animals (ADR 0051,
## docs/SYSTEMS/MOTION_STYLE.md).
##
## Works with any skeleton that has a few of the storybook bones (`Body`, `Head`, `Tail`, `Wing.L`,
## `Wing.R`): the body hunches and lowers, the head drops, the tail tucks, a bird's wings open for
## balance or close tight, fur and feathers fluff (a slight swelling of the body), the body leans
## off a
## sore leg and shivers. Missing bones are skipped. Directions are in the owner's frame
## (`frame_node`:
## -Z forward, +X right, +Y up, as `look_at` leaves a wandering animal).

## Knob values {name: float}; usually `MotionStyleAgent.style`.
var style: Dictionary = {}
var frame_node: Node3D

var _bones: Dictionary = {}
var _resolved := false
var _time := 0.0


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or frame_node == null or style.is_empty():
		return
	if not _resolved:
		_resolved = true
		for n: String in ["Body", "Head", "Tail", "Wing.L", "Wing.R"]:
			var i := skeleton.find_bone(n)
			if i >= 0:
				_bones[n] = i
	if _bones.is_empty():
		return
	_time += get_process_delta_time()
	var to_skel := (
		skeleton.global_transform.basis.orthonormalized().inverse()
		* frame_node.global_transform.basis.orthonormalized()
	)
	var right := to_skel * Vector3.RIGHT
	var fwd := to_skel * Vector3.FORWARD
	var up := to_skel * Vector3.UP
	var tremor := 0.04 * float(style.get("tremor", 0.0)) * sin(_time * TAU * 11.0)
	var pitch := float(style.get("trunk_pitch", 0.0))
	var crouch := float(style.get("crouch", 0.0))
	var roll := float(style.get("trunk_roll", 0.0)) - 0.06 * float(style.get("limp", 0.0))
	if _bones.has("Body"):
		var body: int = _bones["Body"]
		# Nose down (a hunch) is a rotation about +X toward -Y in front.
		_rotate(skeleton, body, right, -0.35 * pitch + tremor)
		_rotate(skeleton, body, fwd, roll)
		var rest_h := skeleton.get_bone_global_rest(body).origin.dot(up)
		var parent := skeleton.get_bone_parent(body)
		var down := -up
		if parent >= 0:
			down = skeleton.get_bone_global_pose(parent).basis.orthonormalized().inverse() * down
		skeleton.set_bone_pose_position(
			body, skeleton.get_bone_pose_position(body) + down * 0.25 * crouch * absf(rest_h)
		)
		var fluff := 1.0 + 0.07 * float(style.get("fluff", 0.0))
		skeleton.set_bone_pose_scale(body, skeleton.get_bone_pose_scale(body) * fluff)
	if _bones.has("Head"):
		_rotate(
			skeleton, _bones["Head"], right, -0.5 * float(style.get("head_down", 0.0)) + 0.3 * pitch
		)
	if _bones.has("Tail"):
		_rotate(skeleton, _bones["Tail"], right, -0.9 * float(style.get("tail_tuck", 0.0)))
	var spread := float(style.get("arm_out", 0.0))
	var hug := 0.5 * (float(style.get("hug_L", 0.0)) + float(style.get("hug_R", 0.0)))
	for side: String in ["L", "R"]:
		var key := "Wing." + side
		if not _bones.has(key):
			continue
		var s := 1.0 if side == "R" else -1.0
		# Out: the wing lifts away from the body; hug: it presses in.
		_rotate(skeleton, _bones[key], fwd, s * (0.9 * spread - 0.4 * hug))


func _rotate(skeleton: Skeleton3D, bone: int, axis: Vector3, angle: float) -> void:
	if absf(angle) < 1e-4:
		return
	var global := skeleton.get_bone_global_pose(bone)
	var turned := Basis(axis.normalized(), angle) * global.basis.orthonormalized()
	var parent := skeleton.get_bone_parent(bone)
	var parent_basis := Basis.IDENTITY
	if parent >= 0:
		parent_basis = skeleton.get_bone_global_pose(parent).basis.orthonormalized()
	skeleton.set_bone_pose_rotation(
		bone, (parent_basis.inverse() * turned).get_rotation_quaternion()
	)
