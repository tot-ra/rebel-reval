class_name EnvironmentalConsequenceController
extends Node

## Applies district consequence overlays from ledger and flag state.

const ModelScript := preload("res://scripts/world/environmental_consequence_model.gd")

var location_id: StringName = &""

var _view_runtime: MapViewRuntime
var _district_id: StringName = &""
var _state: GameState
var _applied_state := &""
var _applied_supply := false


func setup(view_runtime: MapViewRuntime, map_location_id: StringName) -> void:
	location_id = map_location_id
	_view_runtime = view_runtime
	_district_id = ModelScript.district_for_location(location_id)
	_connect_state(SessionState.state)
	if not SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.connect(_on_state_replaced)


func _exit_tree() -> void:
	if SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.disconnect(_on_state_replaced)
	_disconnect_state(_state)


func sync_for_test(state: GameState) -> void:
	_connect_state(state)


func get_applied_snapshot() -> Dictionary:
	if _state == null:
		return {}
	return ModelScript.resolve_snapshot(_district_id, _state)


func _on_state_replaced(_previous: GameState, current: GameState, _reason: StringName) -> void:
	_connect_state(current)


func _connect_state(state: GameState) -> void:
	_disconnect_state(_state)
	_state = state
	if _state == null:
		return
	if not _state.faction_event_recorded.is_connected(_on_faction_event_recorded):
		_state.faction_event_recorded.connect(_on_faction_event_recorded)
	if not _state.phase_changed.is_connected(_on_state_changed):
		_state.phase_changed.connect(_on_state_changed)
	_sync_visuals()


func _disconnect_state(state: GameState) -> void:
	if state == null:
		return
	if state.faction_event_recorded.is_connected(_on_faction_event_recorded):
		state.faction_event_recorded.disconnect(_on_faction_event_recorded)
	if state.phase_changed.is_connected(_on_state_changed):
		state.phase_changed.disconnect(_on_state_changed)


func _process(_delta: float) -> void:
	_sync_visuals()


func _on_state_changed(_a = null, _b = null) -> void:
	_sync_visuals()


func _on_faction_event_recorded(_event_id: StringName, _faction_id: StringName) -> void:
	_sync_visuals()


func _sync_visuals() -> void:
	if _view_runtime == null or _view_runtime.view == null or _district_id.is_empty() or _state == null:
		return
	var snapshot := ModelScript.resolve_snapshot(_district_id, _state)
	var consequence_state: StringName = snapshot.get("consequence_state", ModelScript.STATE_BASELINE)
	var supply_disrupted := bool(snapshot.get("supply_disrupted", false))
	if consequence_state == _applied_state and supply_disrupted == _applied_supply:
		return
	_applied_state = consequence_state
	_applied_supply = supply_disrupted
	for prop_id: StringName in ModelScript.all_managed_prop_ids(_district_id):
		_view_runtime.view.set_prop_visible(
			prop_id,
			ModelScript.prop_visible(snapshot, prop_id)
		)
