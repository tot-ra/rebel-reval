class_name EncounterOutcomeDefinition
extends RefCounted

## Authored mapping from encounter outcome kinds to quest state values (P1-026).
## P1-026a loads the same shape from ContentDB so P2-009 / P5-004 can swap quest
## mappings without code edits. watch_checkpoint() remains a typed smoke mirror.

const WATCH_CHECKPOINT_ID := &"encounter.watch_checkpoint"

var encounter_id: StringName = &""
var quest_id: StringName = &""
## kind StringName -> quest state StringName
var quest_states: Dictionary = {}
## Optional secondary flag written true when any outcome resolves.
var resolved_flag: StringName = &""


## Demo fixture for the watch-checkpoint night stub used by the combat room.
## Kept in sync with content/examples/valid/encounter.watch_checkpoint.json.
static func watch_checkpoint() -> EncounterOutcomeDefinition:
	var definition := EncounterOutcomeDefinition.new()
	definition.encounter_id = WATCH_CHECKPOINT_ID
	definition.quest_id = &"quest.bitter_brew"
	definition.resolved_flag = &"flag.watch_checkpoint_resolved"
	definition.quest_states = {
		EncounterOutcome.KIND_SURRENDER: &"night_surrendered",
		EncounterOutcome.KIND_ESCAPE: &"night_escaped",
		EncounterOutcome.KIND_BYPASS: &"night_bypassed",
		EncounterOutcome.KIND_KILL: &"night_fought",
	}
	return definition


## Build from a ContentDB encounter record. Returns an empty definition when the
## record is missing required fields or has no supported outcome kinds.
static func from_content_record(record: Dictionary) -> EncounterOutcomeDefinition:
	var definition := EncounterOutcomeDefinition.new()
	if record.is_empty():
		return definition
	if String(record.get("type", "")) != ContentDB.TYPE_ENCOUNTER:
		return definition
	var content_id := StringName(String(record.get("id", "")))
	var quest := StringName(String(record.get("quest_id", "")))
	if content_id.is_empty() or quest.is_empty():
		return definition
	definition.encounter_id = content_id
	definition.quest_id = quest
	var flag_raw := String(record.get("resolved_flag", ""))
	if not flag_raw.is_empty():
		definition.resolved_flag = StringName(flag_raw)
	var states: Dictionary = {}
	for entry_value in record.get("outcomes", []) as Array:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry := entry_value as Dictionary
		var kind := StringName(String(entry.get("kind", "")))
		var quest_state := StringName(String(entry.get("quest_state", "")))
		if not EncounterOutcome.is_known(kind) or quest_state.is_empty():
			continue
		states[kind] = quest_state
	definition.quest_states = states
	return definition


## Load encounter.watch_checkpoint (or another id) through ContentDB.
## Falls back to the typed smoke mirror when content is unavailable.
static func from_content_db(
	content_db: ContentDB,
	encounter_id: StringName = WATCH_CHECKPOINT_ID
) -> EncounterOutcomeDefinition:
	if content_db == null or not content_db.is_loaded():
		return watch_checkpoint() if encounter_id == WATCH_CHECKPOINT_ID else EncounterOutcomeDefinition.new()
	var record := content_db.get_encounter(encounter_id)
	if record.is_empty():
		return watch_checkpoint() if encounter_id == WATCH_CHECKPOINT_ID else EncounterOutcomeDefinition.new()
	var loaded := from_content_record(record)
	if loaded.encounter_id.is_empty() or loaded.quest_states.is_empty():
		return watch_checkpoint() if encounter_id == WATCH_CHECKPOINT_ID else EncounterOutcomeDefinition.new()
	return loaded


func quest_state_for(kind: StringName) -> StringName:
	return quest_states.get(kind, &"") as StringName


func supports(kind: StringName) -> bool:
	return EncounterOutcome.is_known(kind) and quest_states.has(kind)
