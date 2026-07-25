class_name MapViewRuntimeCamera
extends RefCounted

## Gameplay camera modes, orbit, look, and top-down zoom for MapViewRuntime.

enum CameraMode {
	THIRD_PERSON,
	FIRST_PERSON,
	TOP_DOWN,
}

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
const THIRD_PERSON_DISTANCE := 6.0
## Closest boom before scroll-zoom flips into first-person.
const THIRD_PERSON_MIN_DISTANCE := 2.0
## Farthest boom before scroll-zoom flips into the orthographic top-down overview.
const THIRD_PERSON_MAX_DISTANCE := 12.0
const THIRD_PERSON_TARGET_HEIGHT := 1.15
const THIRD_PERSON_PITCH_DEGREES := -12.0
## Follow-camera pitch band: look down toward the character/ground, or raise the
## boom enough to inspect ceilings without crossing the vertical poles.
const THIRD_PERSON_MIN_PITCH_DEGREES := -55.0
const THIRD_PERSON_MAX_PITCH_DEGREES := 35.0
const THIRD_PERSON_FOV_DEGREES := 65.0
const THIRD_PERSON_NEAR := 0.05
const FIRST_PERSON_EYE_HEIGHT := 1.65
const FIRST_PERSON_PITCH_DEGREES := -10.0
const FIRST_PERSON_MIN_PITCH_DEGREES := -80.0
const FIRST_PERSON_MAX_PITCH_DEGREES := 80.0
const FIRST_PERSON_FOV_DEGREES := 75.0
const FIRST_PERSON_NEAR := 0.05
const TOP_DOWN_NEAR := 0.05
const OCCLUSION_PROBE_HEIGHTS: Array[float] = [0.5, 1.1, 1.8]

var camera: Camera3D
var player_rig: SharedCharacterRig
var view: MapView3D
var player: CharacterBody2D

const SHAKE_DECAY_RATE := 3.5
const SHAKE_MAX_OFFSET := 0.14

var _shake_trauma := 0.0
var _shake_phase := 0.0

var drag_rotating_view := false
var camera_mode: CameraMode = CameraMode.THIRD_PERSON
var first_person: bool:
	get:
		return camera_mode == CameraMode.FIRST_PERSON

var _mouse_rotation_armed := false
var _last_mouse_position := Vector2.ZERO
var _top_down_size := CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE
var _third_person_distance := THIRD_PERSON_DISTANCE


func configure(runtime_camera: Camera3D, runtime_player_rig: SharedCharacterRig, runtime_view: MapView3D, runtime_player: CharacterBody2D) -> void:
	camera = runtime_camera
	player_rig = runtime_player_rig
	view = runtime_view
	player = runtime_player
	_top_down_size = camera.size
	_third_person_distance = THIRD_PERSON_DISTANCE
	_apply_camera_mode()


func third_person_follow_distance() -> float:
	return _third_person_distance


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
	if snap or camera.position.distance_to(target) > SNAP_DISTANCE_WORLD:
		camera.position = _apply_screen_shake(delta, target)
		view.update_terrain_detail_focus(player_rig.position)
		return
	var lerped := camera.position.lerp(target, clampf(FOLLOW_LERP_WEIGHT * delta, 0.0, 1.0))
	camera.position = _apply_screen_shake(delta, lerped)
	view.update_terrain_detail_focus(player_rig.position)


func add_screen_shake(amount: float = 0.35) -> void:
	if not _screen_shake_enabled():
		return
	_shake_trauma = clampf(_shake_trauma + amount, 0.0, 1.0)


func _apply_screen_shake(delta: float, position: Vector3) -> Vector3:
	if _shake_trauma <= 0.0:
		return position
	_shake_trauma = maxf(_shake_trauma - SHAKE_DECAY_RATE * delta, 0.0)
	var amount := _shake_trauma * _shake_trauma
	_shake_phase += delta * 42.0
	var offset := Vector3(
		sin(_shake_phase * 1.7) * SHAKE_MAX_OFFSET * amount,
		sin(_shake_phase * 2.3) * SHAKE_MAX_OFFSET * amount * 0.45,
		cos(_shake_phase * 1.3) * SHAKE_MAX_OFFSET * amount
	)
	return position + offset


func _screen_shake_enabled() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or not tree.root.has_node("/root/UserSettings"):
		return true
	var settings: Node = tree.root.get_node("/root/UserSettings")
	if not ("gameplay" in settings) or not ("dialogue" in settings):
		return true
	var gameplay: Variant = settings.get("gameplay")
	var dialogue: Variant = settings.get("dialogue")
	if gameplay == null or not gameplay.has_method("allows_screenshake"):
		return true
	var reduced_motion := bool(dialogue.reduced_motion) if dialogue != null else false
	return bool(gameplay.allows_screenshake(reduced_motion))


func _follow_target() -> Vector3:
	match camera_mode:
		CameraMode.FIRST_PERSON:
			return player_rig.position + Vector3.UP * FIRST_PERSON_EYE_HEIGHT
		CameraMode.THIRD_PERSON:
			return (
				player_rig.position
				+ Vector3.UP * THIRD_PERSON_TARGET_HEIGHT
				+ camera.transform.basis.z * _third_person_distance
			)
		_:
			return player_rig.position + camera.transform.basis.z * MapView3D.CAMERA_DISTANCE


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
			var mouse_delta := mouse_position - _last_mouse_position
			if not is_zero_approx(mouse_delta.x):
				rotate_view_degrees(-mouse_delta.x * MOUSE_ROTATE_DEGREES_PER_PIXEL)
			# Perspective modes share vertical orbit; top-down keeps its authored pitch.
			if camera_mode != CameraMode.TOP_DOWN and not is_zero_approx(mouse_delta.y):
				look_pitch_degrees(-mouse_delta.y * MOUSE_ROTATE_DEGREES_PER_PIXEL)
		_mouse_rotation_armed = true
		drag_rotating_view = true
	else:
		_mouse_rotation_armed = false
		drag_rotating_view = false
	_last_mouse_position = mouse_position


