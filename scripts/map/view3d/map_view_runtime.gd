class_name MapViewRuntime
extends Node3D

## Emitted whenever the time controls change, so a HUD can show the current
## speed or a paused indicator. Carries the effective multiplier (0 while paused)
## and the paused flag.
signal time_flow_changed(speed: float, paused: bool)

## D-001 gameplay presentation: upgrades a bootstrapped 2D map scene to the
## ADR 0007 3D orthographic view. The 2D logic plane keeps running collision,
## navigation, doors, and spawns; this node only hides the flat 2D drawing,
## mounts MapView3D, mirrors logic actors onto shared character rigs, and
## follows the player with a gameplay-scale camera. Positions flow one way,
## logic to view, through MapViewBridge.

const RuntimeBootstrap := preload("res://scripts/map/view3d/map_view_runtime_bootstrap.gd")
## Re-exported so tests and tooling keep a stable MapViewRuntime install contract.
const PLAYER_LIGHT_LAYER := RuntimeBootstrap.PLAYER_LIGHT_LAYER
const RuntimeCamera := preload("res://scripts/map/view3d/map_view_runtime_camera.gd")
const RuntimeInput := preload("res://scripts/map/view3d/map_view_runtime_input.gd")
const RuntimeActors := preload("res://scripts/map/view3d/map_view_runtime_actors.gd")
const RuntimeAmbient := preload("res://scripts/map/view3d/map_view_runtime_ambient.gd")
const RuntimeTimeFlow := preload("res://scripts/map/view3d/map_view_runtime_time_flow.gd")
const RuntimeEnvironment := preload("res://scripts/map/view3d/map_view_runtime_environment.gd")
const RuntimeFlatMap := preload("res://scripts/map/view3d/map_view_runtime_flat_map.gd")
const RuntimeSession := preload("res://scripts/map/view3d/map_view_runtime_session.gd")
const RuntimeHosted := preload("res://scripts/map/view3d/map_view_runtime_hosted.gd")
const RuntimeCameraBinding := preload(
	"res://scripts/map/view3d/map_view_runtime_camera_binding.gd"
)
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
const THIRD_PERSON_DISTANCE := RuntimeCamera.THIRD_PERSON_DISTANCE
const THIRD_PERSON_MIN_DISTANCE := RuntimeCamera.THIRD_PERSON_MIN_DISTANCE
const THIRD_PERSON_MAX_DISTANCE := RuntimeCamera.THIRD_PERSON_MAX_DISTANCE
const THIRD_PERSON_TARGET_HEIGHT := RuntimeCamera.THIRD_PERSON_TARGET_HEIGHT
const THIRD_PERSON_PITCH_DEGREES := RuntimeCamera.THIRD_PERSON_PITCH_DEGREES
const THIRD_PERSON_MIN_PITCH_DEGREES := RuntimeCamera.THIRD_PERSON_MIN_PITCH_DEGREES
const THIRD_PERSON_MAX_PITCH_DEGREES := RuntimeCamera.THIRD_PERSON_MAX_PITCH_DEGREES
const THIRD_PERSON_FOV_DEGREES := RuntimeCamera.THIRD_PERSON_FOV_DEGREES
const THIRD_PERSON_NEAR := RuntimeCamera.THIRD_PERSON_NEAR
const FIRST_PERSON_EYE_HEIGHT := RuntimeCamera.FIRST_PERSON_EYE_HEIGHT
const FIRST_PERSON_PITCH_DEGREES := RuntimeCamera.FIRST_PERSON_PITCH_DEGREES
const FIRST_PERSON_MIN_PITCH_DEGREES := RuntimeCamera.FIRST_PERSON_MIN_PITCH_DEGREES
const FIRST_PERSON_MAX_PITCH_DEGREES := RuntimeCamera.FIRST_PERSON_MAX_PITCH_DEGREES
const FIRST_PERSON_FOV_DEGREES := RuntimeCamera.FIRST_PERSON_FOV_DEGREES
const FIRST_PERSON_NEAR := RuntimeCamera.FIRST_PERSON_NEAR
const OCCLUSION_PROBE_HEIGHTS := RuntimeCamera.OCCLUSION_PROBE_HEIGHTS
## Re-exported time-flow constants so tests and UI keep a stable MapViewRuntime API.
const TIME_SPEED_LADDER: Array[float] = RuntimeTimeFlow.TIME_SPEED_LADDER
const TIME_SPEED_DEFAULT := RuntimeTimeFlow.TIME_SPEED_DEFAULT

var view: MapView3D
## WB-06b: set only by install_hosted(). When set, the view, player, rig and
## camera belong to this host and the host clock drives the day/night cycle.
## Untyped for the same early-compile reason as MapViewRuntimeEnvironment.
var world_host = null

var time_speed: float:
	get:
		return _time_flow.time_speed
	set(value):
		_time_flow.set_time_speed(value)


var time_paused: bool:
	get:
		return _time_flow.time_paused
	set(value):
		_time_flow.set_time_paused(value)

## The world clock follows the system clock; time-flow controls scale it for dev review.
var cycle_enabled: bool:
	get:
		return _environment.cycle_enabled
	set(value):
		_environment.cycle_enabled = value

