class_name MapViewRuntimeCameraPerspective
extends RefCounted

## Practical-camera exposure and depth-of-field for MapViewRuntimeCamera perspective
## modes. Split out under P0-185 so mode/zoom/orbit code stays under the soft cap.

const PERSPECTIVE_AUTO_EXPOSURE_ENABLED := true
const PERSPECTIVE_AUTO_EXPOSURE_SCALE := 0.35
const PERSPECTIVE_AUTO_EXPOSURE_SPEED := 0.5
const PERSPECTIVE_EXPOSURE_SENSITIVITY := 100.0
const THIRD_PERSON_DOF_BLUR_AMOUNT := 0.032
const THIRD_PERSON_DOF_FAR_DISTANCE := 10.0
const THIRD_PERSON_DOF_FAR_TRANSITION := 6.0
const FIRST_PERSON_DOF_BLUR_AMOUNT := 0.028
const FIRST_PERSON_DOF_FAR_DISTANCE := 14.0
const FIRST_PERSON_DOF_FAR_TRANSITION := 8.0

var _controller: MapViewRuntimeCamera
var _attributes: CameraAttributesPractical


func configure(controller: MapViewRuntimeCamera) -> void:
	_controller = controller
	_attributes = CameraAttributesPractical.new()


func perspective_camera_attributes() -> CameraAttributesPractical:
	return _attributes


func clear_for_top_down() -> void:
	if _controller.camera != null:
		_controller.camera.attributes = null


func apply_for_perspective_mode(mode: MapViewRuntimeCamera.CameraMode) -> void:
	if _attributes == null or _controller.camera == null:
		return
	if _supports_auto_exposure():
		_attributes.auto_exposure_enabled = PERSPECTIVE_AUTO_EXPOSURE_ENABLED
		_attributes.auto_exposure_scale = PERSPECTIVE_AUTO_EXPOSURE_SCALE
		_attributes.auto_exposure_speed = PERSPECTIVE_AUTO_EXPOSURE_SPEED
		_attributes.exposure_sensitivity = PERSPECTIVE_EXPOSURE_SENSITIVITY
	if not _supports_depth_of_field():
		# Compatibility does not implement DOF and logs a warning when blur is enabled.
		# Keep practical exposure attributes active while leaving unsupported blur off.
		_attributes.dof_blur_near_enabled = false
		_attributes.dof_blur_far_enabled = false
		_controller.camera.attributes = _attributes
		return
	_attributes.dof_blur_near_enabled = false
	_attributes.dof_blur_far_enabled = true
	match mode:
		MapViewRuntimeCamera.CameraMode.THIRD_PERSON:
			_attributes.dof_blur_amount = THIRD_PERSON_DOF_BLUR_AMOUNT
			_attributes.dof_blur_far_distance = THIRD_PERSON_DOF_FAR_DISTANCE
			_attributes.dof_blur_far_transition = THIRD_PERSON_DOF_FAR_TRANSITION
		MapViewRuntimeCamera.CameraMode.FIRST_PERSON:
			_attributes.dof_blur_amount = FIRST_PERSON_DOF_BLUR_AMOUNT
			_attributes.dof_blur_far_distance = FIRST_PERSON_DOF_FAR_DISTANCE
			_attributes.dof_blur_far_transition = FIRST_PERSON_DOF_FAR_TRANSITION
		_:
			return
	_controller.camera.attributes = _attributes


func _supports_auto_exposure() -> bool:
	return (
		str(ProjectSettings.get_setting("rendering/renderer/rendering_method", ""))
		== "forward_plus"
	)


func _supports_depth_of_field() -> bool:
	var rendering_method := str(
		ProjectSettings.get_setting("rendering/renderer/rendering_method", "")
	)
	return rendering_method in ["forward_plus", "mobile"]
