class_name MapViewRuntimeCamera
extends RefCounted

## Gameplay camera orbit, zoom, and first-person toggles for MapViewRuntime.

const FOLLOW_LERP_WEIGHT := 8.0
const SNAP_DISTANCE_WORLD := 6.0
const ZOOM_STEP_FACTOR := 0.9
const ZOOM_MIN_FACTOR := 0.3
const ZOOM_MAX_FACTOR := 1.5
const ZOOM_MIN_ORTHOGRAPHIC_SIZE := CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE * ZOOM_MIN_FACTOR
const ZOOM_MAX_ORTHOGRAPHIC_SIZE := CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE * ZOOM_MAX_FACTOR
const ROTATE_SPEED_DEGREES := 120.0
const MOUSE_ROTATE_DEGREES_PER_PIXEL := 0.3
## macOS trackpad two-finger scroll arrives as InputEventPanGesture with small
## deltas (~0.5-1.5 per tick) instead of mouse-wheel buttons.
const PAN_SCROLL_ZOOM_SENSITIVITY := 1.0
const FIRST_PERSON_EYE_HEIGHT := 1.65
const FIRST_PERSON_PITCH_DEGREES := -10.0
const FIRST_PERSON_FOV_DEGREES := 75.0
const FIRST_PERSON_NEAR := 0.05
const OCCLUSION_PROBE_HEIGHTS: Array[float] = [0.5, 1.1, 1.8]

var camera: Camera3D
var player_rig: SharedCharacterRig
var view: MapView3D
var player: CharacterBody2D

var drag_rotating_view := false
var first_person := false

var _mouse_rotation_armed := false
var _last_mouse_position := Vector2.ZERO
var _third_person_size := CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE


func configure(runtime_camera: Camera3D, runtime_player_rig: SharedCharacterRig, runtime_view: MapView3D, runtime_player: CharacterBody2D) -> void:
	camera = runtime_camera
	player_rig = runtime_player_rig
	view = runtime_view
	player = runtime_player
	_third_person_size = camera.size


func logic_direction_toward_camera() -> Vector2:
	var world_offset := camera.position - player_rig.position
	return Vector2(world_offset.x, world_offset.z).normalized()


func follow_player(snap: bool, delta: float) -> void:
	var target: Vector3
	if first_person:
		target = player_rig.position + Vector3.UP * FIRST_PERSON_EYE_HEIGHT
	else:
		target = player_rig.position + camera.transform.basis.z * MapView3D.CAMERA_DISTANCE
	if snap or camera.position.distance_to(target) > SNAP_DISTANCE_WORLD:
		camera.position = target
		return
	camera.position = camera.position.lerp(target, clampf(FOLLOW_LERP_WEIGHT * delta, 0.0, 1.0))


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
		camera.get_viewport().get_mouse_position(),
		Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	)


func apply_mouse_rotation_from_position(mouse_position: Vector2, button_pressed: bool) -> void:
	if button_pressed:
		if _mouse_rotation_armed:
			var delta_x := mouse_position.x - _last_mouse_position.x
			if not is_zero_approx(delta_x):
				rotate_view_degrees(-delta_x * MOUSE_ROTATE_DEGREES_PER_PIXEL)
		_mouse_rotation_armed = true
		drag_rotating_view = true
	else:
		_mouse_rotation_armed = false
		drag_rotating_view = false
	_last_mouse_position = mouse_position


func rotate_view_degrees(delta_degrees: float) -> void:
	camera.rotation_degrees.y = wrapf(camera.rotation_degrees.y + delta_degrees, -180.0, 180.0)
	follow_player(true, 0.0)


func zoom_view_steps(steps: float) -> void:
	if first_person or is_zero_approx(steps):
		return
	camera.size = clampf(
		camera.size * pow(ZOOM_STEP_FACTOR, steps),
		ZOOM_MIN_ORTHOGRAPHIC_SIZE,
		ZOOM_MAX_ORTHOGRAPHIC_SIZE
	)


func zoom_from_magnify_factor(factor: float) -> void:
	if is_equal_approx(factor, 1.0):
		return
	# Pinch spread (factor > 1) must match wheel-up zoom-in semantics.
	zoom_view_steps(-log(factor) / log(ZOOM_STEP_FACTOR))


func zoom_from_pan_delta(delta: Vector2) -> void:
	if is_zero_approx(delta.y):
		return
	# Negative delta.y is trackpad scroll-up on macOS; wheel-up uses positive steps.
	zoom_view_steps(-delta.y * PAN_SCROLL_ZOOM_SENSITIVITY)


func toggle_first_person() -> void:
	set_first_person(not first_person)


func set_first_person(enabled: bool) -> void:
	if first_person == enabled:
		return
	first_person = enabled
	if enabled:
		_third_person_size = camera.size
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = FIRST_PERSON_FOV_DEGREES
		camera.near = FIRST_PERSON_NEAR
		camera.rotation_degrees.x = FIRST_PERSON_PITCH_DEGREES
	else:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = _third_person_size
		camera.near = 0.05
		camera.rotation_degrees.x = MapView3D.CAMERA_PITCH_DEGREES
	player_rig.visible = not enabled
	follow_player(true, 0.0)


func update_occlusion_ghost() -> void:
	if first_person:
		player_rig.set_occlusion_ghost(false)
		return
	var toward_camera := camera.transform.basis.z * MapView3D.CAMERA_DISTANCE
	var occluded := false
	for height in OCCLUSION_PROBE_HEIGHTS:
		var from := player_rig.position + Vector3.UP * height
		if view.is_segment_occluded(from, from + toward_camera):
			occluded = true
			break
	player_rig.set_occlusion_ghost(occluded)
