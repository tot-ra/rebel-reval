class_name MapViewRuntime
extends Node3D

## D-001 gameplay presentation: upgrades a bootstrapped 2D map scene to the
## ADR 0007 3D orthographic view. The 2D logic plane keeps running collision,
## navigation, doors, and spawns; this node only hides the flat 2D drawing,
## mounts MapView3D, mirrors logic actors onto shared character rigs, and
## follows the player with a gameplay-scale camera. Positions flow one way,
## logic to view, through MapViewBridge.

const PLAYER_RIG_SCENE := preload("res://assets/characters/kalev/kalev.tscn")
const CLICK_INPUT_SCRIPT_PATH := "res://scripts/map/map_click_input_controller.gd"
const DayNightCycle := preload("res://scripts/global/day_night_cycle.gd")
const GameCalendarScript := preload("res://scripts/global/game_calendar.gd")
const RuntimeCamera := preload("res://scripts/map/view3d/map_view_runtime_camera.gd")
const RuntimeActors := preload("res://scripts/map/view3d/map_view_runtime_actors.gd")

## Compatibility aliases keep the runtime's public locomotion thresholds stable.
const WALK_ANIMATION_MIN_SPEED := RuntimeActors.WALK_ANIMATION_MIN_SPEED
const RUN_ANIMATION_MIN_SPEED := RuntimeActors.RUN_ANIMATION_MIN_SPEED
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

## Emitted whenever the time controls change, so a HUD can show the current
## speed or a paused indicator. Carries the effective multiplier (0 while paused)
## and the paused flag.
signal time_flow_changed(speed: float, paused: bool)

var view: MapView3D

## Dev pacing: one in-game day every DayNightCycle.CYCLE_DURATION_SECONDS.
var cycle_enabled := true
var cycle_progress := DayNightCycle.DEFAULT_PROGRESS
var cycle_elapsed_days := 0

## Shared time controls for the day/night clock and the sky (sun, clouds, weather,
## lightning). `time_speed` is the chosen multiplier; `time_paused` freezes flow
## without losing the chosen speed. The ladder gives predictable slow-mo and
## fast-forward steps; 1.0 must stay on it as the neutral default.
const TIME_SPEED_LADDER: Array[float] = [0.1, 0.25, 0.5, 1.0, 2.0, 4.0, 8.0, 20.0]
const TIME_SPEED_DEFAULT := 1.0
var time_speed := TIME_SPEED_DEFAULT
var time_paused := false

var _definition: MapDefinition
var _player: CharacterBody2D
var _player_rig: SharedCharacterRig
var _camera: Camera3D
var _camera_controller: MapViewRuntimeCamera = RuntimeCamera.new()
var _actor_controller = RuntimeActors.new()
## Compatibility aliases for integration tests that inspect the current binding.
var _equipment_state: GameState
var _session_state: Node
var _session_content_db: ContentDB
var _click_input: Node


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
	RuntimeActors.hide_player_canvas(player)

	runtime._player_rig = PLAYER_RIG_SCENE.instantiate()
	runtime._player_rig.name = "PlayerRig"
	runtime._player_rig.add_to_group(&"player_view_rig")
	runtime.add_child(runtime._player_rig)

	runtime._camera = runtime.view.view_camera()
	runtime._camera.size = CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE
	runtime._camera_controller.configure(runtime._camera, runtime._player_rig, runtime.view, runtime._player)
	runtime._actor_controller.configure(
		runtime,
		runtime._definition,
		runtime._player,
		runtime._player_rig,
		runtime.view,
		runtime._camera_controller.follow_player,
		runtime._camera_controller.logic_direction_toward_camera
	)

	scene_root.add_child(runtime)
	# Created at runtime, so enable input explicitly before the first frame.
	runtime.set_process_unhandled_input(true)
	runtime._bind_session_state()
	runtime._actor_controller.register_view_actors(scene_root)
	runtime._configure_screen_relative_movement()
	runtime._sync_player(true)
	runtime._actor_controller.bind_player_health_ring()
	# WHY: Each district used to restart at DEFAULT_PROGRESS, so harbor kept a
	# moving sun while Workers' District (and any fresh map) snapped morning.
	# MusicDirector holds both clock fractions and completed solar days so scene
	# transitions cannot rewind the date or lunar phase.
	runtime._restore_cycle_from_music_director()
	runtime.view.set_calendar_date(runtime._current_calendar_date())
	runtime.view.apply_cycle_progress(runtime.cycle_progress)
	runtime._sync_music_cycle()
	runtime._install_click_input(scene_root)
	return runtime


