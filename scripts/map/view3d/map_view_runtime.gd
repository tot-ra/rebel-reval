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
const RuntimeCamera := preload("res://scripts/map/view3d/map_view_runtime_camera.gd")

const WALK_ANIMATION_MIN_SPEED := 5.0
## Logic px/s above which locomotion reads as running (midpoint between the
## player's walk and run speeds).
const RUN_ANIMATION_MIN_SPEED := 170.0
const INPUT_PROJECTION_SAMPLE_PX := 64.0
## Re-exported for tests and MapView3D preview bounds.
const FOLLOW_LERP_WEIGHT := RuntimeCamera.FOLLOW_LERP_WEIGHT
const SNAP_DISTANCE_WORLD := RuntimeCamera.SNAP_DISTANCE_WORLD
const ZOOM_STEP_FACTOR := RuntimeCamera.ZOOM_STEP_FACTOR
const ZOOM_MIN_FACTOR := RuntimeCamera.ZOOM_MIN_FACTOR
const ZOOM_MAX_FACTOR := RuntimeCamera.ZOOM_MAX_FACTOR
const ZOOM_MIN_ORTHOGRAPHIC_SIZE := RuntimeCamera.ZOOM_MIN_ORTHOGRAPHIC_SIZE
const ZOOM_MAX_ORTHOGRAPHIC_SIZE := RuntimeCamera.ZOOM_MAX_ORTHOGRAPHIC_SIZE
const ROTATE_SPEED_DEGREES := RuntimeCamera.ROTATE_SPEED_DEGREES
const MOUSE_ROTATE_DEGREES_PER_PIXEL := RuntimeCamera.MOUSE_ROTATE_DEGREES_PER_PIXEL
const PAN_SCROLL_ZOOM_SENSITIVITY := RuntimeCamera.PAN_SCROLL_ZOOM_SENSITIVITY
const FIRST_PERSON_EYE_HEIGHT := RuntimeCamera.FIRST_PERSON_EYE_HEIGHT
const FIRST_PERSON_PITCH_DEGREES := RuntimeCamera.FIRST_PERSON_PITCH_DEGREES
const FIRST_PERSON_MIN_PITCH_DEGREES := RuntimeCamera.FIRST_PERSON_MIN_PITCH_DEGREES
const FIRST_PERSON_MAX_PITCH_DEGREES := RuntimeCamera.FIRST_PERSON_MAX_PITCH_DEGREES
const FIRST_PERSON_FOV_DEGREES := RuntimeCamera.FIRST_PERSON_FOV_DEGREES
const FIRST_PERSON_NEAR := RuntimeCamera.FIRST_PERSON_NEAR
const OCCLUSION_PROBE_HEIGHTS := RuntimeCamera.OCCLUSION_PROBE_HEIGHTS

var view: MapView3D

## Dev pacing: one in-game day every DayNightCycle.CYCLE_DURATION_SECONDS.
var cycle_enabled := true
var cycle_progress := DayNightCycle.DEFAULT_PROGRESS

var _definition: MapDefinition
var _player: CharacterBody2D
var _player_rig: SharedCharacterRig
var _camera: Camera3D
var _camera_controller: MapViewRuntimeCamera = RuntimeCamera.new()
var _last_facing := Vector2.ZERO
var _actor_rigs: Dictionary = {}
var _equipment_state: GameState
var _click_input: MapClickInputController


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
	runtime._camera_controller.configure(runtime._camera, runtime._player_rig, runtime.view, runtime._player)

	scene_root.add_child(runtime)
	# Created at runtime, so enable input explicitly before the first frame.
	runtime.set_process_unhandled_input(true)
	runtime._bind_equipment_state(SessionState.state)
	if not SessionState.state_replaced.is_connected(runtime._on_state_replaced):
		SessionState.state_replaced.connect(runtime._on_state_replaced)
	runtime._register_view_actors(scene_root)
	runtime._configure_screen_relative_movement()
	runtime._sync_player(true)
	runtime._bind_player_health_ring()
	runtime.view.apply_cycle_progress(runtime.cycle_progress)
	runtime._sync_music_cycle()
	runtime._install_click_input(scene_root)
	return runtime


func configure_click_input(world_items: WorldItemController = null) -> void:
	if _click_input == null:
		return
	if world_items != null:
		_click_input.set_world_items(world_items)


