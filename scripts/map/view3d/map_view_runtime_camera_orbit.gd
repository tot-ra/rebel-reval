class_name MapViewRuntimeCameraOrbit
extends RefCounted

## Keyboard and mouse orbit / pitch for MapViewRuntimeCamera. Split out under P0-185 so
## mode, zoom, and follow code stays under the architecture soft cap.

const ROTATE_SPEED_DEGREES := 120.0
const MOUSE_ROTATE_DEGREES_PER_PIXEL := 0.3
const THIRD_PERSON_MIN_PITCH_DEGREES := -55.0
const THIRD_PERSON_MAX_PITCH_DEGREES := 35.0
const FIRST_PERSON_MIN_PITCH_DEGREES := -80.0
const FIRST_PERSON_MAX_PITCH_DEGREES := 80.0

var _controller: MapViewRuntimeCamera
var _mouse_rotation_armed := false
var _last_mouse_position := Vector2.ZERO


func configure(controller: MapViewRuntimeCamera) -> void:
	_controller = controller


func apply_view_rotation(delta: float) -> void:
	apply_mouse_rotation_drag()
	var direction := 0.0
	if Input.is_key_pressed(KEY_PAGEUP):
		direction += 1.0
	if Input.is_key_pressed(KEY_PAGEDOWN):
		direction -= 1.0
	if direction == 0.0:
		return
	rotate_view_degrees(direction * ROTATE_SPEED_DEGREES * delta)


func apply_mouse_rotation_drag() -> void:
	apply_mouse_rotation_from_position(
		_controller.camera.get_viewport().get_mouse_position(),
		Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	)


func apply_mouse_rotation_from_position(mouse_position: Vector2, button_pressed: bool) -> void:
	if button_pressed:
		if _mouse_rotation_armed:
			var mouse_delta := mouse_position - _last_mouse_position
			if not is_zero_approx(mouse_delta.x):
				rotate_view_degrees(-mouse_delta.x * MOUSE_ROTATE_DEGREES_PER_PIXEL)
			# Perspective modes share vertical orbit; top-down keeps its authored pitch.
			if (
				_controller.camera_mode != MapViewRuntimeCamera.CameraMode.TOP_DOWN
				and not is_zero_approx(mouse_delta.y)
			):
				look_pitch_degrees(-mouse_delta.y * MOUSE_ROTATE_DEGREES_PER_PIXEL)
		_mouse_rotation_armed = true
		_controller.drag_rotating_view = true
	else:
		_mouse_rotation_armed = false
		_controller.drag_rotating_view = false
	_last_mouse_position = mouse_position


func rotate_view_degrees(delta_degrees: float) -> void:
	_controller.camera.rotation_degrees.y = wrapf(
		_controller.camera.rotation_degrees.y + delta_degrees, -180.0, 180.0
	)
	_controller.follow_player(true, 0.0)
	_controller._sync_player_facing_to_camera()


func look_pitch_degrees(delta_degrees: float) -> void:
	if _controller.camera_mode == MapViewRuntimeCamera.CameraMode.TOP_DOWN:
		return
	var min_pitch := FIRST_PERSON_MIN_PITCH_DEGREES
	var max_pitch := FIRST_PERSON_MAX_PITCH_DEGREES
	if _controller.camera_mode == MapViewRuntimeCamera.CameraMode.THIRD_PERSON:
		min_pitch = THIRD_PERSON_MIN_PITCH_DEGREES
		max_pitch = THIRD_PERSON_MAX_PITCH_DEGREES
	# Avoid crossing the vertical poles, which would make yaw and movement flip.
	_controller.camera.rotation_degrees.x = clampf(
		_controller.camera.rotation_degrees.x + delta_degrees, min_pitch, max_pitch
	)
	if _controller.camera_mode == MapViewRuntimeCamera.CameraMode.THIRD_PERSON:
		# Pitch changes the orbit boom; snap so the follow distance stays exact.
		_controller.follow_player(true, 0.0)


## Compatibility wrapper for callers that only intend first-person free look.
func look_first_person_degrees(delta_degrees: float) -> void:
	if not _controller.first_person:
		return
	look_pitch_degrees(delta_degrees)
