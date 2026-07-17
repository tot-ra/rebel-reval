extends SkeletonModifier3D

## Shrinks the vendor rig's oversized chibi head toward realistic proportions.
## Runs as a skeleton modifier so the scale survives every animation pose
## update instead of being overwritten by the AnimationPlayer.

@export_range(0.3, 1.0, 0.01) var head_scale := 0.72

var _head_bone := -1


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	if _head_bone < 0:
		_head_bone = _find_head_bone(skeleton)
		if _head_bone < 0:
			return
	skeleton.set_bone_pose_scale(_head_bone, Vector3.ONE * head_scale)


func _find_head_bone(skeleton: Skeleton3D) -> int:
	var exact := skeleton.find_bone("head")
	if exact >= 0:
		return exact
	for bone_index in skeleton.get_bone_count():
		if skeleton.get_bone_name(bone_index).to_lower().contains("head"):
			return bone_index
	return -1