func configure_click_input(world_items: Node = null) -> void:
	if _click_input == null:
		return
	if world_items != null:
		_click_input.call("set_world_items", world_items)


func _install_click_input(_scene_root: Node2D) -> void:
	# Keep gameplay click routing out of the editor-time map dependency graph.
	# MapViewRuntime is loaded by import tooling before gameplay autoloads exist.
	var click_input_script := load(CLICK_INPUT_SCRIPT_PATH) as Script
	if click_input_script == null:
		push_error("MapViewRuntime could not load the click input controller")
		return
	_click_input = click_input_script.new() as Node
	_click_input.name = "MapClickInput"
	add_child(_click_input)
	_click_input.call("setup", _player, self)


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


## The multiplier actually applied this frame: 0 while paused, otherwise the
## chosen speed.
func effective_time_speed() -> float:
	return 0.0 if time_paused else time_speed


## Freezes or resumes the flow of time without discarding the chosen speed.
func toggle_time_pause() -> void:
	set_time_paused(not time_paused)


func set_time_paused(paused: bool) -> void:
	if time_paused == paused:
		return
	time_paused = paused
	_notify_time_flow()


## Steps one rung up the speed ladder (faster). Snaps an off-ladder speed to the
## next rung above it. Resumes if paused, so tapping faster always does something.
func time_speed_up() -> void:
	_step_time_speed(1)


## Steps one rung down the speed ladder (slower).
func time_speed_down() -> void:
	_step_time_speed(-1)


func set_time_speed(speed: float) -> void:
	time_speed = clampf(speed, TIME_SPEED_LADDER[0], TIME_SPEED_LADDER[-1])
	_notify_time_flow()


## Returns to real-time pacing and unpauses.
func reset_time_flow() -> void:
	time_speed = TIME_SPEED_DEFAULT
	time_paused = false
	_notify_time_flow()


func _step_time_speed(direction: int) -> void:
	time_paused = false
	var index := _nearest_ladder_index()
	index = clampi(index + direction, 0, TIME_SPEED_LADDER.size() - 1)
	time_speed = TIME_SPEED_LADDER[index]
	_notify_time_flow()


func _nearest_ladder_index() -> int:
	var best := 0
	var best_gap := absf(TIME_SPEED_LADDER[0] - time_speed)
	for i in range(1, TIME_SPEED_LADDER.size()):
		var gap := absf(TIME_SPEED_LADDER[i] - time_speed)
		if gap < best_gap:
			best_gap = gap
			best = i
	return best


func _notify_time_flow() -> void:
	if view != null:
		view.set_weather_time_scale(effective_time_speed())
	time_flow_changed.emit(effective_time_speed(), time_paused)


func _process(delta: float) -> void:
	# The time controls scale (or pause) the world clock and, through the view,
	# the sky's own cloud/weather/lightning stepping so they stay in lockstep.
	var scaled_delta := delta * effective_time_speed()
	view.set_weather_time_scale(effective_time_speed())
	if cycle_enabled:
		var clock_advance := DayNightCycle.advance_clock(cycle_progress, scaled_delta)
		cycle_progress = float(clock_advance["progress"])
		var completed_days := int(clock_advance["completed_days"])
		if completed_days > 0:
			cycle_elapsed_days += completed_days
			view.set_calendar_date(_current_calendar_date())
		view.apply_cycle_progress(cycle_progress)
		_sync_music_cycle()
	if _player == null or not is_instance_valid(_player):
		return
	_apply_view_rotation(delta)
	_sync_player(false, delta)
	_actor_controller.sync_view_actors(delta)


func get_actor_rig(actor: Node2D) -> SharedCharacterRig:
	return _actor_controller.get_actor_rig(actor)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_camera_view") and not event.is_echo():
		toggle_camera_view()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if _handle_time_control_key((event as InputEventKey).keycode):
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


