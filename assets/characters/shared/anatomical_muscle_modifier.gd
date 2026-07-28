extends SkeletonModifier3D

## Lightweight pose-driven muscle response for anatomical character bodies.
##
## The imported animation still owns every joint. This modifier only adds a
## restrained volume response: as an elbow or knee bends, the parent muscle
## group gets slightly thicker and shorter. Scaling the same skeleton that
## skins both body and fitted clothing keeps all layers registered without a
## runtime soft-body simulation.

@export_range(0.0, 0.12, 0.005) var arm_transverse_gain := 0.055
@export_range(0.0, 0.08, 0.005) var arm_longitudinal_loss := 0.018
@export_range(0.0, 0.12, 0.005) var leg_transverse_gain := 0.045
@export_range(0.0, 0.08, 0.005) var leg_longitudinal_loss := 0.014

const FULL_CONTRACTION_ANGLE := deg_to_rad(105.0)
const LIMB_CHAINS: Array[Dictionary] = [
	{
		"driver": &"lowerarm.l",
		"muscle": &"upperarm.l",
		"transverse_gain": "arm_transverse_gain",
		"longitudinal_loss": "arm_longitudinal_loss",
	},
	{
		"driver": &"lowerarm.r",
		"muscle": &"upperarm.r",
		"transverse_gain": "arm_transverse_gain",
		"longitudinal_loss": "arm_longitudinal_loss",
	},
	{
		"driver": &"lowerleg.l",
		"muscle": &"lowerleg.l",
		"transverse_gain": "leg_transverse_gain",
		"longitudinal_loss": "leg_longitudinal_loss",
	},
	{
		"driver": &"lowerleg.r",
		"muscle": &"lowerleg.r",
		"transverse_gain": "leg_transverse_gain",
		"longitudinal_loss": "leg_longitudinal_loss",
	},
]


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	for chain: Dictionary in LIMB_CHAINS:
		_apply_chain(skeleton, chain)


func _apply_chain(skeleton: Skeleton3D, chain: Dictionary) -> void:
	var driver_index := skeleton.find_bone(String(chain["driver"]))
	var muscle_index := skeleton.find_bone(String(chain["muscle"]))
	if driver_index < 0 or muscle_index < 0:
		return

	# Pose rotation is measured relative to the imported rest transform. The
	# smoothstep-like curve suppresses tiny idle noise but responds in combat,
	# locomotion, sitting, and pickup poses.
	var bend_angle := skeleton.get_bone_pose_rotation(driver_index).get_angle()
	var contraction := clampf(bend_angle / FULL_CONTRACTION_ANGLE, 0.0, 1.0)
	contraction = contraction * contraction * (3.0 - 2.0 * contraction)
	var transverse_gain: float = get(StringName(chain["transverse_gain"]))
	var longitudinal_loss: float = get(StringName(chain["longitudinal_loss"]))
	skeleton.set_bone_pose_scale(
		muscle_index,
		Vector3(
			1.0 + transverse_gain * contraction,
			1.0 - longitudinal_loss * contraction,
			1.0 + transverse_gain * contraction
		)
	)
