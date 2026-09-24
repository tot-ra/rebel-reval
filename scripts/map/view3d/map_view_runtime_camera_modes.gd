class_name MapViewRuntimeCameraModes
extends RefCounted

## Perspective/top-down mode switching and per-mode camera attributes for
## MapViewRuntimeCamera. Split out under P0-185 so follow/orbit code stays
## under the architecture soft cap.

const THIRD_PERSON_TARGET_HEIGHT := 1.15
const THIRD_PERSON_PITCH_DEGREES := -12.0
const THIRD_PERSON_FOV_DEGREES := 65.0
const THIRD_PERSON_NEAR := 0.05
const FIRST_PERSON_EYE_HEIGHT := 1.65
const FIRST_PERSON_PITCH_DEGREES := -10.0
const FIRST_PERSON_FOV_DEGREES := 75.0
const FIRST_PERSON_NEAR := 0.05
const TOP_DOWN_NEAR := 0.05

var _controller: MapViewRuntimeCamera


func configure(controller: MapViewRuntimeCamera) -> void:
	_controller = controller


func resolve_initial_mode() -> MapViewRuntimeCamera.CameraMode:
	var view := _controller.view
	if view != null and view.definition != null and view.definition.suppresses_exterior_surroundings():
		return MapViewRuntimeCamera.CameraMode.TOP_DOWN
	return MapViewRuntimeCamera.CameraMode.THIRD_PERSON


func cycle_camera_mode() -> void:
	match _controller.camera_mode:
		MapViewRuntimeCamera.CameraMode.THIRD_PERSON:
			set_camera_mode(MapViewRuntimeCamera.CameraMode.FIRST_PERSON)
		MapViewRuntimeCamera.CameraMode.FIRST_PERSON:
			set_camera_mode(MapViewRuntimeCamera.CameraMode.TOP_DOWN)
		MapViewRuntimeCamera.CameraMode.TOP_DOWN:
			set_camera_mode(MapViewRuntimeCamera.CameraMode.THIRD_PERSON)


func toggle_first_person() -> void:
	set_first_person(not _controller.first_person)


func set_first_person(enabled: bool) -> void:
	set_camera_mode(
		MapViewRuntimeCamera.CameraMode.FIRST_PERSON
		if enabled
		else MapViewRuntimeCamera.CameraMode.THIRD_PERSON
	)


func set_camera_mode(next_mode: MapViewRuntimeCamera.CameraMode) -> void:
	if _controller.camera_mode == next_mode:
		return
	if _controller.camera_mode == MapViewRuntimeCamera.CameraMode.TOP_DOWN:
		_controller._zoom.capture_top_down_size_from_camera()
	_controller.camera_mode = next_mode
	apply_mode()


func apply_mode() -> void:
	var camera := _controller.camera
	match _controller.camera_mode:
		MapViewRuntimeCamera.CameraMode.THIRD_PERSON:
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			camera.fov = THIRD_PERSON_FOV_DEGREES
			camera.near = THIRD_PERSON_NEAR
			camera.rotation_degrees.x = THIRD_PERSON_PITCH_DEGREES
			_controller._perspective.apply_for_perspective_mode(_controller.camera_mode)
		MapViewRuntimeCamera.CameraMode.FIRST_PERSON:
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			camera.fov = FIRST_PERSON_FOV_DEGREES
			camera.near = FIRST_PERSON_NEAR
			camera.rotation_degrees.x = FIRST_PERSON_PITCH_DEGREES
			_controller._perspective.apply_for_perspective_mode(_controller.camera_mode)
		MapViewRuntimeCamera.CameraMode.TOP_DOWN:
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.size = _controller._zoom.top_down_size()
			camera.near = TOP_DOWN_NEAR
			camera.rotation_degrees.x = MapView3D.CAMERA_PITCH_DEGREES
			_controller._perspective.clear_for_top_down()
	_controller.player_rig.visible = not _controller.first_person
	# Close perspective cameras need the ceiling shell and nearby micro detail;
	# only the distant top-down view uses the readability cutaway.
	_controller.view.set_close_camera_mode(
		_controller.camera_mode != MapViewRuntimeCamera.CameraMode.TOP_DOWN
	)
	_controller.follow_player(true, 0.0)
	if (
		_controller.camera_mode == MapViewRuntimeCamera.CameraMode.TOP_DOWN
		and _controller.player.has_method("set_camera_facing")
	):
		_controller.player.call("set_camera_facing", Vector2.ZERO)
	sync_player_facing_to_camera()


func mode_label() -> String:
	match _controller.camera_mode:
		MapViewRuntimeCamera.CameraMode.THIRD_PERSON:
			return "Third-person view"
		MapViewRuntimeCamera.CameraMode.FIRST_PERSON:
			return "First-person view"
		_:
			return "Top-down view"


func sync_player_facing_to_camera() -> void:
	if not _controller.character_follows_camera():
		return
	var facing := _controller.logic_direction_camera_faces()
	if facing.is_zero_approx():
		return
	if _controller.player.has_method("set_camera_facing"):
		_controller.player.call("set_camera_facing", facing)
	elif _controller.player.has_method("set_view_facing"):
		_controller.player.call("set_view_facing", facing)
