class_name PaideFinaleModel
extends RefCounted

## Deterministic Act 2 finale record for the killing of the Four Kings at Paide.
## WHY: the historical outcome is immutable, while the player's role, prior
## knowledge, and warning attempt must survive as distinct Act 3 opening inputs.
## The snapshot uses existing persisted flags and quest state so it remains
## compatible with current saves without widening the GameState schema.

const ENVELOPE_VERSION := 1
const QUEST_ID := &"quest.act2.paide_finale"
const QUEST_STATE_COMPLETE := &"complete"
const PHASE_ACT3_OPENING := &"phase.act3.occupation_opening"
const EVENT_FOUR_KINGS_KILLED := &"event.paide.four_kings_killed"

const ROLE_HALL_WITNESS := &"hall_witness"
const ROLE_WARNING_COURIER := &"warning_courier"
const ROLE_AFTERMATH_INVESTIGATOR := &"aftermath_investigator"
const PLAYER_ROLES: Array[StringName] = [
	ROLE_HALL_WITNESS,
	ROLE_WARNING_COURIER,
	ROLE_AFTERMATH_INVESTIGATOR,
]

const KNOWLEDGE_FOREWARNED := &"forewarned"
const KNOWLEDGE_UNAWARE := &"unaware"
const KNOWLEDGE_STATES: Array[StringName] = [KNOWLEDGE_FOREWARNED, KNOWLEDGE_UNAWARE]

const WARNING_DELIVERED := &"delivered"
const WARNING_INTERCEPTED := &"intercepted"
const WARNING_NOT_ATTEMPTED := &"not_attempted"
const WARNING_STATES: Array[StringName] = [
	WARNING_DELIVERED,
	WARNING_INTERCEPTED,
	WARNING_NOT_ATTEMPTED,
]

const OPENING_WITNESS_UNDER_GUARD := &"witness_under_guard"
const OPENING_WARNING_NETWORK_SCATTERED := &"warning_network_scattered"
const OPENING_BETRAYAL_RECONSTRUCTED := &"betrayal_reconstructed"
const OPENING_STATES: Array[StringName] = [
	OPENING_WITNESS_UNDER_GUARD,
	OPENING_WARNING_NETWORK_SCATTERED,
	OPENING_BETRAYAL_RECONSTRUCTED,
]

const FACT_BETRAYAL_KNOWN := &"fact.paide.betrayal_known_before_talks"
const FLAG_WARNING_ATTEMPTED := &"flag.paide.warning_attempted"
const FLAG_WARNING_DELIVERED := &"flag.paide.warning_delivered"
const FLAG_RECORDED := &"flag.act_transition.act2_recorded"
const FLAG_KINGS_KILLED := &"flag.history.paide.four_kings_killed"

const _ROLE_FLAGS: Dictionary = {
	ROLE_HALL_WITNESS: &"flag.paide.role.hall_witness",
	ROLE_WARNING_COURIER: &"flag.paide.role.warning_courier",
	ROLE_AFTERMATH_INVESTIGATOR: &"flag.paide.role.aftermath_investigator",
}
const _KNOWLEDGE_FLAGS: Dictionary = {
	KNOWLEDGE_FOREWARNED: &"flag.paide.knowledge.forewarned",
	KNOWLEDGE_UNAWARE: &"flag.paide.knowledge.unaware",
}
const _WARNING_FLAGS: Dictionary = {
	WARNING_DELIVERED: &"flag.paide.warning_result.delivered",
	WARNING_INTERCEPTED: &"flag.paide.warning_result.intercepted",
	WARNING_NOT_ATTEMPTED: &"flag.paide.warning_result.not_attempted",
}
const _OPENING_FLAGS: Dictionary = {
	OPENING_WITNESS_UNDER_GUARD: &"flag.act3.opening.witness_under_guard",
	OPENING_WARNING_NETWORK_SCATTERED: &"flag.act3.opening.warning_network_scattered",
	OPENING_BETRAYAL_RECONSTRUCTED: &"flag.act3.opening.betrayal_reconstructed",
}


## Records the finale once. Later input-fact changes cannot rewrite the snapshot.
static func record_transition(state: GameState, player_role: StringName) -> Dictionary:
	if state == null or not PLAYER_ROLES.has(player_role) or state.get_flag(FLAG_RECORDED):
		return {}

	var knowledge := (
		KNOWLEDGE_FOREWARNED if state.get_fact(FACT_BETRAYAL_KNOWN) else KNOWLEDGE_UNAWARE
	)
	var warning := _resolve_warning(state)
	var opening := _opening_for_role(player_role)
	_set_exclusive_flag(state, _ROLE_FLAGS, player_role)
	_set_exclusive_flag(state, _KNOWLEDGE_FLAGS, knowledge)
	_set_exclusive_flag(state, _WARNING_FLAGS, warning)
	_set_exclusive_flag(state, _OPENING_FLAGS, opening)

	# History is fixed even when a warning reaches the envoys; branches steer
	# witnesses, evidence, and Act 3 readiness, never the attested killing.
	state.set_flag(FLAG_KINGS_KILLED, true)
	state.set_flag(FLAG_RECORDED, true)
	state.set_quest_state(QUEST_ID, QUEST_STATE_COMPLETE)
	state.set_phase(PHASE_ACT3_OPENING)

	var record := build_record(state)
	var validation := validate_record(record)
	if not validation["valid"]:
		return {}
	return record


