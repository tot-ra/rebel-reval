class_name MapViewRuntime
extends Node3D

## D-001 gameplay presentation: upgrades a bootstrapped 2D map scene to the
## ADR 0007 3D orthographic view. The 2D logic plane keeps running collision,
## navigation, doors, and spawns; this node only hides the flat 2D drawing,
## mounts MapView3D, mirrors logic actors onto shared character rigs, and
## follows the player with a gameplay-scale camera. Positions flow one way,
## logic to view, through MapViewBridge.

const PLAYER_RIG_SCENE := preload("res://assets/characters/kalev/kalev.tscn")
const DayNightCycle := preload("res://scripts/global/day_night_cycle.gd")

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
const ZOOM_MIN_FACTOR := 0.3
const ZOOM_MAX_FACTOR := 1.5
const ZOOM_MIN_ORTHOGRAPHIC_SIZE := CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE * ZOOM_MIN_FACTOR
const ZOOM_MAX_ORTHOGRAPHIC_SIZE := CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE * ZOOM_MAX_FACTOR
## Holding Page Up / Page Down, or dragging with the right mouse button, orbits
## the dimetric camera smoothly around the player so facades the default angle
## hides stay reachable.
const ROTATE_SPEED_DEGREES := 120.0
const MOUSE_ROTATE_DEGREES_PER_PIXEL := 0.3
## Rig heights (world units, of the frozen 2.0-unit character) probed toward
## the camera to decide when the occluded-player silhouette should show.
const OCCLUSION_PROBE_HEIGHTS: Array[float] = [0.5, 1.1, 1.8]

var view: MapView3D

## Dev pacing: one in-game day every DayNightCycle.CYCLE_DURATION_SECONDS.
var cycle_enabled := true
var cycle_progress := DayNightCycle.DEFAULT_PROGRESS

var _definition: MapDefinition
var _player: CharacterBody2D
var _player_rig: SharedCharacterRig
var _camera: Camera3D
var _drag_rotating_view := false
var _mouse_rotation_armed := false
var _last_mouse_position := Vector2.ZERO
var _last_facing := Vector2.ZERO
var _actor_rigs: Dictionary = {}
var _equipment_state: GameState


static func install(scene_root: Node2D, bootstrap: Dictionary, map_root: CanvasItem, player: CharacterBody2D) -> MapViewRuntime:
	var runtime := MapViewRuntime.new()
	runtime.name = "MapViewRuntime"
	runtime._definition = bootstrap["definition"]
	runtime._player = player
	runtime.view = MapView3D.create(bootstrap["definition"], bootstrap["grid"])
	runtime.add_child(runtime.view)

	map_root.visible = false
	_hide_flat_map_visuals(bootstrap)
	_bind_streamed_flat_visual_hiding(bootstrap)
	_hide_player_canvas(player)

	runtime._player_rig = PLAYER_RIG_SCENE.instantiate()
	runtime._player_rig.name = "PlayerRig"
	runtime._player_rig.add_to_group(&"player_view_rig")
	runtime.add_child(runtime._player_rig)

	runtime._camera = runtime.view.view_camera()
	runtime._camera.size = CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE

	scene_root.add_child(runtime)
	# Created at runtime, so enable input explicitly before the first frame.
	runtime.set_process_unhandled_input(true)
	runtime._bind_equipment_state()
	if not SessionState.debug_state_applied.is_connected(runtime._on_debug_state_applied):
		SessionState.debug_state_applied.connect(runtime._on_debug_state_applied)
	runtime._register_view_actors(scene_root)
	runtime._configure_screen_relative_movement()
	runtime._sync_player(true)
	runtime.view.apply_cycle_progress(runtime.cycle_progress)
	runtime._sync_music_cycle()
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
	cycle_enabled = false
	view.set_time_of_day(next_time)
	cycle_progress = 0.5 if next_time == MapView3D.TIME_DAY else 0.0
	_sync_music_cycle()


func _process(delta: float) -> void:
	if cycle_enabled:
		cycle_progress = DayNightCycle.advance(cycle_progress, delta)
		view.apply_cycle_progress(cycle_progress)
		_sync_music_cycle()
	if _player == null or not is_instance_valid(_player):
		return
	_apply_view_rotation(delta)
	_sync_player(false, delta)
	_sync_view_actors(delta)


