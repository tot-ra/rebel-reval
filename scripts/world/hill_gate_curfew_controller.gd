class_name HillGateCurfewController
extends RefCounted

## Runtime state for the two Toompea hill gates.
## WHY: the watch changes gate state at the jurisdiction boundary, while the
## inactive prototype remains available to developer tools and save fixtures.

const JurisdictionModelScript := preload("res://scripts/world/jurisdiction_model.gd")

const MapTypesScript := preload("res://scripts/map/map_types.gd")

const GATE_STATE_OPEN := MapTypesScript.HILL_GATE_STATE_OPEN
const GATE_STATE_CLOSED := MapTypesScript.HILL_GATE_STATE_CLOSED
const GATE_STATES: Array[StringName] = MapTypesScript.HILL_GATE_STATES
const GATE_PIKK_JALG := &"pikk_jalg"
const GATE_LUHIKE_JALG := &"luhike_jalg"
const GATE_IDS: Array[StringName] = [GATE_PIKK_JALG, GATE_LUHIKE_JALG]
const LOCATION_STATE_PREFIX := "hill_gate."

var _state: GameState


func setup(state: GameState) -> void:
	_state = state


func sync_for_phase(phase_id: StringName, from_lower_town: bool = true) -> bool:
	if _state == null:
		return false
	if not from_lower_town:
		return false
	var next_state := GATE_STATE_CLOSED if is_night_phase(phase_id) else GATE_STATE_OPEN
	var changed := false
	for gate_id in GATE_IDS:
		changed = set_gate_state(gate_id, next_state) or changed
	return changed


func set_gate_state(gate_id: StringName, gate_state: StringName) -> bool:
	if _state == null or not is_known_gate(gate_id) or not GATE_STATES.has(gate_state):
		return false
	if get_gate_state(gate_id) == gate_state:
		return false
	_state.set_location_state(_location_state_key(gate_id), gate_state)
	return true


func get_gate_state(gate_id: StringName) -> StringName:
	if _state == null or not is_known_gate(gate_id):
		return &""
	var saved := _state.get_location_state(_location_state_key(gate_id))
	if GATE_STATES.has(saved):
		return saved
	return GATE_STATE_OPEN


func gate_states() -> Dictionary:
	var result: Dictionary = {}
	for gate_id in GATE_IDS:
		result[gate_id] = get_gate_state(gate_id)
	return result


func developer_snapshot() -> Dictionary:
	return {
		"map_id": JurisdictionModelScript.TOOMPEA_MAP_ID,
		"map_active": false,
		"jurisdiction": JurisdictionModelScript.JURISDICTION_TOOMPEA_DANISH,
		"gate_states": gate_states(),
		"transitions": JurisdictionModelScript.transition_contracts(),
	}


static func is_known_gate(gate_id: StringName) -> bool:
	return gate_id in GATE_IDS


static func is_night_phase(phase_id: StringName) -> bool:
	return phase_id in [GameState.PHASE_INVESTIGATION_NIGHT, GameState.PHASE_CONSEQUENCE_NIGHT]


func _location_state_key(gate_id: StringName) -> StringName:
	return StringName(LOCATION_STATE_PREFIX + String(gate_id))
