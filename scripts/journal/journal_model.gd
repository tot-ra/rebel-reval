class_name JournalModel
extends RefCounted

## Builds player-facing journal snapshots from quest content and GameState.
## Quest outcomes are never surfaced here; only objectives and discovered facts.

const EVALUATOR_SCRIPT := preload("res://scripts/state/state_rule_evaluator.gd")


static func build_snapshot(
	state: GameState,
	content_db: ContentDB,
	evaluator: StateRuleEvaluator = null
) -> Dictionary:
	var rule_evaluator := evaluator if evaluator != null else EVALUATOR_SCRIPT.new()
	var objectives: Array[Dictionary] = []
	var evidence: Array[Dictionary] = []

	if state == null or content_db == null or not content_db.is_loaded():
		return {"objectives": objectives, "evidence": evidence}

	for quest_id in content_db.get_ids_by_type(ContentDB.TYPE_QUEST):
		var quest := content_db.get_quest(quest_id)
		if quest.is_empty():
			continue
		var current_state := state.get_quest_state(quest_id)
		if current_state.is_empty():
			continue
		if _is_terminal_state(quest, current_state):
			continue

		var objective := _current_objective_for_quest(quest, quest_id, current_state, state, rule_evaluator)
		if not objective.is_empty():
			objectives.append(objective)

		for entry in _journal_evidence_entries(quest):
			var fact_id := StringName(String(entry.get("fact_id", "")))
			if fact_id.is_empty() or not state.get_fact(fact_id):
				continue
			evidence.append({
				"fact_id": fact_id,
				"text": String(entry.get("text", "")),
				"quest_id": quest_id,
			})

	objectives.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("quest_id", "")) < String(b.get("quest_id", ""))
	)
	evidence.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left := "%s:%s" % [String(a.get("quest_id", "")), String(a.get("fact_id", ""))]
		var right := "%s:%s" % [String(b.get("quest_id", "")), String(b.get("fact_id", ""))]
		return left < right
	)
	return {"objectives": objectives, "evidence": evidence}


static func _current_objective_for_quest(
	quest: Dictionary,
	quest_id: StringName,
	current_state: StringName,
	state: GameState,
	evaluator: StateRuleEvaluator
) -> Dictionary:
	var current_index := _state_index(quest, String(current_state))
	if current_index < 0:
		return {}

	var objectives: Variant = quest.get("objectives", [])
	if typeof(objectives) != TYPE_ARRAY:
		return {}

	for value in objectives as Array:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var objective := value as Dictionary
		var target_state := String(objective.get("state_id", ""))
		if target_state.is_empty():
			continue
		var target_index := _state_index(quest, target_state)
		if target_index < 0 or current_index >= target_index:
			continue
		if not _objective_conditions_met(objective, state, evaluator):
			continue
		return {
			"quest_id": quest_id,
			"quest_title": String(quest.get("title", String(quest_id))),
			"objective_id": String(objective.get("id", "")),
			"text": String(objective.get("text", "")),
		}
	return {}


static func _objective_conditions_met(
	objective: Dictionary,
	state: GameState,
	evaluator: StateRuleEvaluator
) -> bool:
	var conditions: Variant = objective.get("conditions", [])
	if typeof(conditions) != TYPE_ARRAY:
		return true
	return evaluator.evaluate_conditions(conditions as Array, state)


static func _is_terminal_state(quest: Dictionary, current_state: StringName) -> bool:
	for value in quest.get("states", []) as Array:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var state_record := value as Dictionary
		if String(state_record.get("id", "")) != String(current_state):
			continue
		return bool(state_record.get("terminal", false))
	return false


static func _state_index(quest: Dictionary, state_id: String) -> int:
	var states: Variant = quest.get("states", [])
	if typeof(states) != TYPE_ARRAY:
		return -1
	for index in (states as Array).size():
		var value: Variant = (states as Array)[index]
		if typeof(value) == TYPE_DICTIONARY and String((value as Dictionary).get("id", "")) == state_id:
			return index
	return -1


static func _journal_evidence_entries(quest: Dictionary) -> Array:
	var entries: Variant = quest.get("journal_evidence", [])
	if typeof(entries) != TYPE_ARRAY:
		return []
	return entries as Array
