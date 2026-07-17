extends SkeletonModifier3D

## Final animated retargeting on top of the baked heroic body proportions.
## Moderate values keep the silhouette adult at gameplay scale without the
## extreme deformation previously required by the untouched vendor mesh.

## Neutral by default: adult proportions are now fully baked into the glb
## skeleton by tools/build_heroic_humanoid_glb.py; these stay as per-variant
## fine-tune knobs only.
@export_range(0.3, 1.2, 0.01) var head_scale := 1.0
@export_range(0.8, 1.5, 0.01) var leg_segment_scale := 1.0
@export_range(0.8, 1.5, 0.01) var arm_segment_scale := 1.0
@export_range(0.7, 1.2, 0.01) var torso_scale := 1.0

const LEG_BONES: Array[StringName] = [
	&"upperleg.l",
	&"upperleg.r",
	&"lowerleg.l",
	&"lowerleg.r",
]
const ARM_BONES: Array[StringName] = [
	&"upperarm.l",
	&"upperarm.r",
	&"lowerarm.l",
	&"lowerarm.r",
]
const TORSO_BONES: Array[StringName] = [&"spine", &"chest"]

var _head_bone := -1


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	_apply_head_scale(skeleton)
	_apply_y_segment_scales(skeleton, LEG_BONES, leg_segment_scale)
	_apply_y_segment_scales(skeleton, ARM_BONES, arm_segment_scale)
	_apply_y_segment_scales(skeleton, TORSO_BONES, torso_scale)


func _apply_head_scale(skeleton: Skeleton3D) -> void:
	if _head_bone < 0:
		_head_bone = _find_head_bone(skeleton)
		if _head_bone < 0:
			return
	skeleton.set_bone_pose_scale(_head_bone, Vector3.ONE * head_scale)


func _apply_y_segment_scales(
	skeleton: Skeleton3D,
	bone_names: Array[StringName],
	y_scale: float,
) -> void:
	for bone_name: StringName in bone_names:
		var bone_index := skeleton.find_bone(String(bone_name))
		if bone_index < 0:
			continue
		skeleton.set_bone_pose_scale(bone_index, Vector3(1.0, y_scale, 1.0))


func _find_head_bone(skeleton: Skeleton3D) -> int:
	var exact := skeleton.find_bone("head")
	if exact >= 0:
		return exact
	for bone_index in skeleton.get_bone_count():
		if skeleton.get_bone_name(bone_index).to_lower().contains("head"):
			return bone_index
	return -1