## Dev/playtest time controls, handled as raw keys so they need no input-map
## entries: comma/period slow down/speed up the world clock and sky, P pauses and
## resumes, backslash restores real-time. Returns true when the key was a control.
func _handle_time_control_key(keycode: Key) -> bool:
	match keycode:
		KEY_COMMA:
			time_speed_down()
		KEY_PERIOD:
			time_speed_up()
		KEY_P:
			toggle_time_pause()
		KEY_BACKSLASH:
			reset_time_flow()
		_:
			return false
	return true


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


func _music_director() -> Node:
	# Unit-level runtime instances can advance their local clock before entering a
	# SceneTree. Resolve the autoload through the tree root only when one exists,
	# instead of issuing an invalid absolute NodePath lookup on a detached node.
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("MusicDirector")


func _restore_cycle_from_music_director() -> void:
	var music_director := _music_director()
	if music_director == null:
		return
	if music_director.has_method(&"is_cycle_active") and not bool(music_director.call(&"is_cycle_active")):
		return
	if not music_director.has_method(&"get_cycle_progress"):
		return
	cycle_progress = float(music_director.call(&"get_cycle_progress"))
	if music_director.has_method(&"get_cycle_elapsed_days"):
		cycle_elapsed_days = int(music_director.call(&"get_cycle_elapsed_days"))


func _sync_music_cycle() -> void:
	var music_director := _music_director()
	if music_director != null:
		music_director.call("set_cycle_progress", cycle_progress)
		if music_director.has_method(&"set_cycle_elapsed_days"):
			music_director.call(&"set_cycle_elapsed_days", cycle_elapsed_days)


func _sync_player(snap: bool, delta: float = 0.0) -> void:
	_actor_controller.sync_player(snap, delta)
	_update_occlusion_ghost()


## The session GameState owns what Kalev wears; the variant's authored
## equipment is only a default for showcase scenes. Mirror the state now and
## on every equipment change.
func _exit_tree() -> void:
	if _session_state != null and _session_state.is_connected(&"state_replaced", _on_state_replaced):
		_session_state.disconnect(&"state_replaced", _on_state_replaced)
	_disconnect_equipment_state()
	# Actor rigs and the map view share ShaderMaterials; strip before free so the
	# headless dummy renderer does not emit material_get_instance_shader_parameters.
	MapView3D._strip_geometry_materials(self)


func _bind_session_state() -> void:
	_session_state = get_node_or_null("/root/SessionState")
	if _session_state == null:
		return
	_session_content_db = _session_state.get("content_db") as ContentDB
	_bind_equipment_state(_session_state.get("state") as GameState)
	if not _session_state.is_connected(&"state_replaced", _on_state_replaced):
		_session_state.connect(&"state_replaced", _on_state_replaced)


func _on_state_replaced(_previous: GameState, current: GameState, _reason: StringName) -> void:
	_bind_equipment_state(current)


func _on_phase_changed(_previous: StringName, next: StringName) -> void:
	cycle_elapsed_days = 0
	view.set_calendar_date(GameCalendarScript.date_for_phase(next))
	var music_director := _music_director()
	if music_director != null and music_director.has_method(&"set_cycle_elapsed_days"):
		music_director.call(&"set_cycle_elapsed_days", cycle_elapsed_days)


func _current_calendar_date() -> Dictionary:
	var base_date := GameCalendarScript.DEFAULT_DATE
	if _equipment_state != null:
		base_date = GameCalendarScript.date_for_phase(_equipment_state.get_phase())
	return GameCalendarScript.add_days(base_date, cycle_elapsed_days)


func _bind_equipment_state(current: GameState = null) -> void:
	_disconnect_equipment_state()
	_equipment_state = current
	view.set_calendar_date(_current_calendar_date())
	_actor_controller.bind_equipment_state(_equipment_state, _session_content_db)
	if _equipment_state == null:
		return
	if not _equipment_state.phase_changed.is_connected(_on_phase_changed):
		_equipment_state.phase_changed.connect(_on_phase_changed)


func _disconnect_equipment_state() -> void:
	if _equipment_state == null:
		return
	_actor_controller.disconnect_equipment_state()
	if _equipment_state.phase_changed.is_connected(_on_phase_changed):
		_equipment_state.phase_changed.disconnect(_on_phase_changed)
	_equipment_state = null


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
