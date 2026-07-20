class_name EncounterCheckpoint
extends RefCounted

## Combat failure retry checkpoint (P1-027).
## Arms a GameState payload at encounter start so a failed fight can restore
## narrative progress (dialogue seen, quest/flags) without replaying completed
## dialogue or writing a false encounter outcome.

signal armed(encounter_id: StringName)
signal failed(encounter_id: StringName)
signal restored(encounter_id: StringName)
signal cleared(encounter_id: StringName)

var encounter_id: StringName = &""
var is_armed := false
var failure_pending := false
var last_restore_ok := false
var _payload: Dictionary = {}


## Capture the live GameState as the retry restore point. Call when the
## encounter becomes active, after pre-fight dialogue/quest progress is already
## written into state.
func arm(state: GameState, id: StringName) -> bool:
	if state == null or id.is_empty():
		return false
	encounter_id = id
	_payload = state.save_payload().duplicate(true)
	is_armed = true
	failure_pending = false
	last_restore_ok = false
	armed.emit(encounter_id)
	return true


## Mark the armed encounter as failed (typically player death). Does not mutate
## GameState; callers restore explicitly so UI can present a Retry affordance.
func mark_failed() -> bool:
	if not is_armed:
		return false
	failure_pending = true
	failed.emit(encounter_id)
	return true


## Reload the armed payload into state. Preserves completed dialogue and prior
## quest/flag values from arm time; undoes mid-fight corruption.
func restore(state: GameState) -> bool:
	last_restore_ok = false
	if state == null or not is_armed or _payload.is_empty():
		return false
	var errors := state.load_payload(_payload.duplicate(true))
	if not errors.is_empty():
		return false
	failure_pending = false
	last_restore_ok = true
	restored.emit(encounter_id)
	return true


## Drop the armed snapshot (successful encounter close or scene exit).
func clear() -> void:
	var previous := encounter_id
	encounter_id = &""
	is_armed = false
	failure_pending = false
	last_restore_ok = false
	_payload.clear()
	if not previous.is_empty():
		cleared.emit(previous)


func has_payload() -> bool:
	return is_armed and not _payload.is_empty()


## Test/inspection helper: dialogue keys captured at arm time.
func armed_dialogue_nodes_seen() -> Array[StringName]:
	var keys: Array[StringName] = []
	if _payload.is_empty():
		return keys
	var raw: Variant = _payload.get("dialogue_nodes_seen", {})
	if not raw is Dictionary:
		return keys
	for key in raw as Dictionary:
		keys.append(StringName(String(key)))
	keys.sort()
	return keys


func armed_quest_state(quest_id: StringName) -> StringName:
	if _payload.is_empty() or quest_id.is_empty():
		return &""
	var raw: Variant = _payload.get("quest_states", {})
	if not raw is Dictionary:
		return &""
	return StringName(String((raw as Dictionary).get(String(quest_id), "")))
