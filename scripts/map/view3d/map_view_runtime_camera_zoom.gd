class_name MapViewRuntimeCameraZoom
extends RefCounted

## Scroll, pinch, and trackpad zoom across third-person, first-person, and top-down
## for MapViewRuntimeCamera. Split out under P0-185 so mode and follow code stays
## under the architecture soft cap.

const ZOOM_STEP_FACTOR := 0.9
const ZOOM_MIN_FACTOR := 0.3
const ZOOM_MAX_FACTOR := 1.5
const ZOOM_MIN_ORTHOGRAPHIC_SIZE := CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE * ZOOM_MIN_FACTOR
const ZOOM_MAX_ORTHOGRAPHIC_SIZE := CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE * ZOOM_MAX_FACTOR
## macOS trackpad two-finger scroll arrives as InputEventPanGesture with small
## deltas (~0.5-1.5 per tick) instead of mouse-wheel buttons.
const PAN_SCROLL_ZOOM_SENSITIVITY := 1.0
const THIRD_PERSON_DISTANCE := 6.0
## Closest boom before scroll-zoom flips into first-person.
const THIRD_PERSON_MIN_DISTANCE := 2.0
## Farthest boom before scroll-zoom flips into the next overview (painted iso where
## the view offers it, otherwise the orthographic top-down).
const THIRD_PERSON_MAX_DISTANCE := 12.0
## Painted-iso boom band (R-1744): 30-45 m of telephoto between third person and
## the orthographic overview.
const PAINTED_ISO_DISTANCE := 42.0
const PAINTED_ISO_MIN_DISTANCE := 30.0
const PAINTED_ISO_MAX_DISTANCE := 45.0

var _controller: MapViewRuntimeCamera
var _top_down_size := CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE
var _third_person_distance := THIRD_PERSON_DISTANCE
var _painted_iso_distance := PAINTED_ISO_DISTANCE


func configure(controller: MapViewRuntimeCamera) -> void:
	_controller = controller
	_top_down_size = controller.camera.size
	_third_person_distance = THIRD_PERSON_DISTANCE


func third_person_distance() -> float:
	return _third_person_distance


func painted_iso_distance() -> float:
	return _painted_iso_distance


func top_down_size() -> float:
	return _top_down_size


func capture_top_down_size_from_camera() -> void:
	_top_down_size = _controller.camera.size


func apply_view_steps(steps: float) -> void:
	if is_zero_approx(steps):
		return
	match _controller.camera_mode:
		MapViewRuntimeCamera.CameraMode.TOP_DOWN:
			# Same continuum as the follow boom: zoom-in past the close ortho
			# threshold restores third-person at the farthest boom.
			var next_size := _controller.camera.size * pow(ZOOM_STEP_FACTOR, steps)
			if next_size < ZOOM_MIN_ORTHOGRAPHIC_SIZE and steps > 0.0:
				if _controller.painted_iso_available():
					_painted_iso_distance = PAINTED_ISO_MAX_DISTANCE
					_controller.set_camera_mode(MapViewRuntimeCamera.CameraMode.PAINTED_ISO)
					return
				_third_person_distance = THIRD_PERSON_MAX_DISTANCE
				_controller.set_camera_mode(MapViewRuntimeCamera.CameraMode.THIRD_PERSON)
				return
			_controller.camera.size = clampf(
				next_size, ZOOM_MIN_ORTHOGRAPHIC_SIZE, ZOOM_MAX_ORTHOGRAPHIC_SIZE
			)
			_top_down_size = _controller.camera.size
		MapViewRuntimeCamera.CameraMode.THIRD_PERSON:
			# Same wheel polarity as top-down: positive steps pull the boom closer.
			var next_distance := _third_person_distance * pow(ZOOM_STEP_FACTOR, steps)
			if next_distance < THIRD_PERSON_MIN_DISTANCE:
				# Crossing the close threshold enters eye-height first-person.
				_third_person_distance = THIRD_PERSON_MIN_DISTANCE
				_controller.set_camera_mode(MapViewRuntimeCamera.CameraMode.FIRST_PERSON)
				return
			if next_distance > THIRD_PERSON_MAX_DISTANCE:
				# Crossing the far threshold enters the painted iso or the ortho overview.
				_third_person_distance = THIRD_PERSON_MAX_DISTANCE
				if _controller.painted_iso_available():
					_painted_iso_distance = PAINTED_ISO_MIN_DISTANCE
					_controller.set_camera_mode(MapViewRuntimeCamera.CameraMode.PAINTED_ISO)
					return
				_controller.set_camera_mode(MapViewRuntimeCamera.CameraMode.TOP_DOWN)
				return
			_third_person_distance = clampf(
				next_distance, THIRD_PERSON_MIN_DISTANCE, THIRD_PERSON_MAX_DISTANCE
			)
			_controller.follow_player(true, 0.0)
		MapViewRuntimeCamera.CameraMode.PAINTED_ISO:
			var next_iso := _painted_iso_distance * pow(ZOOM_STEP_FACTOR, steps)
			if next_iso < PAINTED_ISO_MIN_DISTANCE:
				_third_person_distance = THIRD_PERSON_MAX_DISTANCE
				_controller.set_camera_mode(MapViewRuntimeCamera.CameraMode.THIRD_PERSON)
				return
			if next_iso > PAINTED_ISO_MAX_DISTANCE:
				_controller.set_camera_mode(MapViewRuntimeCamera.CameraMode.TOP_DOWN)
				return
			_painted_iso_distance = next_iso
			_controller.follow_player(true, 0.0)
		MapViewRuntimeCamera.CameraMode.FIRST_PERSON:
			# Scroll-out restores the closest third-person boom; scroll-in is a no-op.
			if steps < 0.0:
				_third_person_distance = THIRD_PERSON_MIN_DISTANCE
				_controller.set_camera_mode(MapViewRuntimeCamera.CameraMode.THIRD_PERSON)


func apply_magnify_factor(factor: float) -> void:
	if is_equal_approx(factor, 1.0):
		return
	# Pinch spread (factor > 1) must match wheel-up zoom-in semantics.
	apply_view_steps(-log(factor) / log(ZOOM_STEP_FACTOR))


func apply_pan_delta(delta: Vector2) -> void:
	if is_zero_approx(delta.y):
		return
	# Negative delta.y is trackpad scroll-up on macOS; wheel-up uses positive steps.
	apply_view_steps(-delta.y * PAN_SCROLL_ZOOM_SENSITIVITY)
