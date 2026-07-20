class_name EncounterOutcomeDefinition
extends RefCounted

## Authored mapping from encounter outcome kinds to quest state values (P1-026).
## Content later (P5-004 / P2-009) can load the same shape; this typed holder
## keeps the combat smoke host and tests free of quest-specific branching.

var encounter_id: StringName = &""
var quest_id: StringName = &""
## kind StringName -> quest state StringName
var quest_states: Dictionary = {}
## Optional secondary flag written true when any outcome resolves.
var resolved_flag: StringName = &""


## Demo fixture for the watch-checkpoint night stub used by the combat room.
static func watch_checkpoint() -> EncounterOutcomeDefinition:
	var definition := EncounterOutcomeDefinition.new()
	definition.encounter_id = &"encounter.watch_checkpoint"
	definition.quest_id = &"quest.bitter_brew"
	definition.resolved_flag = &"flag.watch_checkpoint_resolved"
	definition.quest_states = {
		EncounterOutcome.KIND_SURRENDER: &"night_surrendered",
		EncounterOutcome.KIND_ESCAPE: &"night_escaped",
		EncounterOutcome.KIND_BYPASS: &"night_bypassed",
		EncounterOutcome.KIND_KILL: &"night_fought",
	}
	return definition


func quest_state_for(kind: StringName) -> StringName:
	return quest_states.get(kind, &"") as StringName


func supports(kind: StringName) -> bool:
	return EncounterOutcome.is_known(kind) and quest_states.has(kind)
