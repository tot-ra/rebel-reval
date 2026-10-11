class_name MapViewRuntimeSession
extends RefCounted

## SessionState and GameState equipment binding for MapViewRuntime. Keeps the
## player rig, calendar date, and phase hooks aligned with canonical state
## replacement without duplicating SessionState ownership.

var equipment_state: GameState

var _host: MapViewRuntime
var _actors: MapViewRuntimeActors
var _environment: MapViewRuntimeEnvironment
var _session_state: Node
var _session_content_db: ContentDB


func configure(
	runtime_host: MapViewRuntime,
	actors: MapViewRuntimeActors,
	environment: MapViewRuntimeEnvironment
) -> void:
	_host = runtime_host
	_actors = actors
	_environment = environment


func bind_session_state() -> void:
	_session_state = _host.get_node_or_null("/root/SessionState")
	if _session_state == null:
		return
	_session_content_db = _session_state.get("content_db") as ContentDB
	bind_equipment_state(_session_state.get("state") as GameState)
	if not _session_state.is_connected(&"state_replaced", _on_state_replaced):
		_session_state.connect(&"state_replaced", _on_state_replaced)


func bind_equipment_state(current: GameState = null) -> void:
	disconnect_equipment_state()
	equipment_state = current
	_host.view.set_calendar_date(current_calendar_date())
	_actors.bind_equipment_state(equipment_state, _session_content_db)
	if equipment_state == null:
		return
	if not equipment_state.phase_changed.is_connected(_on_phase_changed):
		equipment_state.phase_changed.connect(_on_phase_changed)


func disconnect_equipment_state() -> void:
	if equipment_state == null:
		return
	_actors.disconnect_equipment_state()
	if equipment_state.phase_changed.is_connected(_on_phase_changed):
		equipment_state.phase_changed.disconnect(_on_phase_changed)
	equipment_state = null


func disconnect_session() -> void:
	if (
		_session_state != null
		and _session_state.is_connected(&"state_replaced", _on_state_replaced)
	):
		_session_state.disconnect(&"state_replaced", _on_state_replaced)
	disconnect_equipment_state()
	_session_state = null
	_session_content_db = null


func current_calendar_date() -> Dictionary:
	return _environment.current_calendar_date(equipment_state)


func _on_state_replaced(_previous: GameState, current: GameState, _reason: StringName) -> void:
	bind_equipment_state(current)


func _on_phase_changed(_previous: StringName, next: StringName) -> void:
	_environment.on_phase_changed(next)
