class_name MapViewRuntimeAmbient
extends RefCounted

## Bird/flight/fauna/insect audio, music zones, and crowd rendering for MapViewRuntime.
## MapViewRuntime remains the scene-facing facade while this helper owns ambient
## installers, enable flags, and per-frame sync.

const BirdAmbientAudio := preload("res://scripts/map/view3d/map_view_bird_ambient_audio.gd")
const BirdContext := preload("res://scripts/map/view3d/map_view_bird_context.gd")
const BirdFlight := preload("res://scripts/map/view3d/map_view_bird_flight.gd")
const FaunaContext := preload("res://scripts/map/view3d/map_view_fauna_context.gd")
const UrbanFauna := preload("res://scripts/map/view3d/map_view_urban_fauna.gd")
const PennedFauna := preload("res://scripts/map/view3d/map_view_penned_fauna.gd")
const InsectAmbientAudio := preload("res://scripts/map/view3d/map_view_insect_ambient_audio.gd")
const InsectContext := preload("res://scripts/map/view3d/map_view_insect_context.gd")
const MapMusicZoneBinder := preload("res://scripts/map/map_music_zone_binder.gd")
const CrowdRenderer := preload("res://scripts/map/view3d/map_view_crowd_renderer.gd")

var _host: Node3D
var _definition: MapDefinition
var _player: CharacterBody2D
var _camera: Camera3D
var _view: MapView3D
var _bird_audio
var _bird_audio_enabled := true
var _bird_flight
var _bird_flight_enabled := true
var _urban_fauna
var _urban_fauna_enabled := true
var _penned_fauna
var _penned_fauna_enabled := true
var _insect_audio
var _insect_audio_enabled := true
var _music_zone_binder
var _crowd_renderer: MapViewCrowdRenderer
var _crowd_enabled := true


func configure(
	runtime_host: Node3D,
	map_definition: MapDefinition,
	logic_player: CharacterBody2D,
	gameplay_camera: Camera3D,
	map_view: MapView3D
) -> void:
	_host = runtime_host
	_definition = map_definition
	_player = logic_player
	_camera = gameplay_camera
	_view = map_view


func install() -> void:
	_install_bird_audio()
	_install_bird_flight()
	_install_urban_fauna()
	_install_penned_fauna()
	_install_insect_audio()
	_install_music_zone_binder()
	_install_crowd_renderer()


func sync(delta: float, cycle_progress: float) -> void:
	_sync_bird_audio(delta, cycle_progress)
	_sync_bird_flight(delta, cycle_progress)
	_sync_urban_fauna(delta)
	_sync_penned_fauna(delta)
	_sync_insect_audio(delta, cycle_progress)


func set_bird_audio_enabled(enabled: bool) -> void:
	_bird_audio_enabled = enabled
	if _bird_audio != null:
		_bird_audio.set_audio_enabled(enabled)


func bird_audio_active_voice_count() -> int:
	if _bird_audio == null:
		return 0
	return _bird_audio.active_voice_count()


func set_bird_flight_enabled(enabled: bool) -> void:
	_bird_flight_enabled = enabled
	if _bird_flight != null:
		_bird_flight.set_flight_enabled(enabled)


func bird_flight_active_count() -> int:
	if _bird_flight == null:
		return 0
	return _bird_flight.active_bird_count()


func set_urban_fauna_enabled(enabled: bool) -> void:
	_urban_fauna_enabled = enabled
	if _urban_fauna != null:
		_urban_fauna.set_fauna_enabled(enabled)


func urban_fauna_active_count() -> int:
	if _urban_fauna == null:
		return 0
	return _urban_fauna.active_fauna_count()


func set_penned_fauna_enabled(enabled: bool) -> void:
	_penned_fauna_enabled = enabled
	if _penned_fauna != null:
		_penned_fauna.set_fauna_enabled(enabled)


func penned_fauna_active_count() -> int:
	if _penned_fauna == null:
		return 0
	return _penned_fauna.active_fauna_count()


func set_insect_audio_enabled(enabled: bool) -> void:
	_insect_audio_enabled = enabled
	if _insect_audio != null:
		_insect_audio.set_audio_enabled(enabled)


func insect_audio_active_voice_count() -> int:
	if _insect_audio == null:
		return 0
	return _insect_audio.active_voice_count()


func configure_crowd(max_instances: int, seed_value: int) -> void:
	if _crowd_renderer != null:
		_crowd_renderer.clear_actors()
		_host.remove_child(_crowd_renderer)
		_crowd_renderer.queue_free()
		_crowd_renderer = null
	_crowd_renderer = CrowdRenderer.new()
	_crowd_renderer.name = "CrowdRenderer"
	_host.add_child(_crowd_renderer)
	_crowd_renderer.configure(max_instances, seed_value)
	_crowd_renderer.set_crowd_enabled(_crowd_enabled)


func get_crowd_renderer() -> MapViewCrowdRenderer:
	return _crowd_renderer