static func build_record(state: GameState) -> Dictionary:
	if state == null or not state.get_flag(FLAG_RECORDED):
		return {}
	return {
		"version": ENVELOPE_VERSION,
		"finale_id": String(QUEST_ID),
		"historical_event": String(EVENT_FOUR_KINGS_KILLED),
		"four_kings_killed": state.get_flag(FLAG_KINGS_KILLED),
		"player_role": String(_selected_key(state, _ROLE_FLAGS)),
		"knowledge_state": String(_selected_key(state, _KNOWLEDGE_FLAGS)),
		"warning_state": String(_selected_key(state, _WARNING_FLAGS)),
		"act3_opening_state": String(_selected_key(state, _OPENING_FLAGS)),
		"opening_phase": String(state.get_phase()),
	}


static func validate_record(record: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	if record.is_empty():
		return {"valid": false, "errors": ["record is empty"]}
	if int(record.get("version", 0)) != ENVELOPE_VERSION:
		errors.append("unsupported record version")
	if String(record.get("finale_id", "")) != String(QUEST_ID):
		errors.append("invalid finale_id")
	if String(record.get("historical_event", "")) != String(EVENT_FOUR_KINGS_KILLED):
		errors.append("invalid historical_event")
	if not bool(record.get("four_kings_killed", false)):
		errors.append("attested Four Kings killing must remain true")

	var role := StringName(String(record.get("player_role", "")))
	var knowledge := StringName(String(record.get("knowledge_state", "")))
	var warning := StringName(String(record.get("warning_state", "")))
	var opening := StringName(String(record.get("act3_opening_state", "")))
	if not PLAYER_ROLES.has(role):
		errors.append("invalid player_role")
	if not KNOWLEDGE_STATES.has(knowledge):
		errors.append("invalid knowledge_state")
	if not WARNING_STATES.has(warning):
		errors.append("invalid warning_state")
	if not OPENING_STATES.has(opening):
		errors.append("invalid act3_opening_state")
	if PLAYER_ROLES.has(role) and opening != _opening_for_role(role):
		errors.append("act3_opening_state does not match player_role")
	if warning == WARNING_DELIVERED and knowledge != KNOWLEDGE_FOREWARNED:
		errors.append("delivered warning requires foreknowledge")
	if warning != WARNING_NOT_ATTEMPTED and knowledge != KNOWLEDGE_FOREWARNED:
		errors.append("warning attempt requires foreknowledge")
	if String(record.get("opening_phase", "")) != String(PHASE_ACT3_OPENING):
		errors.append("invalid opening_phase")
	return {"valid": errors.is_empty(), "errors": errors}


static func validate_state(state: GameState) -> Dictionary:
	var errors: Array[String] = []
	if state == null:
		return {"valid": false, "errors": ["state is null"]}
	if state.get_flag(FLAG_RECORDED):
		if state.get_quest_state(QUEST_ID) != QUEST_STATE_COMPLETE:
			errors.append("recorded finale must have complete quest state")
		for group: Dictionary in [_ROLE_FLAGS, _KNOWLEDGE_FLAGS, _WARNING_FLAGS, _OPENING_FLAGS]:
			if _selected_count(state, group) != 1:
				errors.append("recorded finale flag group must select exactly one value")
		var record_validation := validate_record(build_record(state))
		errors.append_array(record_validation["errors"])
	return {"valid": errors.is_empty(), "errors": errors}


static func _resolve_warning(state: GameState) -> StringName:
	if not state.get_flag(FLAG_WARNING_ATTEMPTED):
		return WARNING_NOT_ATTEMPTED
	if state.get_flag(FLAG_WARNING_DELIVERED):
		return WARNING_DELIVERED
	return WARNING_INTERCEPTED


static func _opening_for_role(role: StringName) -> StringName:
	match role:
		ROLE_HALL_WITNESS:
			return OPENING_WITNESS_UNDER_GUARD
		ROLE_WARNING_COURIER:
			return OPENING_WARNING_NETWORK_SCATTERED
		ROLE_AFTERMATH_INVESTIGATOR:
			return OPENING_BETRAYAL_RECONSTRUCTED
	return &""


static func _set_exclusive_flag(
	state: GameState, flag_map: Dictionary, selected: StringName
) -> void:
	for key: StringName in flag_map:
		state.set_flag(StringName(flag_map[key]), key == selected)


static func _selected_key(state: GameState, flag_map: Dictionary) -> StringName:
	for key: StringName in flag_map:
		if state.get_flag(StringName(flag_map[key])):
			return key
	return &""


static func _selected_count(state: GameState, flag_map: Dictionary) -> int:
	var count := 0
	for key: StringName in flag_map:
		if state.get_flag(StringName(flag_map[key])):
			count += 1
	return count