func _install_click_input(_scene_root: Node2D) -> void:
	# Own the click controller under the runtime so scene tests and forge wiring
	# can resolve MapClickInput as a MapViewRuntime child.
	_click_input = MapClickInputController.new()
	_click_input.name = "MapClickInput"
	add_child(_click_input)
	_click_input.setup(_player, self)


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
	_sync_actor_health_ring(rig, actor)
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
	if event.is_action_pressed(&"toggle_camera_view") and not event.is_echo():
		toggle_camera_view()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		return
	if event is InputEventMagnifyGesture:
		_camera_controller.zoom_from_magnify_factor((event as InputEventMagnifyGesture).factor)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventPanGesture:
		_camera_controller.zoom_from_pan_delta((event as InputEventPanGesture).delta)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		var wheel_steps := 0.0
		var wheel_factor := mouse_button.factor if mouse_button.factor > 0.0 else 1.0
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			wheel_steps = wheel_factor
		elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			wheel_steps = -wheel_factor
		else:
			return
		zoom_view_steps(wheel_steps)
		get_viewport().set_input_as_handled()


func toggle_camera_view() -> void:
	_camera_controller.toggle_first_person()
	_configure_screen_relative_movement()
	_update_occlusion_ghost()


func set_first_person(enabled: bool) -> void:
	_camera_controller.set_first_person(enabled)
	_configure_screen_relative_movement()
	_update_occlusion_ghost()


func is_first_person() -> bool:
	return _camera_controller.first_person


func zoom_view_steps(steps: float) -> void:
	_camera_controller.zoom_view_steps(steps)


func _apply_view_rotation(delta: float) -> void:
	var yaw_before := _camera.rotation_degrees.y
	_camera_controller.apply_view_rotation(delta)
	# First-person look can rotate the camera without going through rotate_view_degrees,
	# so keep keyboard movement tied to the current view every frame.
	if _camera_controller.first_person or not is_equal_approx(_camera.rotation_degrees.y, yaw_before):
		_configure_screen_relative_movement()


func _apply_mouse_rotation_from_position(mouse_position: Vector2, button_pressed: bool) -> void:
	_camera_controller.apply_mouse_rotation_from_position(mouse_position, button_pressed)
	if button_pressed:
		_configure_screen_relative_movement()


func is_camera_drag_active() -> bool:
	return _camera_controller.drag_rotating_view


func rotate_view_degrees(delta_degrees: float) -> void:
	_camera_controller.rotate_view_degrees(delta_degrees)
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
		_last_facing = _camera_controller.logic_direction_toward_camera()
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
	_sync_actor_health_ring(_player_rig, _player)
	_update_occlusion_ghost()


## The session GameState owns what Kalev wears; the variant's authored
## equipment is only a default for showcase scenes. Mirror the state now and
## on every equipment change.
func _exit_tree() -> void:
	if SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.disconnect(_on_state_replaced)
	_disconnect_equipment_state()
	# Actor rigs and the map view share ShaderMaterials; strip before free so the
	# headless dummy renderer does not emit material_get_instance_shader_parameters.
	MapView3D._strip_geometry_materials(self)


func _on_state_replaced(_previous: GameState, current: GameState, _reason: StringName) -> void:
	_bind_equipment_state(current)


func _bind_equipment_state(current: GameState = null) -> void:
	_disconnect_equipment_state()
	_equipment_state = current if current != null else SessionState.state
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
	var state := _equipment_state
	if state == null:
		return
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
	_camera_controller.update_occlusion_ghost()


func _configure_screen_relative_movement() -> void:
	if not _player.has_method("set_screen_movement_basis"):
		return
	var viewport_size := _camera.get_viewport().get_visible_rect().size
	var center := viewport_size * 0.5
	var center_logic := logic_position_at_screen(center)
	var logic_right := logic_position_at_screen(center + Vector2(INPUT_PROJECTION_SAMPLE_PX, 0.0)) - center_logic
	var logic_down := logic_position_at_screen(center + Vector2(0.0, INPUT_PROJECTION_SAMPLE_PX)) - center_logic
	_player.call("set_screen_movement_basis", logic_right, logic_down)


func _follow_player(snap: bool, delta: float) -> void:
	_camera_controller.follow_player(snap, delta)


static func _hide_player_canvas(player: CharacterBody2D) -> void:
	# The rig replaces the greybox rectangle; the 3D overhead health bar mirrors logic health.
	for node_name in ["GreyboxVisual", "HealthRing", "StaminaBar"]:
		var node := player.get_node_or_null(node_name) as CanvasItem
		if node != null:
			node.visible = false


func _bind_player_health_ring() -> void:
	if _player == null or not _player.has_signal("health_changed"):
		return
	if not _player.health_changed.is_connected(_on_player_health_changed):
		_player.health_changed.connect(_on_player_health_changed)


func _on_player_health_changed(current: float, maximum: float) -> void:
	var ring := _player_rig.get_node_or_null("HealthRing") as CharacterHealthRing3D
	if ring != null:
		ring.set_health(current, maximum)


static func _sync_actor_health_ring(rig: SharedCharacterRig, actor: Node) -> void:
	var ring := rig.get_node_or_null("HealthRing") as CharacterHealthRing3D
	if ring == null:
		return
	if not ("health" in actor) or not ("max_health" in actor):
		return
	ring.set_health(float(actor.health), float(actor.max_health))


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
