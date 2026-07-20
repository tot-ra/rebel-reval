class_name EncounterOutcomeResolver
extends RefCounted

## Applies authored encounter outcomes to GameState and enemy hosts (P1-026).
## Lethal and non-lethal closes share this path so quest state stays one contract.

signal resolved(
	kind: StringName,
	quest_id: StringName,
	quest_state: StringName,
	encounter_id: StringName
)

var last_kind: StringName = &""
var last_quest_id: StringName = &""
var last_quest_state: StringName = &""
var last_encounter_id: StringName = &""
var last_ok := false


## Resolve one authored outcome. Non-lethal kinds force-disengage enemies without
## marking them dead; KIND_KILL marks hosts dead. Quest writes always use
## GameState.set_quest_state for the definition's quest_id.
func resolve(
	state: GameState,
	definition: EncounterOutcomeDefinition,
	kind: StringName,
	enemies: Array = []
) -> bool:
	last_ok = false
	last_kind = kind
	last_quest_id = &""
	last_quest_state = &""
	last_encounter_id = &""
	if state == null or definition == null:
		return false
	if not definition.supports(kind):
		return false
	var quest_state := definition.quest_state_for(kind)
	if quest_state.is_empty() or definition.quest_id.is_empty():
		return false

	_apply_enemy_close(kind, enemies)
	state.set_quest_state(definition.quest_id, quest_state)
	if not definition.resolved_flag.is_empty():
		state.set_flag(definition.resolved_flag, true)

	last_ok = true
	last_kind = kind
	last_quest_id = definition.quest_id
	last_quest_state = quest_state
	last_encounter_id = definition.encounter_id
	resolved.emit(kind, definition.quest_id, quest_state, definition.encounter_id)
	return true


func _apply_enemy_close(kind: StringName, enemies: Array) -> void:
	for entry in enemies:
		var machine := _machine_from(entry)
		if machine == null:
			continue
		if EncounterOutcome.is_non_lethal(kind):
			# Why: surrender/escape/bypass must leave actors alive for aftermath
			# and retry (P1-027) while still ending the fight loop.
			machine.force_disengage()
			machine.clear_target()
			# Scene hosts keep a Node2D target that would re-feed perception on tick.
			if entry != null and entry.has_method("set_ai_target"):
				entry.call("set_ai_target", null)
		elif kind == EncounterOutcome.KIND_KILL:
			machine.mark_dead()


func _machine_from(entry: Variant) -> EnemyCombatStateMachine:
	if entry is EnemyCombatStateMachine:
		return entry as EnemyCombatStateMachine
	if entry is CombatRoomEnemy:
		return (entry as CombatRoomEnemy).get_machine()
	if entry != null and entry.has_method("get_machine"):
		var maybe: Variant = entry.call("get_machine")
		if maybe is EnemyCombatStateMachine:
			return maybe as EnemyCombatStateMachine
	return null