func _register_view_actors(scene_root: Node) -> void:
	for found: Node in scene_root.find_children("*", "", true, false):
		if not found.is_in_group(&"map_view_actor") or not found is Node2D:
			continue
		var actor := found as Node2D
		var rig_scene: PackedScene = actor.get("rig_scene") as PackedScene
		if rig_scene == null:
			push_warning("Map view actor %s has no rig_scene" % actor.name)
			continue
		var rig := rig_scene.instantiate() as SharedCharacterRig
		if rig == null:
			push_warning("Map view actor %s rig is not a SharedCharacterRig" % actor.name)
			continue
		rig.name = "%sRig" % actor.name
		add_child(rig)
		_actor_rigs[actor] = rig
		_hide_actor_canvas(actor)
		_sync_view_actor(actor, rig, true, 0.0)


func _sync_view_actors(delta: float) -> void:
	for actor: Node2D in _actor_rigs.keys():
		if not is_instance_valid(actor):
			var stale_rig: SharedCharacterRig = _actor_rigs[actor]
			if is_instance_valid(stale_rig):
				stale_rig.queue_free()
			_actor_rigs.erase(actor)
			continue
		_sync_view_actor(actor, _actor_rigs[actor] as SharedCharacterRig, false, delta)


func _sync_view_actor(
	actor: Node2D,
	rig: SharedCharacterRig,
	snap: bool,
	delta: float
) -> void:
	view.sync_actor(rig, actor.global_position)
	var facing := Vector2.DOWN
	if actor.has_method("view_facing"):
		facing = actor.call("view_facing") as Vector2
	if snap:
		rig.set_facing(facing)
	else:
		rig.face_toward(facing, delta)
	var wanted := &"idle"
	if actor.has_method("view_animation"):
		wanted = actor.call("view_animation") as StringName
	# Newly added rigs enter the tree on add_child(), so their AnimationPlayer
	# is ready before we ask for a canonical state.
	if not rig.is_node_ready():
		return
	if rig.current_canonical_animation() != wanted:
		rig.play_animation(wanted)
	var actor_velocity := actor.get("velocity") as Vector2
	rig.set_locomotion_speed(actor_velocity.length() * MapViewBridge.world_scale(_definition.cell_size))


static func _hide_actor_canvas(actor: Node2D) -> void:
	for child: Node in actor.get_children():
		if child is CanvasItem and not child is CollisionShape2D and not child is NavigationAgent2D:
			(child as CanvasItem).visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if not mouse_button.pressed:
			return
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_view_steps(mouse_button.factor)
		elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_view_steps(-mouse_button.factor)
		else:
			return
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
	_apply_mouse_rotation_drag()
	var direction := 0.0
	if Input.is_key_pressed(KEY_PAGEUP):
		direction += 1.0
	if Input.is_key_pressed(KEY_PAGEDOWN):
		direction -= 1.0
	if direction == 0.0:
		return
	rotate_view_degrees(direction * ROTATE_SPEED_DEGREES * delta)


## Polls mouse position while RMB is held so camera orbit keeps working even
## when UI nodes or input actions consume the underlying mouse-button events.
func _apply_mouse_rotation_drag() -> void:
	_apply_mouse_rotation_from_position(
		get_viewport().get_mouse_position(),
		Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	)


func _apply_mouse_rotation_from_position(mouse_position: Vector2, button_pressed: bool) -> void:
	if button_pressed:
		if _mouse_rotation_armed:
			var delta_x := mouse_position.x - _last_mouse_position.x
			if not is_zero_approx(delta_x):
				rotate_view_degrees(-delta_x * MOUSE_ROTATE_DEGREES_PER_PIXEL)
		_mouse_rotation_armed = true
		_drag_rotating_view = true
	else:
		_mouse_rotation_armed = false
		_drag_rotating_view = false
	_last_mouse_position = mouse_position


func is_camera_drag_active() -> bool:
	return _drag_rotating_view


## Orbits the gameplay camera around the player by an arbitrary angle, then
## re-projects the keyboard axes so screen-relative movement stays intuitive.
func rotate_view_degrees(delta_degrees: float) -> void:
	_camera.rotation_degrees.y = wrapf(_camera.rotation_degrees.y + delta_degrees, -180.0, 180.0)
	_follow_player(true, 0.0)
	_configure_screen_relative_movement()


func _sync_music_cycle() -> void:
	MusicDirector.set_cycle_progress(cycle_progress)


