class_name NunnatornStateModel
extends RefCounted

## Stable persistence adapter for the developer-only Nunnatorn interior.
## WHY: the scene is disposable, while door, encounter, reward, and retry state
## must survive a map re-entry and a GameState save/load round trip.

const LOCATION_ID := &"loc.lower_town.nunnatorn_interior"
const OBJECT_ID := &"nunnatorn_state"
const RETRY_ENCOUNTER_ID := &"encounter.nunnatorn_boss"
const CURRENT_VERSION := 1

const DOOR_OPEN := "open"
const DOOR_CLOSED := "closed"
const OUTCOME_KILL := "kill"
const OUTCOME_BYPASS := "bypass"
const OUTCOME_PENDING := ""
const RETRY_CLEAR := "clear"
const RETRY_ARMED := "armed"
const RETRY_FAILED := "failed"


## Returns the canonical fresh-entry shape. Values are plain JSON types because
## MapStableStateStore is also consumed by save fixtures and migration tooling.
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


## Read and normalize state. Missing data is the backward-compatible fresh-entry
## default used by saves created before the Nunnatorn package existed.
static func snapshot(state: GameState) -> Dictionary:
	if state == null:
		return defaults()
	return _normalize(state.map_world_state.object_delta(LOCATION_ID, OBJECT_ID))


## Materialize the default/migrated record into the stable map-state store.
static func ensure(state: GameState) -> Dictionary:
	if state == null:
		return defaults()
	var normalized := snapshot(state)
	if state.map_world_state.object_delta(LOCATION_ID, OBJECT_ID) != normalized:
		_write(state, normalized)
	return normalized


## Record an entry without resetting a closed door, an encounter outcome, or loot.
static func record_entry(state: GameState) -> bool:
	if state == null:
		return false
	var current := ensure(state)
	current["entry_count"] = int(current["entry_count"]) + 1
	return _write(state, current)


static func set_door_state(state: GameState, door_state: String) -> bool:
	if state == null or (door_state != DOOR_OPEN and door_state != DOOR_CLOSED):
		return false
	var current := ensure(state)
	current["door_state"] = door_state
	return _write(state, current)


## Outcomes are immutable once resolved. This prevents a re-entry from replacing
## a lethal result with the alternate route (or vice versa).
static func set_boss_outcome(state: GameState, outcome: String) -> bool:
	if state == null or (outcome != OUTCOME_KILL and outcome != OUTCOME_BYPASS):
		return false
	var current := ensure(state)
	var previous := String(current["boss_outcome"])
	if not previous.is_empty():
		return previous == outcome
	current["boss_outcome"] = outcome
	current["retry_state"] = RETRY_CLEAR
	return _write(state, current)


## Collection methods are intentionally one-shot. Callers can use the boolean to
## avoid duplicating a reward when the player leaves and re-enters the tower.
static func mark_loot_collected(state: GameState) -> bool:
	return _mark_once(state, "loot_collected")


static func mark_evidence_recorded(state: GameState) -> bool:
	return _mark_once(state, "evidence_recorded")


## EncounterCheckpoint stores a GameState payload, not scene nodes. The stable
## retry marker is written before arming so restore returns to the authored entry.
static func arm_retry(state: GameState, checkpoint: EncounterCheckpoint) -> bool:
	if state == null or checkpoint == null:
		return false
	var current := ensure(state)
	current["retry_state"] = RETRY_ARMED
	if not _write(state, current):
		return false
	if checkpoint.arm(state, RETRY_ENCOUNTER_ID):
		return true
	current["retry_state"] = RETRY_CLEAR
	_write(state, current)
	return false


static func mark_retry_failed(state: GameState, checkpoint: EncounterCheckpoint) -> bool:
	if state == null or checkpoint == null or not checkpoint.mark_failed():
		return false
	var current := ensure(state)
	current["retry_state"] = RETRY_FAILED
	return _write(state, current)


## A failed retry restores the complete pre-fight GameState, including the stable
## Nunnatorn record. The checkpoint itself is cleared only after an explicit close.
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


## Migrate the early contract spelling (`version`, `door`, `boss`, `loot`, and
## `evidence`) while defaulting fields absent from pre-package saves.
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
	return door if door == DOOR_OPEN or door == DOOR_CLOSED else DOOR_OPEN


static func _normalized_outcome(value: Variant) -> String:
	var outcome := String(value)
	return outcome if outcome == OUTCOME_KILL or outcome == OUTCOME_BYPASS else OUTCOME_PENDING


static func _normalized_retry(value: Variant) -> String:
	var retry := String(value)
	return retry if retry in [RETRY_CLEAR, RETRY_ARMED, RETRY_FAILED] else RETRY_CLEAR
