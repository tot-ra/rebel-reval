class_name KuldjalaStateModel
extends RefCounted

## Durable Kuldjala state. Scene nodes stay transient while door, outcome,
## rewards, and retry markers survive map re-entry and save/load.

const LOCATION_ID := &"loc.lower_town.kuldjala_interior"
const OBJECT_ID := &"kuldjala_state"
const RETRY_ENCOUNTER_ID := &"encounter.kuldjala_boss"
const CURRENT_VERSION := 1

const DOOR_OPEN := "open"
const DOOR_CLOSED := "closed"
const OUTCOME_KILL := "kill"
const OUTCOME_BYPASS := "bypass"
const OUTCOME_PENDING := ""
const RETRY_CLEAR := "clear"
const RETRY_ARMED := "armed"
const RETRY_FAILED := "failed"


static func defaults() -> Dictionary:
	return {
		"state_version": CURRENT_VERSION,
		"door_state": DOOR_OPEN,
		"boss_outcome": OUTCOME_PENDING,
		"loot_collected": false,
		"evidence_recorded": false,
		"retry_state": RETRY_CLEAR,
		"entry_count": 0,
	}


static func snapshot(state: GameState) -> Dictionary:
	if state == null:
		return defaults()
	return _normalize(state.map_world_state.object_delta(LOCATION_ID, OBJECT_ID))


static func ensure(state: GameState) -> Dictionary:
	if state == null:
		return defaults()
	var normalized := snapshot(state)
	if state.map_world_state.object_delta(LOCATION_ID, OBJECT_ID) != normalized:
		_write(state, normalized)
	return normalized


static func record_entry(state: GameState) -> bool:
	if state == null:
		return false
	var current := ensure(state)
	current["entry_count"] = int(current["entry_count"]) + 1
	return _write(state, current)


static func set_door_state(state: GameState, door_state: String) -> bool:
	if state == null or door_state not in [DOOR_OPEN, DOOR_CLOSED]:
		return false
	var current := ensure(state)
	current["door_state"] = door_state
	return _write(state, current)


## Outcomes are immutable after resolution so re-entry cannot rewrite history.
static func set_boss_outcome(state: GameState, outcome: String) -> bool:
	if state == null or outcome not in [OUTCOME_KILL, OUTCOME_BYPASS]:
		return false
	var current := ensure(state)
	var previous := String(current["boss_outcome"])
	if not previous.is_empty():
		return previous == outcome
	current["boss_outcome"] = outcome
	current["retry_state"] = RETRY_CLEAR
	return _write(state, current)


static func mark_loot_collected(state: GameState) -> bool:
	return _mark_once(state, "loot_collected")


static func mark_evidence_recorded(state: GameState) -> bool:
	return _mark_once(state, "evidence_recorded")


## The checkpoint owns only a serialized GameState payload, never scene nodes.
static func arm_retry(state: GameState, checkpoint: EncounterCheckpoint) -> bool:
	if state == null or checkpoint == null:
		return false
	var current := ensure(state)
	current["retry_state"] = RETRY_ARMED
	if not _write(state, current):
		return false
	checkpoint.arm(state, RETRY_ENCOUNTER_ID)
	return checkpoint.is_armed


static func mark_retry_failed(state: GameState, checkpoint: EncounterCheckpoint) -> bool:
	if state == null or checkpoint == null or not checkpoint.is_armed:
		return false
	var current := ensure(state)
	current["retry_state"] = RETRY_FAILED
	return _write(state, current)


static func restore_retry(state: GameState, checkpoint: EncounterCheckpoint) -> bool:
	if state == null or checkpoint == null or not checkpoint.restore(state):
		return false
	var current := ensure(state)
	current["retry_state"] = RETRY_ARMED
	return _write(state, current)


static func clear_retry(state: GameState, checkpoint: EncounterCheckpoint) -> bool:
	if checkpoint != null:
		checkpoint.clear()
	if state == null:
		return false
	var current := ensure(state)
	current["retry_state"] = RETRY_CLEAR
	return _write(state, current)


static func _mark_once(state: GameState, field: String) -> bool:
	if state == null:
		return false
	var current := ensure(state)
	if bool(current[field]):
		return false
	current[field] = true
	return _write(state, current)


static func _write(state: GameState, value: Dictionary) -> bool:
	return state.map_world_state.record_object_delta(LOCATION_ID, OBJECT_ID, _normalize(value))


## Accept early alias spellings so pre-package saves migrate safely.
static func _normalize(raw: Dictionary) -> Dictionary:
	var source := raw if raw != null else {}
	var result := defaults()
	result["state_version"] = CURRENT_VERSION
	result["door_state"] = _normalized_door(
		source.get("door_state", source.get("door", DOOR_OPEN))
	)
	result["boss_outcome"] = _normalized_outcome(
		source.get("boss_outcome", source.get("boss", OUTCOME_PENDING))
	)
	result["loot_collected"] = bool(source.get("loot_collected", source.get("loot", false)))
	result["evidence_recorded"] = bool(
		source.get("evidence_recorded", source.get("evidence", false))
	)
	result["retry_state"] = _normalized_retry(
		source.get("retry_state", source.get("retry", RETRY_CLEAR))
	)
	result["entry_count"] = maxi(0, int(source.get("entry_count", source.get("entries", 0))))
	return result


static func _normalized_door(value: Variant) -> String:
	var door := String(value)
	return door if door in [DOOR_OPEN, DOOR_CLOSED] else DOOR_OPEN


static func _normalized_outcome(value: Variant) -> String:
	var outcome := String(value)
	return outcome if outcome in [OUTCOME_KILL, OUTCOME_BYPASS] else OUTCOME_PENDING


static func _normalized_retry(value: Variant) -> String:
	var retry := String(value)
	return retry if retry in [RETRY_CLEAR, RETRY_ARMED, RETRY_FAILED] else RETRY_CLEAR
