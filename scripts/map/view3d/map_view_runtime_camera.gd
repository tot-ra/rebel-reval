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
## Interior follow targets this close to the floor edge count as wall clips. The
## authored perimeter walls occupy a full cell, so leave that cell plus a small
## lens/mesh buffer between the camera and the room boundary. Without this
## clearance, the safety pass alternates between the wall AABB and the boom target.
const INTERIOR_FLOOR_EDGE_MARGIN := 1.05
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
## Frozen practical-camera attributes (P0-143). Orthographic top-down clears them so
## the overview stays fully sharp and does not fight the fixed ortho size.
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
## Safety: prevent camera from clipping through terrain, buildings, or losing
## sight of the player. Ground clamping pulls the camera above the terrain
## height map; building collision slides it out of building AABBs toward the
## player; visibility safety snaps closer when the player is fully occluded.
const GROUND_CLEARANCE := 0.3
const BUILDING_PULL_ITERATIONS := 4
const BUILDING_PULL_STEP := 0.6
const VISIBILITY_PULL_STEP := 0.6
const VISIBILITY_PULL_ITERATIONS := 4
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
var _perspective_attributes: CameraAttributesPractical


func configure(runtime_camera: Camera3D, runtime_player_rig: SharedCharacterRig, runtime_view: MapView3D, runtime_player: CharacterBody2D) -> void:
	camera = runtime_camera
	player_rig = runtime_player_rig
	view = runtime_view
	player = runtime_player
	_top_down_size = camera.size
	_third_person_distance = THIRD_PERSON_DISTANCE
	_perspective_attributes = CameraAttributesPractical.new()
	_apply_camera_mode()


func perspective_camera_attributes() -> CameraAttributesPractical:
	return _perspective_attributes


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
	else:
		var lerped := camera.position.lerp(target, clampf(FOLLOW_LERP_WEIGHT * delta, 0.0, 1.0))
		camera.position = _apply_screen_shake(delta, lerped)
	_enforce_camera_safety()
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


func _resolve_third_person_target(target: Vector3) -> Vector3:
	if view == null or view.definition == null:
		return target
	var anchor := player_rig.position + Vector3.UP * THIRD_PERSON_TARGET_HEIGHT
	var direction := target - anchor
	var distance := direction.length()
	if is_zero_approx(distance):
		return target
	direction /= distance
	# Interior maps enforce floor-edge margins so the boom stays inside the room.
	# Exterior maps pull the target out of any building/landmark AABB it enters.
	if view.definition.suppresses_exterior_surroundings():
		while distance > THIRD_PERSON_MIN_DISTANCE and _third_person_target_clips(target):
			distance = maxf(THIRD_PERSON_MIN_DISTANCE, distance * 0.75)
			target = anchor + direction * distance
	else:
		while distance > THIRD_PERSON_MIN_DISTANCE and view.is_point_inside_occluder(target):
			distance = maxf(THIRD_PERSON_MIN_DISTANCE, distance * 0.75)
			target = anchor + direction * distance
	if view.definition.suppresses_exterior_surroundings():
		# A minimum boom can still leave a player near a perimeter wall with the
		# lens inside that wall's AABB. Clamp the final target to the walkable room
		# envelope so the next-frame safety pass cannot pull it back and forth.
		return _clamp_interior_target(target)
	return target


func _clamp_interior_target(target: Vector3) -> Vector3:
	var size := view.definition.size_cells
	var min_edge := INTERIOR_FLOOR_EDGE_MARGIN
	var max_x := maxf(min_edge, float(size.x) - min_edge)
	var max_z := maxf(min_edge, float(size.y) - min_edge)
	target.x = clampf(target.x, min_edge, max_x)
	target.z = clampf(target.z, min_edge, max_z)
	return target


func _third_person_target_clips(target: Vector3) -> bool:
	if view.is_point_inside_occluder(target):
		return true
	var size := view.definition.size_cells
	return (
		target.x < INTERIOR_FLOOR_EDGE_MARGIN
		or target.x > float(size.x) - INTERIOR_FLOOR_EDGE_MARGIN
		or target.z < INTERIOR_FLOOR_EDGE_MARGIN
		or target.z > float(size.y) - INTERIOR_FLOOR_EDGE_MARGIN
	)