func _sync_player(snap: bool, delta: float = 0.0) -> void:
	view.sync_actor(_player_rig, _player.global_position)
	_follow_player(snap, delta)
	var speed := _player.velocity.length()
	var moving := speed > WALK_ANIMATION_MIN_SPEED
	if moving:
		_last_facing = _player.velocity.normalized()
	elif _last_facing.is_zero_approx():
		# Spawn-facing must use the snapped camera offset, not pre-sync positions.
		_last_facing = _logic_direction_toward_camera()
	var facing := _player.velocity if moving else _last_facing
	if _player.has_method("view_facing"):
		facing = _player.call("view_facing") as Vector2
		if not facing.is_zero_approx():
			_last_facing = facing.normalized()
	if snap or not moving:
		_player_rig.set_facing(facing)
	else:
		_player_rig.face_toward(facing, delta)
	var wanted: StringName = &"idle"
	if _player.has_method("view_animation"):
		wanted = _player.call("view_animation") as StringName
	elif moving:
		wanted = &"run" if speed > RUN_ANIMATION_MIN_SPEED else &"walk"
	if _player_rig.current_canonical_animation() != wanted:
		_player_rig.play_animation(wanted)
	_player_rig.set_locomotion_speed(speed * MapViewBridge.world_scale(_definition.cell_size))
	_update_occlusion_ghost()


## The session GameState owns what Kalev wears; the variant's authored
## equipment is only a default for showcase scenes. Mirror the state now and
## on every equipment change.
func _exit_tree() -> void:
	if SessionState.debug_state_applied.is_connected(_on_debug_state_applied):
		SessionState.debug_state_applied.disconnect(_on_debug_state_applied)
	_disconnect_equipment_state()


func _on_debug_state_applied(_preset_id: StringName) -> void:
	_bind_equipment_state()


func _bind_equipment_state() -> void:
	_disconnect_equipment_state()
	_equipment_state = SessionState.state
	if _equipment_state == null:
		return
	for slot: StringName in SharedCharacterRig.EQUIPMENT_SLOTS:
		_sync_equipment_slot(slot)
	if not _equipment_state.equipment_changed.is_connected(_sync_equipment_slot):
		_equipment_state.equipment_changed.connect(_sync_equipment_slot)


func _disconnect_equipment_state() -> void:
	if _equipment_state == null:
		return
	if _equipment_state.equipment_changed.is_connected(_sync_equipment_slot):
		_equipment_state.equipment_changed.disconnect(_sync_equipment_slot)
	_equipment_state = null


func _sync_equipment_slot(slot: StringName) -> void:
	var state := SessionState.state
	var item_id := state.equipped_item(slot)
	if item_id.is_empty():
		_player_rig.unequip(slot)
		return
	var record: Dictionary = SessionState.content_db.get_item(item_id)
	var gameplay: Dictionary = record.get("gameplay", {})
	var equip_info: Dictionary = gameplay.get("equip", {})
	var scene_path := String(equip_info.get("scene", ""))
	if scene_path.is_empty():
		_player_rig.unequip(slot)
		return
	_player_rig.equip(slot, load(scene_path) as PackedScene)


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
	for key: String in ["terrain", "buildings", "props", "view_landmarks"]:
		var value: Variant = assembled.get(key)
		if value is CanvasItem:
			(value as CanvasItem).visible = false
		elif value is Array:
			for item: Variant in value as Array:
				_hide_flat_map_object(item)


static func _bind_streamed_flat_visual_hiding(bootstrap: Dictionary) -> void:
	var assembled: Dictionary = bootstrap.get("assembled", {})
	var streamer: Variant = assembled.get("object_streamer")
	if streamer == null or not streamer.has_signal(&"object_loaded"):
		return
	if not streamer.object_loaded.is_connected(_on_streamed_flat_map_object_loaded):
		streamer.object_loaded.connect(_on_streamed_flat_map_object_loaded)
	for object_id in streamer.loaded_object_ids():
		_hide_flat_map_object(streamer.loaded_instance(object_id))


static func _on_streamed_flat_map_object_loaded(_handle: Dictionary, instance: Node) -> void:
	_hide_flat_map_object(instance)


static func _hide_flat_map_object(item: Variant) -> void:
	if item == null or not item is Node:
		return
	var node := item as Node
	if node is StaticBody2D:
		var visuals := node.get_node_or_null("Visuals") as CanvasItem
		if visuals != null:
			visuals.visible = false
		return
	if node is CanvasItem:
		(node as CanvasItem).visible = false
