class_name MapViewRuntimeCamera
extends RefCounted

## Gameplay camera modes, orbit, look, and top-down zoom for MapViewRuntime.

enum CameraMode {
	THIRD_PERSON,
	FIRST_PERSON,
	TOP_DOWN,
}

const CameraSafety := preload("res://scripts/map/view3d/map_view_runtime_camera_safety.gd")
const CameraTarget := preload("res://scripts/map/view3d/map_view_runtime_camera_target.gd")
const CameraPerspective := preload(
	"res://scripts/map/view3d/map_view_runtime_camera_perspective.gd"
)
const CameraShake := preload("res://scripts/map/view3d/map_view_runtime_camera_shake.gd")
const CameraZoom := preload("res://scripts/map/view3d/map_view_runtime_camera_zoom.gd")
const CameraOrbit := preload("res://scripts/map/view3d/map_view_runtime_camera_orbit.gd")
## Re-exported so camera safety tests keep a stable MapViewRuntimeCamera API.
const GROUND_CLEARANCE := CameraSafety.GROUND_CLEARANCE
const INTERIOR_FLOOR_EDGE_MARGIN := CameraTarget.INTERIOR_FLOOR_EDGE_MARGIN
const BUILDING_PULL_ITERATIONS := CameraSafety.BUILDING_PULL_ITERATIONS
const BUILDING_PULL_STEP := CameraSafety.BUILDING_PULL_STEP
const VISIBILITY_PULL_STEP := CameraSafety.VISIBILITY_PULL_STEP
const VISIBILITY_PULL_ITERATIONS := CameraSafety.VISIBILITY_PULL_ITERATIONS

const FOLLOW_LERP_WEIGHT := 8.0
const SNAP_DISTANCE_WORLD := 6.0
## Re-exported so runtime and camera tests keep a stable MapViewRuntimeCamera API.
const ZOOM_STEP_FACTOR := CameraZoom.ZOOM_STEP_FACTOR
const ZOOM_MIN_FACTOR := CameraZoom.ZOOM_MIN_FACTOR
const ZOOM_MAX_FACTOR := CameraZoom.ZOOM_MAX_FACTOR
const ZOOM_MIN_ORTHOGRAPHIC_SIZE := CameraZoom.ZOOM_MIN_ORTHOGRAPHIC_SIZE
const ZOOM_MAX_ORTHOGRAPHIC_SIZE := CameraZoom.ZOOM_MAX_ORTHOGRAPHIC_SIZE
const PAN_SCROLL_ZOOM_SENSITIVITY := CameraZoom.PAN_SCROLL_ZOOM_SENSITIVITY
const THIRD_PERSON_DISTANCE := CameraZoom.THIRD_PERSON_DISTANCE
const THIRD_PERSON_MIN_DISTANCE := CameraZoom.THIRD_PERSON_MIN_DISTANCE
const THIRD_PERSON_MAX_DISTANCE := CameraZoom.THIRD_PERSON_MAX_DISTANCE
## Re-exported so runtime and camera tests keep a stable MapViewRuntimeCamera API.
const ROTATE_SPEED_DEGREES := CameraOrbit.ROTATE_SPEED_DEGREES
const MOUSE_ROTATE_DEGREES_PER_PIXEL := CameraOrbit.MOUSE_ROTATE_DEGREES_PER_PIXEL
const THIRD_PERSON_TARGET_HEIGHT := 1.15
const THIRD_PERSON_PITCH_DEGREES := -12.0
## Follow-camera pitch band: look down toward the character/ground, or raise the
## boom enough to inspect ceilings without crossing the vertical poles.
const THIRD_PERSON_MIN_PITCH_DEGREES := CameraOrbit.THIRD_PERSON_MIN_PITCH_DEGREES
const THIRD_PERSON_MAX_PITCH_DEGREES := CameraOrbit.THIRD_PERSON_MAX_PITCH_DEGREES
const THIRD_PERSON_FOV_DEGREES := 65.0
const THIRD_PERSON_NEAR := 0.05
const FIRST_PERSON_EYE_HEIGHT := 1.65
const FIRST_PERSON_PITCH_DEGREES := -10.0
const FIRST_PERSON_MIN_PITCH_DEGREES := CameraOrbit.FIRST_PERSON_MIN_PITCH_DEGREES
const FIRST_PERSON_MAX_PITCH_DEGREES := CameraOrbit.FIRST_PERSON_MAX_PITCH_DEGREES
const FIRST_PERSON_FOV_DEGREES := 75.0
const FIRST_PERSON_NEAR := 0.05
const TOP_DOWN_NEAR := 0.05
## Re-exported so camera attribute tests keep a stable MapViewRuntimeCamera API.
const PERSPECTIVE_AUTO_EXPOSURE_SCALE := CameraPerspective.PERSPECTIVE_AUTO_EXPOSURE_SCALE
const PERSPECTIVE_EXPOSURE_SENSITIVITY := CameraPerspective.PERSPECTIVE_EXPOSURE_SENSITIVITY
const THIRD_PERSON_DOF_BLUR_AMOUNT := CameraPerspective.THIRD_PERSON_DOF_BLUR_AMOUNT
const THIRD_PERSON_DOF_FAR_DISTANCE := CameraPerspective.THIRD_PERSON_DOF_FAR_DISTANCE
const FIRST_PERSON_DOF_BLUR_AMOUNT := CameraPerspective.FIRST_PERSON_DOF_BLUR_AMOUNT
const FIRST_PERSON_DOF_FAR_DISTANCE := CameraPerspective.FIRST_PERSON_DOF_FAR_DISTANCE
const OCCLUSION_PROBE_HEIGHTS: Array[float] = [0.5, 1.1, 1.8]