func _follow_target() -> Vector3:
	match camera_mode:
		CameraMode.FIRST_PERSON:
			return player_rig.position + Vector3.UP * FIRST_PERSON_EYE_HEIGHT
		CameraMode.THIRD_PERSON:
			return _resolve_third_person_target(
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


func _apply_perspective_camera_attributes() -> void:
	if _perspective_attributes == null:
		return
	if _supports_auto_exposure():
		_perspective_attributes.auto_exposure_enabled = PERSPECTIVE_AUTO_EXPOSURE_ENABLED
		_perspective_attributes.auto_exposure_scale = PERSPECTIVE_AUTO_EXPOSURE_SCALE
		_perspective_attributes.auto_exposure_speed = PERSPECTIVE_AUTO_EXPOSURE_SPEED
		_perspective_attributes.exposure_sensitivity = PERSPECTIVE_EXPOSURE_SENSITIVITY
	if not _supports_depth_of_field():
		# Compatibility does not implement DOF and logs a warning when blur is enabled.
		# Keep practical exposure attributes active while leaving unsupported blur off.
		_perspective_attributes.dof_blur_near_enabled = false
		_perspective_attributes.dof_blur_far_enabled = false
		camera.attributes = _perspective_attributes
		return
	_perspective_attributes.dof_blur_near_enabled = false
	_perspective_attributes.dof_blur_far_enabled = true
	match camera_mode:
		CameraMode.THIRD_PERSON:
			_perspective_attributes.dof_blur_amount = THIRD_PERSON_DOF_BLUR_AMOUNT
			_perspective_attributes.dof_blur_far_distance = THIRD_PERSON_DOF_FAR_DISTANCE
			_perspective_attributes.dof_blur_far_transition = THIRD_PERSON_DOF_FAR_TRANSITION
		CameraMode.FIRST_PERSON:
			_perspective_attributes.dof_blur_amount = FIRST_PERSON_DOF_BLUR_AMOUNT
			_perspective_attributes.dof_blur_far_distance = FIRST_PERSON_DOF_FAR_DISTANCE
			_perspective_attributes.dof_blur_far_transition = FIRST_PERSON_DOF_FAR_TRANSITION
		_:
			return
	camera.attributes = _perspective_attributes


func _supports_auto_exposure() -> bool:
	return str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")) == "forward_plus"


func _supports_depth_of_field() -> bool:
	var rendering_method := str(ProjectSettings.get_setting("rendering/renderer/rendering_method", ""))
	return rendering_method in ["forward_plus", "mobile"]


func _clear_camera_attributes() -> void:
	camera.attributes = null


func _apply_camera_mode() -> void:
	match camera_mode:
		CameraMode.THIRD_PERSON:
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			camera.fov = THIRD_PERSON_FOV_DEGREES
			camera.near = THIRD_PERSON_NEAR
			camera.rotation_degrees.x = THIRD_PERSON_PITCH_DEGREES
			_apply_perspective_camera_attributes()
		CameraMode.FIRST_PERSON:
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			camera.fov = FIRST_PERSON_FOV_DEGREES
			camera.near = FIRST_PERSON_NEAR
			camera.rotation_degrees.x = FIRST_PERSON_PITCH_DEGREES
			_apply_perspective_camera_attributes()
		CameraMode.TOP_DOWN:
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.size = _top_down_size
			camera.near = TOP_DOWN_NEAR
			camera.rotation_degrees.x = MapView3D.CAMERA_PITCH_DEGREES
			_clear_camera_attributes()
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


## Post-follow safety: clamp above ground, pull out of buildings, and ensure
## the camera can still see the player. Called every frame after position is
## set so both snap and lerp paths stay safe.
func _enforce_camera_safety() -> void:
	_clamp_above_ground()
	_pull_out_of_buildings()
	_ensure_player_visible()


## Prevent the camera from sinking below the terrain height field. The margin
## (GROUND_CLEARANCE) avoids z-fighting and gives a comfortable buffer above
## grass/paving relief that the height field alone does not capture.
func _clamp_above_ground() -> void:
	if view == null or view.definition == null:
		return
	var world_xz := Vector2(camera.position.x, camera.position.z)
	var terrain_y := MapViewMeshBuilder.ground_height(view.definition, world_xz)
	var min_y := terrain_y + GROUND_CLEARANCE
	if camera.position.y < min_y:
		camera.position.y = min_y


## When the camera lands inside a building/landmark AABB (e.g. after a sharp
## pitch orbit or lerp through geometry), slide it toward the player until it
## exits the occluder. Keeps the player visible and avoids interior-flicker.
func _pull_out_of_buildings() -> void:
	if view == null:
		return
	if not view.is_point_inside_occluder(camera.position):
		return
	var player_pos := player_rig.position
	for i in range(BUILDING_PULL_ITERATIONS):
		camera.position = camera.position.lerp(player_pos, BUILDING_PULL_STEP)
		if not view.is_point_inside_occluder(camera.position):
			break
	# Hard fallback: if still inside after iterations, place just outside the
	# nearest occluder by pushing toward the player at minimum boom distance.
	if view.is_point_inside_occluder(camera.position):
		var to_camera := (camera.position - player_pos)
		if to_camera.length_squared() > 0.01:
			camera.position = player_pos + to_camera.normalized() * THIRD_PERSON_MIN_DISTANCE
		else:
			camera.position = player_pos + Vector3.UP * THIRD_PERSON_TARGET_HEIGHT


## Final safety net: if the camera-to-player segment is fully occluded by
## buildings/terrain (e.g. camera ended up behind a wall), pull the camera
## closer until the line-of-sight is clear. In top-down mode the occlusion
## ghost overlay handles the visual; this mostly fires for third-person.
func _ensure_player_visible() -> void:
	if view == null:
		return
	# Enclosed interiors have authored perimeter walls by design. The camera and
	# player are both constrained to the same room envelope, so treating a wall
	# as outdoor line-of-sight occlusion would pull the lens back toward the actor
	# every frame and fight the stable interior target above.
	if view.definition != null and view.definition.suppresses_exterior_surroundings():
		return
	var player_pos := player_rig.position
	if not view.is_segment_occluded(camera.position, player_pos):
		return
	# Top-down mode intentionally allows occlusion (shows skeleton ghost);
	# only correct third-person and first-person to avoid disorientation.
	if camera_mode == CameraMode.TOP_DOWN:
		return
	var dir := camera.position - player_pos
	var distance := dir.length()
	if distance < 0.1:
		return
	dir /= distance
	for i in range(VISIBILITY_PULL_ITERATIONS):
		distance *= VISIBILITY_PULL_STEP
		if distance < THIRD_PERSON_MIN_DISTANCE:
			break
		var candidate := player_pos + dir * distance
		if not view.is_segment_occluded(candidate, player_pos):
			camera.position = candidate
			return
	# Last resort: place the camera at the player's eye level so at least the
	# player is visible; ground/building clamping will re-correct on next tick.
	camera.position = player_pos + Vector3.UP * THIRD_PERSON_TARGET_HEIGHT


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
