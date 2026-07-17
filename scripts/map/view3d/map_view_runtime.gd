class_name MapViewRuntime
extends Node3D

## D-001 gameplay presentation: upgrades a bootstrapped 2D map scene to the
## ADR 0007 3D orthographic view. The 2D logic plane keeps running collision,
## navigation, doors, and spawns; this node only hides the flat 2D drawing,
## mounts MapView3D, mirrors logic actors onto shared character rigs, and
## follows the player with a gameplay-scale camera. Positions flow one way,
## logic to view, through MapViewBridge.

const PLAYER_RIG_SCENE := preload("res://assets/characters/kalev/kalev.tscn")

## Gameplay camera: frozen 64 px character target from CharacterScale, with
## light smoothing so door spawns snap and walking glides.
const FOLLOW_LERP_WEIGHT := 8.0
const SNAP_DISTANCE_WORLD := 6.0
const WALK_ANIMATION_MIN_SPEED := 5.0
## Logic px/s above which locomotion reads as running (midpoint between the
## player's walk and run speeds).
const RUN_ANIMATION_MIN_SPEED := 170.0
const INPUT_PROJECTION_SAMPLE_PX := 64.0
## Orthographic zoom keeps the player-centered orbit intact while changing how
## much of the map is visible. Limits prevent clipping into the character or
## zooming so far out that gameplay-scale details become unreadable.
const ZOOM_STEP_FACTOR := 0.9
const ZOOM_MIN_ORTHOGRAPHIC_SIZE := CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE * 0.5
const ZOOM_MAX_ORTHOGRAPHIC_SIZE := CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE * 2.0
## Holding Page Up / Page Down, or dragging with the right mouse button, orbits
## the dimetric camera smoothly around the player so facades the default angle
## hides stay reachable.
const ROTATE_SPEED_DEGREES := 120.0
const MOUSE_ROTATE_DEGREES_PER_PIXEL := 0.3
## Rig heights (world units, of the frozen 2.0-unit character) probed toward
## the camera to decide when the occluded-player silhouette should show.
const OCCLUSION_PROBE_HEIGHTS: Array[float] = [0.5, 1.1, 1.8]

var view: MapView3D

var _definition: MapDefinition
var _player: CharacterBody2D
var _player_rig: SharedCharacterRig
var _camera: Camera3D
var _drag_rotating_view := false
var _last_facing := Vector2.ZERO


static func install(scene_root: Node2D, bootstrap: Dictionary, map_root: CanvasItem, player: CharacterBody2D) -> MapViewRuntime:
	var runtime := MapViewRuntime.new()
	runtime.name = "MapViewRuntime"
	runtime._definition = bootstrap["definition"]
	runtime._player = player
	runtime.view = MapView3D.create(bootstrap["definition"], bootstrap["grid"])
	runtime.add_child(runtime.view)

	map_root.visible = false
	_hide_flat_map_visuals(bootstrap)
	_hide_player_canvas(player)

	runtime._player_rig = PLAYER_RIG_SCENE.instantiate()
	runtime._player_rig.name = "PlayerRig"
	runtime._player_rig.add_to_group(&"player_view_rig")
	runtime.add_child(runtime._player_rig)

	runtime._camera = runtime.view.view_camera()
	runtime._camera.size = CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE

	scene_root.add_child(runtime)
	runtime._configure_screen_relative_movement()
	runtime._last_facing = runtime._logic_direction_toward_camera()
	runtime._sync_player(true)
	return runtime


## Projects a screen point through the gameplay camera onto the logic plane,
## so click-to-move keeps working against what the player actually sees.
func logic_position_at_screen(screen_position: Vector2) -> Vector2:
	var origin := _camera.project_ray_origin(screen_position)
	var direction := _camera.project_ray_normal(screen_position)
	if is_zero_approx(direction.y):
		return MapViewBridge.world_to_logic(origin, _definition.cell_size)
	var distance := -origin.y / direction.y
	return MapViewBridge.world_to_logic(origin + direction * distance, _definition.cell_size)