var camera: Camera3D
var player_rig: SharedCharacterRig
var view: MapView3D
var player: CharacterBody2D
var drag_rotating_view := false
var camera_mode: CameraMode = CameraMode.THIRD_PERSON
var first_person: bool:
	get:
		return camera_mode == CameraMode.FIRST_PERSON

var _safety := CameraSafety.new()
var _target := CameraTarget.new()
var _perspective := CameraPerspective.new()
var _shake := CameraShake.new()
var _zoom := CameraZoom.new()
var _orbit := CameraOrbit.new()


func configure(
	runtime_camera: Camera3D,
	runtime_player_rig: SharedCharacterRig,
	runtime_view: MapView3D,
	runtime_player: CharacterBody2D
) -> void:
	camera = runtime_camera
	player_rig = runtime_player_rig
	view = runtime_view
	player = runtime_player
	_zoom.configure(self)
	_orbit.configure(self)
	# Enclosed building scenes start overhead so perspective camera booms cannot
	# collide with perimeter walls. Players may still cycle to either perspective mode.
	camera_mode = (
		CameraMode.TOP_DOWN
		if view.definition != null and view.definition.suppresses_exterior_surroundings()
		else CameraMode.THIRD_PERSON
	)
	_safety.configure(self)
	_target.configure(self)
	_perspective.configure(self)
	_apply_camera_mode()


func player_inside_occluder() -> bool:
	return _safety.player_inside_occluder()


func perspective_camera_attributes() -> CameraAttributesPractical:
	return _perspective.perspective_camera_attributes()


func third_person_follow_distance() -> float:
	return _zoom.third_person_distance()


func logic_direction_toward_camera() -> Vector2:
	var world_offset := camera.position - player_rig.position
	return Vector2(world_offset.x, world_offset.z).normalized()


func logic_direction_camera_faces() -> Vector2:
	var world_forward := -camera.transform.basis.z
	return Vector2(world_forward.x, world_forward.z).normalized()


func character_follows_camera() -> bool:
	return camera_mode != CameraMode.TOP_DOWN


func follow_player(snap: bool, delta: float) -> void:
	var target := _follow_target()
	var camera_was_inside_occluder := view != null and view.is_point_inside_occluder(camera.position)
	var camera_and_player_shared_occluder := (
		camera_was_inside_occluder and _safety.camera_and_player_share_occluder()
	)
	var camera_was_below_ground := _safety.camera_is_below_ground()
	if snap or camera.position.distance_to(target) > SNAP_DISTANCE_WORLD:
		camera.position = _shake.apply(delta, target)
	else:
		var lerped := camera.position.lerp(target, clampf(FOLLOW_LERP_WEIGHT * delta, 0.0, 1.0))
		camera.position = _shake.apply(delta, lerped)
	_safety.enforce_camera_safety(
		camera_was_inside_occluder, camera_and_player_shared_occluder, camera_was_below_ground
	)
	view.update_terrain_detail_focus(player_rig.position)


func add_screen_shake(amount: float = 0.35) -> void:
	_shake.add(amount)


