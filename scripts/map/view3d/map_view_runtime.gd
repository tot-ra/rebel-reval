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
## Page Up / Page Down orbit the dimetric camera in fixed steps so players can
## look at facades the default angle hides.
const ROTATE_STEP_DEGREES := 45.0

var view: MapView3D

var _definition: MapDefinition
var _player: CharacterBody2D
var _player_rig: SharedCharacterRig
var _camera: Camera3D


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
	runtime.add_child(runtime._player_rig)

	runtime._camera = runtime.view.view_camera()
	runtime._camera.size = CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE

	scene_root.add_child(runtime)
	runtime._configure_screen_relative_movement()
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
	_sync_player(false, delta)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_PAGEUP:
		rotate_view(1)
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_PAGEDOWN:
		rotate_view(-1)
		get_viewport().set_input_as_handled()


## Rotates the gameplay camera by whole steps around the player, then
## re-projects the keyboard axes so screen-relative movement stays intuitive.
func rotate_view(steps: int) -> void:
	_camera.rotation_degrees.y = wrapf(
		_camera.rotation_degrees.y + float(steps) * ROTATE_STEP_DEGREES, -180.0, 180.0
	)
	_follow_player(true, 0.0)
	_configure_screen_relative_movement()


func _sync_player(snap: bool, delta: float = 0.0) -> void:
	view.sync_actor(_player_rig, _player.global_position)
	_follow_player(snap, delta)
	var speed := _player.velocity.length()
	var moving := speed > WALK_ANIMATION_MIN_SPEED
	var facing := _player.velocity if moving else _logic_direction_toward_camera()
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