var cycle_progress: float:
	get:
		return _environment.cycle_progress
	set(value):
		_environment.cycle_progress = value

var cycle_elapsed_days: int:
	get:
		return _environment.cycle_elapsed_days
	set(value):
		_environment.cycle_elapsed_days = value

var _definition: MapDefinition
var _owning_location_id: StringName = &""
var _minimap_logic_tracker: Node2D
var _player: CharacterBody2D
var _player_rig: SharedCharacterRig
var _camera: Camera3D
var _camera_controller: MapViewRuntimeCamera = RuntimeCamera.new()
var _actor_controller = RuntimeActors.new()
var _ambient_controller = RuntimeAmbient.new()
var _time_flow = RuntimeTimeFlow.new()
var _environment = RuntimeEnvironment.new()
var _session = RuntimeSession.new()
var _hosted = RuntimeHosted.new()
var _camera_binding = RuntimeCameraBinding.new()
var _input = RuntimeInput.new()
## Compatibility alias for integration tests that inspect the current binding.
var _equipment_state: GameState:
	get:
		return _session.equipment_state



func _init() -> void:
	_time_flow.configure(self, Callable(self, "_emit_time_flow_changed"))
	_environment.configure(self)
	_session.configure(self, _actor_controller, _environment)
	_hosted.configure(self)
	_camera_binding.configure(self)


static func install(
	scene_root: Node2D, bootstrap: Dictionary, map_root: CanvasItem, player: CharacterBody2D
) -> MapViewRuntime:
	return RuntimeBootstrap.install(scene_root, bootstrap, map_root, player)


## WB-06b: bind a runtime to a WorldHost-mounted location instead of creating
## a view, rig and camera. Only the additive-residency launch path calls this.
static func install_hosted(
	scene_root: Node2D, host: Node, location_id: StringName
) -> MapViewRuntime:
	return RuntimeBootstrap.install_hosted(scene_root, host, location_id)


func is_hosted() -> bool:
	return world_host != null


func owning_location_id() -> StringName:
	return _owning_location_id


## WB-08d: retarget terrain, view, ambient, camera and minimap to the location
## that now owns the player. The Player, camera and HUD instances stay put.
func bind_owning_location(location_id: StringName) -> bool:
	return _hosted.bind_owning_location(location_id)


func configure_click_input(world_items: Node = null) -> void:
	_input.configure_click_input(world_items)


func set_bird_audio_enabled(enabled: bool) -> void:
	_ambient_controller.set_bird_audio_enabled(enabled)


func bird_audio_active_voice_count() -> int:
	return _ambient_controller.bird_audio_active_voice_count()


func set_bird_flight_enabled(enabled: bool) -> void:
	_ambient_controller.set_bird_flight_enabled(enabled)


func bird_flight_active_count() -> int:
	return _ambient_controller.bird_flight_active_count()


func set_urban_fauna_enabled(enabled: bool) -> void:
	_ambient_controller.set_urban_fauna_enabled(enabled)


func urban_fauna_active_count() -> int:
	return _ambient_controller.urban_fauna_active_count()


func set_penned_fauna_enabled(enabled: bool) -> void:
	_ambient_controller.set_penned_fauna_enabled(enabled)


func penned_fauna_active_count() -> int:
	return _ambient_controller.penned_fauna_active_count()


func set_insect_audio_enabled(enabled: bool) -> void:
	_ambient_controller.set_insect_audio_enabled(enabled)


func insect_audio_active_voice_count() -> int:
	return _ambient_controller.insect_audio_active_voice_count()


func configure_crowd(max_instances: int, seed_value: int) -> void:
	_ambient_controller.configure_crowd(max_instances, seed_value)


func get_crowd_renderer() -> MapViewCrowdRenderer:
	return _ambient_controller.get_crowd_renderer()


func set_crowd_enabled(enabled: bool) -> void:
	_ambient_controller.set_crowd_enabled(enabled)


func crowd_active_count() -> int:
	return _ambient_controller.crowd_active_count()



## Projects a screen point through the gameplay camera onto the logic plane,
## so click-to-move keeps working against what the player actually sees.
func logic_position_at_screen(screen_position: Vector2) -> Vector2:
	return _camera_binding.logic_position_at_screen(screen_position)


func set_time_of_day(next_time: StringName) -> void:
	_environment.set_time_of_day(next_time)


## The multiplier actually applied this frame: 0 while paused, otherwise the
## chosen speed.
func effective_time_speed() -> float:
	return _time_flow.effective_time_speed()


## Freezes or resumes the flow of time without discarding the chosen speed.
func toggle_time_pause() -> void:
	_time_flow.toggle_time_pause()


func set_time_paused(paused: bool) -> void:
	_time_flow.set_time_paused(paused)


## Steps one rung up the speed ladder (faster). Snaps an off-ladder speed to the
## next rung above it. Resumes if paused, so tapping faster always does something.
func time_speed_up() -> void:
	_time_flow.time_speed_up()


## Steps one rung down the speed ladder (slower).
func time_speed_down() -> void:
	_time_flow.time_speed_down()