func _follow_target() -> Vector3:
	match camera_mode:
		CameraMode.FIRST_PERSON:
			return player_rig.position + Vector3.UP * FIRST_PERSON_EYE_HEIGHT
		CameraMode.THIRD_PERSON:
			return _target.resolve_third_person_target(
				(
					player_rig.position
					+ Vector3.UP * THIRD_PERSON_TARGET_HEIGHT
					+ camera.transform.basis.z * _zoom.third_person_distance()
				)
			)
		_:
			return player_rig.position + camera.transform.basis.z * MapView3D.CAMERA_DISTANCE


func apply_view_rotation(delta: float) -> void:
	_orbit.apply_view_rotation(delta)


func apply_mouse_rotation_drag() -> void:
	_orbit.apply_mouse_rotation_drag()


func apply_mouse_rotation_from_position(mouse_position: Vector2, button_pressed: bool) -> void:
	_orbit.apply_mouse_rotation_from_position(mouse_position, button_pressed)


func rotate_view_degrees(delta_degrees: float) -> void:
	_orbit.rotate_view_degrees(delta_degrees)


func look_pitch_degrees(delta_degrees: float) -> void:
	_orbit.look_pitch_degrees(delta_degrees)


## Compatibility wrapper for callers that only intend first-person free look.
func look_first_person_degrees(delta_degrees: float) -> void:
	_orbit.look_first_person_degrees(delta_degrees)


func zoom_view_steps(steps: float) -> void:
	_zoom.apply_view_steps(steps)


func zoom_from_magnify_factor(factor: float) -> void:
	_zoom.apply_magnify_factor(factor)


func zoom_from_pan_delta(delta: Vector2) -> void:
	_zoom.apply_pan_delta(delta)


func cycle_camera_mode() -> void:
	match camera_mode:
		CameraMode.THIRD_PERSON:
			set_camera_mode(CameraMode.FIRST_PERSON)
		CameraMode.FIRST_PERSON:
			set_camera_mode(CameraMode.TOP_DOWN)
		CameraMode.TOP_DOWN:
			set_camera_mode(CameraMode.THIRD_PERSON)


func toggle_first_person() -> void:
	set_first_person(not first_person)


func set_first_person(enabled: bool) -> void:
	set_camera_mode(CameraMode.FIRST_PERSON if enabled else CameraMode.THIRD_PERSON)


func set_camera_mode(next_mode: CameraMode) -> void:
	if camera_mode == next_mode:
		return
	if camera_mode == CameraMode.TOP_DOWN:
		_zoom.capture_top_down_size_from_camera()
	camera_mode = next_mode
	_apply_camera_mode()


func _apply_camera_mode() -> void:
	match camera_mode:
		CameraMode.THIRD_PERSON:
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			camera.fov = THIRD_PERSON_FOV_DEGREES
			camera.near = THIRD_PERSON_NEAR
			camera.rotation_degrees.x = THIRD_PERSON_PITCH_DEGREES
			_perspective.apply_for_perspective_mode(camera_mode)
		CameraMode.FIRST_PERSON:
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			camera.fov = FIRST_PERSON_FOV_DEGREES
			camera.near = FIRST_PERSON_NEAR
			camera.rotation_degrees.x = FIRST_PERSON_PITCH_DEGREES
			_perspective.apply_for_perspective_mode(camera_mode)
		CameraMode.TOP_DOWN:
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.size = _zoom.top_down_size()
			camera.near = TOP_DOWN_NEAR
			camera.rotation_degrees.x = MapView3D.CAMERA_PITCH_DEGREES
			_perspective.clear_for_top_down()
	player_rig.visible = not first_person
	# Close perspective cameras need the ceiling shell and nearby micro detail;
	# only the distant top-down view uses the readability cutaway.
	view.set_close_camera_mode(camera_mode != CameraMode.TOP_DOWN)
	follow_player(true, 0.0)
	if camera_mode == CameraMode.TOP_DOWN and player.has_method("set_camera_facing"):
		player.call("set_camera_facing", Vector2.ZERO)
	_sync_player_facing_to_camera()


func _sync_player_facing_to_camera() -> void:
	if not character_follows_camera():
		return
	var facing := logic_direction_camera_faces()
	if facing.is_zero_approx():
		return
	if player.has_method("set_camera_facing"):
		player.call("set_camera_facing", facing)
	elif player.has_method("set_view_facing"):
		player.call("set_view_facing", facing)


func mode_label() -> String:
	match camera_mode:
		CameraMode.THIRD_PERSON:
			return "Third-person view"
		CameraMode.FIRST_PERSON:
			return "First-person view"
		_:
			return "Top-down view"


func update_occlusion_ghost() -> void:
	_safety.update_occlusion_ghost()
