class_name SmithyContactPoseModifier
extends SkeletonModifier3D

## Restrained late pose correction for contact-heavy smithy actions. Imported
## clips remain authoritative; this modifier only bends the working arm and
## lowers hips enough to meet a station profile without stretching the body.

var profile: Dictionary = {}


func configure(next_profile: Dictionary) -> void:
	profile = next_profile.duplicate(true)
	active = not profile.is_empty()


func clear_profile() -> void:
	profile.clear()
	active = false


func _process_modification() -> void:
	if profile.is_empty():
		return
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	_apply_rotation(skeleton, &"upperarm.r", float(profile.get("shoulder_pitch_deg", 0.0)))
	_apply_rotation(skeleton, &"lowerarm.r", float(profile.get("elbow_bend_deg", 0.0)))
	_apply_rotation(skeleton, &"upperarm.l", -float(profile.get("left_shoulder_pitch_deg", 0.0)))
	_apply_rotation(skeleton, &"lowerarm.l", -float(profile.get("left_elbow_bend_deg", 0.0)))
	var hips_index := skeleton.find_bone("hips")
	if hips_index >= 0:
		var hips_offset := float(profile.get("hips_offset_y", 0.0))
		if not is_zero_approx(hips_offset):
			skeleton.set_bone_pose_position(
				hips_index,
				skeleton.get_bone_pose_position(hips_index) + Vector3.UP * hips_offset
			)


static func _apply_rotation(
	skeleton: Skeleton3D,
	bone_name: StringName,
	degrees: float
) -> void:
	if is_zero_approx(degrees):
		return
	var index := skeleton.find_bone(String(bone_name))
	if index < 0:
		return
	var authored := skeleton.get_bone_pose_rotation(index)
	var correction := Quaternion(Vector3.FORWARD, deg_to_rad(degrees))
	skeleton.set_bone_pose_rotation(index, authored * correction)