func set_crowd_enabled(enabled: bool) -> void:
	_crowd_enabled = enabled
	if _crowd_renderer != null:
		_crowd_renderer.set_crowd_enabled(enabled)


func crowd_active_count() -> int:
	if _crowd_renderer == null:
		return 0
	return _crowd_renderer.active_count()


func _install_bird_flight() -> void:
	_bird_flight = BirdFlight.new()
	_bird_flight.name = "BirdFlight"
	_host.add_child(_bird_flight)
	var context := BirdContext.context_for_map(_definition.map_id)
	_bird_flight.configure(_definition.map_id, context, _definition.size_cells)


func _install_urban_fauna() -> void:
	_urban_fauna = UrbanFauna.new()
	_urban_fauna.name = "UrbanFauna"
	_host.add_child(_urban_fauna)
	var context := FaunaContext.context_for_map(_definition.map_id)
	_urban_fauna.configure(_definition.map_id, context, _definition.cell_size, _definition)


func _install_penned_fauna() -> void:
	_penned_fauna = PennedFauna.new()
	_penned_fauna.name = "PennedFauna"
	_host.add_child(_penned_fauna)
	var context := FaunaContext.context_for_map(_definition.map_id)
	_penned_fauna.configure(_definition.map_id, context, _definition.cell_size, _definition)


func _install_bird_audio() -> void:
	_bird_audio = BirdAmbientAudio.new()
	_bird_audio.name = "BirdAmbientAudio"
	_host.add_child(_bird_audio)
	var context := BirdContext.context_for_map(_definition.map_id)
	_bird_audio.configure(_definition.map_id, context)


func _install_insect_audio() -> void:
	_insect_audio = InsectAmbientAudio.new()
	_insect_audio.name = "InsectAmbientAudio"
	_host.add_child(_insect_audio)
	var context := InsectContext.context_for_map(_definition.map_id)
	_insect_audio.configure(_definition.map_id, context)


func _install_music_zone_binder() -> void:
	_music_zone_binder = MapMusicZoneBinder.new()
	_music_zone_binder.name = "MapMusicZoneBinder"
	_host.add_child(_music_zone_binder)
	_music_zone_binder.configure(_definition, _player)


func _install_crowd_renderer() -> void:
	_crowd_renderer = CrowdRenderer.new()
	_crowd_renderer.name = "CrowdRenderer"
	_host.add_child(_crowd_renderer)
	# Capacity defaults to 200; maps with battle scenes can override via
	# configure_crowd() after install.
	# Positional args only: GDScript 4.7 rejects `name = value` in call sites
	# as assignment-in-expression (P0-172 / P4-043-F01).
	_crowd_renderer.configure(200, hash(_definition.map_id))


func _sync_bird_audio(delta: float, cycle_progress: float) -> void:
	if _bird_audio == null or _definition == null or _view == null:
		return
	if _definition.suppresses_exterior_surroundings():
		_bird_audio.sync(&"", cycle_progress, Vector3.ZERO, delta, false)
		return
	var context := BirdContext.context_for_map(_definition.map_id)
	var listener := _camera.global_position if _camera != null else Vector3.ZERO
	_bird_audio.sync(context, cycle_progress, listener, delta, _bird_audio_enabled)


func _sync_bird_flight(delta: float, cycle_progress: float) -> void:
	if _bird_flight == null or _definition == null:
		return
	if _definition.suppresses_exterior_surroundings():
		_bird_flight.sync(&"", cycle_progress, delta, false)
		return
	var context := BirdContext.context_for_map(_definition.map_id)
	_bird_flight.sync(context, cycle_progress, delta, _bird_flight_enabled)


func _sync_urban_fauna(delta: float) -> void:
	if _urban_fauna == null or _definition == null:
		return
	if _definition.suppresses_exterior_surroundings():
		_urban_fauna.sync(&"", delta, Vector3.ZERO, false)
		return
	var context := FaunaContext.context_for_map(_definition.map_id)
	var listener := _camera.global_position if _camera != null else Vector3.ZERO
	_urban_fauna.sync(context, delta, listener, _urban_fauna_enabled)


func _sync_penned_fauna(delta: float) -> void:
	if _penned_fauna == null or _definition == null:
		return
	if _definition.suppresses_exterior_surroundings():
		_penned_fauna.sync(&"", delta, Vector3.ZERO, false)
		return
	var context := FaunaContext.context_for_map(_definition.map_id)
	var listener := _camera.global_position if _camera != null else Vector3.ZERO
	_penned_fauna.sync(context, delta, listener, _penned_fauna_enabled)


func _sync_insect_audio(delta: float, cycle_progress: float) -> void:
	if _insect_audio == null or _definition == null or _view == null:
		return
	if _definition.suppresses_exterior_surroundings():
		_insect_audio.sync(&"", cycle_progress, Vector3.ZERO, delta, false)
		return
	var context := InsectContext.context_for_map(_definition.map_id)
	var listener := _camera.global_position if _camera != null else Vector3.ZERO
	_insect_audio.sync(context, cycle_progress, listener, delta, _insect_audio_enabled)