func rotate_view_degrees(delta_degrees: float) -> void:
	camera.rotation_degrees.y = wrapf(camera.rotation_degrees.y + delta_degrees, -180.0, 180.0)
	follow_player(true, 0.0)
	_sync_player_facing_to_camera()


func look_pitch_degrees(delta_degrees: float) -> void:
	if camera_mode == CameraMode.TOP_DOWN:
		return
	var min_pitch := FIRST_PERSON_MIN_PITCH_DEGREES
	var max_pitch := FIRST_PERSON_MAX_PITCH_DEGREES
	if camera_mode == CameraMode.THIRD_PERSON:
		min_pitch = THIRD_PERSON_MIN_PITCH_DEGREES
		max_pitch = THIRD_PERSON_MAX_PITCH_DEGREES
	# Avoid crossing the vertical poles, which would make yaw and movement flip.
	camera.rotation_degrees.x = clampf(
		camera.rotation_degrees.x + delta_degrees,
		min_pitch,
		max_pitch
	)
	if camera_mode == CameraMode.THIRD_PERSON:
		# Pitch changes the orbit boom; snap so the follow distance stays exact.
		follow_player(true, 0.0)


## Compatibility wrapper for callers that only intend first-person free look.
func look_first_person_degrees(delta_degrees: float) -> void:
	if not first_person:
		return
	look_pitch_degrees(delta_degrees)


func zoom_view_steps(steps: float) -> void:
	if is_zero_approx(steps):
		return
	match camera_mode:
		CameraMode.TOP_DOWN:
			# Same continuum as the follow boom: zoom-in past the close ortho
			# threshold restores third-person at the farthest boom.
			var next_size := camera.size * pow(ZOOM_STEP_FACTOR, steps)
			if next_size < ZOOM_MIN_ORTHOGRAPHIC_SIZE and steps > 0.0:
				_third_person_distance = THIRD_PERSON_MAX_DISTANCE
				set_camera_mode(CameraMode.THIRD_PERSON)
				return
			camera.size = clampf(
				next_size,
				ZOOM_MIN_ORTHOGRAPHIC_SIZE,
				ZOOM_MAX_ORTHOGRAPHIC_SIZE
			)
			_top_down_size = camera.size
		CameraMode.THIRD_PERSON:
			# Same wheel polarity as top-down: positive steps pull the boom closer.
			var next_distance := _third_person_distance * pow(ZOOM_STEP_FACTOR, steps)
			if next_distance < THIRD_PERSON_MIN_DISTANCE:
				# Crossing the close threshold enters eye-height first-person.
				_third_person_distance = THIRD_PERSON_MIN_DISTANCE
				set_camera_mode(CameraMode.FIRST_PERSON)
				return
			if next_distance > THIRD_PERSON_MAX_DISTANCE:
				# Crossing the far threshold enters the orthographic overview.
				_third_person_distance = THIRD_PERSON_MAX_DISTANCE
				set_camera_mode(CameraMode.TOP_DOWN)
				return
			_third_person_distance = clampf(
				next_distance,
				THIRD_PERSON_MIN_DISTANCE,
				THIRD_PERSON_MAX_DISTANCE
			)
			follow_player(true, 0.0)
		CameraMode.FIRST_PERSON:
			# Scroll-out restores the closest third-person boom; scroll-in is a no-op.
			if steps < 0.0:
				_third_person_distance = THIRD_PERSON_MIN_DISTANCE
				set_camera_mode(CameraMode.THIRD_PERSON)


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
		_top_down_size = camera.size
	camera_mode = next_mode
	_apply_camera_mode()


func _apply_camera_mode() -> void:
	match camera_mode:
		CameraMode.THIRD_PERSON:
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			camera.fov = THIRD_PERSON_FOV_DEGREES
			camera.near = THIRD_PERSON_NEAR
			camera.rotation_degrees.x = THIRD_PERSON_PITCH_DEGREES
		CameraMode.FIRST_PERSON:
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			camera.fov = FIRST_PERSON_FOV_DEGREES
			camera.near = FIRST_PERSON_NEAR
			camera.rotation_degrees.x = FIRST_PERSON_PITCH_DEGREES
		CameraMode.TOP_DOWN:
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.size = _top_down_size
			camera.near = TOP_DOWN_NEAR
			camera.rotation_degrees.x = MapView3D.CAMERA_PITCH_DEGREES
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
	# First-person hides the rig. Enclosed interiors keep the silhouette off:
	# the follow boom often clips perimeter walls/ceilings, and the X-ray ghost
	# reads as a constant "skeleton" rather than helpful outdoor occlusion.
	if (
		first_person
		or (
			view != null
			and view.definition != null
			and view.definition.suppresses_exterior_surroundings()
		)
	):
		player_rig.set_occlusion_ghost(false)
		return
	# Probe from body samples to the real camera, not to camera+height. The old
	# offset aimed above the lens and false-triggered room ceilings indoors.
	var to_camera := camera.position
	var occluded := false
	for height in OCCLUSION_PROBE_HEIGHTS:
		var from := player_rig.position + Vector3.UP * height
		if view.is_segment_occluded(from, to_camera):
			occluded = true
			break
	player_rig.set_occlusion_ghost(occluded)