func set_time_of_day(next_time: StringName) -> void:
	view.set_time_of_day(next_time)


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_apply_view_rotation(delta)
	_sync_player(false, delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_RIGHT:
			_drag_rotating_view = mouse_button.pressed
			get_viewport().set_input_as_handled()
			return
		if not mouse_button.pressed:
			return
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_view_steps(mouse_button.factor)
		elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_view_steps(-mouse_button.factor)
		else:
			return
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and _drag_rotating_view:
		var mouse_motion := event as InputEventMouseMotion
		rotate_view_degrees(-mouse_motion.relative.x * MOUSE_ROTATE_DEGREES_PER_PIXEL)
		get_viewport().set_input_as_handled()


## Positive steps zoom in and negative steps zoom out. Exponential scaling
## gives mouse wheels and high-resolution trackpads the same proportional feel.
func zoom_view_steps(steps: float) -> void:
	_camera.size = clampf(
		_camera.size * pow(ZOOM_STEP_FACTOR, steps),
		ZOOM_MIN_ORTHOGRAPHIC_SIZE,
		ZOOM_MAX_ORTHOGRAPHIC_SIZE
	)


func _apply_view_rotation(delta: float) -> void:
	if _drag_rotating_view and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_drag_rotating_view = false
	var direction := 0.0
	if Input.is_key_pressed(KEY_PAGEUP):
		direction += 1.0
	if Input.is_key_pressed(KEY_PAGEDOWN):
		direction -= 1.0
	if direction == 0.0:
		return
	rotate_view_degrees(direction * ROTATE_SPEED_DEGREES * delta)


## Orbits the gameplay camera around the player by an arbitrary angle, then
## re-projects the keyboard axes so screen-relative movement stays intuitive.
func rotate_view_degrees(delta_degrees: float) -> void:
	_camera.rotation_degrees.y = wrapf(_camera.rotation_degrees.y + delta_degrees, -180.0, 180.0)
	_follow_player(true, 0.0)
	_configure_screen_relative_movement()


func _sync_player(snap: bool, delta: float = 0.0) -> void:
	view.sync_actor(_player_rig, _player.global_position)
	_follow_player(snap, delta)
	var speed := _player.velocity.length()
	var moving := speed > WALK_ANIMATION_MIN_SPEED
	if moving:
		_last_facing = _player.velocity.normalized()
	var facing := _player.velocity if moving else _last_facing
	if snap:
		_player_rig.set_facing(facing)
	else:
		_player_rig.face_toward(facing, delta)
	var wanted: StringName = &"idle"
	if moving:
		wanted = &"run" if speed > RUN_ANIMATION_MIN_SPEED else &"walk"
	if _player_rig.current_canonical_animation() != wanted:
		_player_rig.play_animation(wanted)
	_player_rig.set_locomotion_speed(speed * MapViewBridge.world_scale(_definition.cell_size))
	_update_occlusion_ghost()


func _update_occlusion_ghost() -> void:
	var toward_camera := _camera.transform.basis.z * MapView3D.CAMERA_DISTANCE
	var occluded := false
	for height in OCCLUSION_PROBE_HEIGHTS:
		var from := _player_rig.position + Vector3.UP * height
		if view.is_segment_occluded(from, from + toward_camera):
			occluded = true
			break
	_player_rig.set_occlusion_ghost(occluded)


func _configure_screen_relative_movement() -> void:
	if not _player.has_method("set_screen_movement_basis"):
		return
	var viewport_size := _camera.get_viewport().get_visible_rect().size
	var center := viewport_size * 0.5
	var center_logic := logic_position_at_screen(center)
	var logic_right := logic_position_at_screen(center + Vector2(INPUT_PROJECTION_SAMPLE_PX, 0.0)) - center_logic
	var logic_down := logic_position_at_screen(center + Vector2(0.0, INPUT_PROJECTION_SAMPLE_PX)) - center_logic
	_player.call("set_screen_movement_basis", logic_right, logic_down)


func _logic_direction_toward_camera() -> Vector2:
	var world_offset := _camera.position - _player_rig.position
	return Vector2(world_offset.x, world_offset.z).normalized()


func _follow_player(snap: bool, delta: float) -> void:
	var target := _player_rig.position + _camera.transform.basis.z * MapView3D.CAMERA_DISTANCE
	if snap or _camera.position.distance_to(target) > SNAP_DISTANCE_WORLD:
		_camera.position = target
		return
	_camera.position = _camera.position.lerp(target, clampf(FOLLOW_LERP_WEIGHT * delta, 0.0, 1.0))


static func _hide_player_canvas(player: CharacterBody2D) -> void:
	# The rig replaces the greybox rectangle; bars re-home to real UI later.
	for node_name in ["GreyboxVisual", "HealthBar", "StaminaBar"]:
		var node := player.get_node_or_null(node_name) as CanvasItem
		if node != null:
			node.visible = false


static func _hide_flat_map_visuals(bootstrap: Dictionary) -> void:
	# Buildings and props are hosted under Actors so their 2D collision remains
	# Y-sorted with the player. Hide the render nodes explicitly; CanvasItem
	# visibility does not disable the StaticBody2D collision used by gameplay.
	var assembled: Dictionary = bootstrap.get("assembled", {})
	for key: String in ["terrain", "buildings", "props"]:
		var value: Variant = assembled.get(key)
		if value is CanvasItem:
			(value as CanvasItem).visible = false
		elif value is Array:
			for item: Variant in value as Array:
				if item is CanvasItem:
					(item as CanvasItem).visible = false