func set_time_speed(speed: float) -> void:
	_time_flow.set_time_speed(speed)


## Returns to real-time pacing and unpauses.
func reset_time_flow() -> void:
	_time_flow.reset_time_flow()


func _emit_time_flow_changed(speed: float, paused: bool) -> void:
	time_flow_changed.emit(speed, paused)


func _bind_environment_runtime() -> void:
	_environment.bind_environment_runtime()


func environment_snapshot() -> Dictionary:
	return _environment.snapshot()


func restore_environment_snapshot(snapshot: Dictionary) -> bool:
	return _environment.restore_snapshot(snapshot)


func apply_environment_presentation() -> void:
	_environment.apply_presentation()


func deactivate_environment_binding() -> void:
	_environment.deactivate_binding()


func environment_weather() -> Node:
	return _environment.weather_node()


func _current_calendar_date() -> Dictionary:
	return _session.current_calendar_date()


func _process(delta: float) -> void:
	# The time controls scale (or pause) the world clock and, through the view,
	# the sky's own cloud/weather/lightning stepping so they stay in lockstep.
	var scaled_delta := _time_flow.scaled_delta(delta)
	_time_flow.apply_weather_time_scale()
	_environment.advance_cycle(scaled_delta, Callable(_session, "current_calendar_date"))
	if _player == null or not is_instance_valid(_player):
		return
	_ambient_controller.sync(delta, cycle_progress)
	_camera_binding.apply_view_rotation(delta)
	_sync_player(false, delta)
	_actor_controller.sync_view_actors(delta)
	_hosted.sync_minimap_tracker()


func get_actor_rig(actor: Node2D) -> SharedCharacterRig:
	return _actor_controller.get_actor_rig(actor)


## Late registration hook for NPCs spawned by controllers that run after
## install(); the boot-time scan only sees actors already in the scene.
func register_view_actor(actor: Node2D) -> void:
	_actor_controller.register_view_actor(actor)


func _unhandled_input(event: InputEvent) -> void:
	_input.handle_unhandled_input(event)


func toggle_camera_view() -> void:
	_camera_binding.toggle_camera_view()


func set_camera_mode(next_mode: MapViewRuntimeCamera.CameraMode) -> void:
	_camera_binding.set_camera_mode(next_mode)


func camera_mode() -> MapViewRuntimeCamera.CameraMode:
	return _camera_binding.camera_mode()


func camera_mode_label() -> String:
	return _camera_binding.camera_mode_label()


func set_first_person(enabled: bool) -> void:
	_camera_binding.set_first_person(enabled)


func is_first_person() -> bool:
	return _camera_binding.is_first_person()


func is_third_person() -> bool:
	return _camera_binding.is_third_person()


func is_top_down() -> bool:
	return _camera_binding.is_top_down()


func zoom_view_steps(steps: float) -> void:
	_camera_binding.zoom_view_steps(steps)


func zoom_from_magnify_factor(factor: float) -> void:
	_camera_binding.zoom_from_magnify_factor(factor)


func zoom_from_pan_delta(delta: Vector2) -> void:
	_camera_binding.zoom_from_pan_delta(delta)


func third_person_follow_distance() -> float:
	return _camera_binding.third_person_follow_distance()


func _apply_view_rotation(delta: float) -> void:
	_camera_binding.apply_view_rotation(delta)


func _apply_mouse_rotation_from_position(mouse_position: Vector2, button_pressed: bool) -> void:
	_camera_binding.apply_mouse_rotation_from_position(mouse_position, button_pressed)


func is_camera_drag_active() -> bool:
	return _camera_binding.is_camera_drag_active()


func rotate_view_degrees(delta_degrees: float) -> void:
	_camera_binding.rotate_view_degrees(delta_degrees)


func _restore_cycle_from_music_director() -> void:
	_environment.restore_from_music_director()


func _sync_music_cycle() -> void:
	_environment.sync_music_cycle()


func _sync_player(snap: bool, delta: float = 0.0) -> void:
	_actor_controller.sync_player(snap, delta)
	_camera_binding.update_occlusion_ghost()


## The session GameState owns what Kalev wears; the variant's authored
## equipment is only a default for showcase scenes. Mirror the state now and
## on every equipment change.
func _exit_tree() -> void:
	var session_state := get_node_or_null("/root/SessionState")
	if session_state != null and session_state.has_method(&"unbind_environment_runtime"):
		session_state.call("unbind_environment_runtime", self)
	_environment.deactivate_binding()
	_session.disconnect_session()
	# Actor rigs and the map view share ShaderMaterials; strip before free so the
	# headless dummy renderer does not emit material_get_instance_shader_parameters.
	MapView3D._strip_geometry_materials(self)


func _update_occlusion_ghost() -> void:
	_camera_binding.update_occlusion_ghost()


func _configure_screen_relative_movement() -> void:
	_camera_binding.configure_screen_relative_movement()


## Compatibility delegate for tests and callers that still target the old helper.
static func _hide_flat_map_visuals(bootstrap: Dictionary) -> void:
	RuntimeFlatMap.hide_visuals(bootstrap)
