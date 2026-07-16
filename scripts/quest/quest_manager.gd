class_name QuestManager
extends RefCounted

## Owns quest progression while keeping authored quest data read-only in ContentDB.
## A transition is applied only after the complete quest graph, conditions, and
## effect batch have been validated.

enum Result {
	OK,
	INVALID_DEPENDENCIES,
	UNKNOWN_QUEST,
	INVALID_QUEST_RECORD,
	ALREADY_STARTED,
	ENTRY_CONDITIONS_NOT_MET,
	UNKNOWN_TRANSITION,
	INVALID_CURRENT_STATE,
	CONDITIONS_NOT_MET,
	EFFECTS_REJECTED,
}

var _content_db: ContentDB
var _state: GameState
var _evaluator: StateRuleEvaluator
var _last_result := Result.OK
var _last_error := ""


func _init(
	content_db: ContentDB = null,
	state: GameState = null,
	evaluator: StateRuleEvaluator = null
) -> void:
	_content_db = content_db
	_state = state
	_evaluator = evaluator if evaluator != null else StateRuleEvaluator.new()


func get_last_result() -> Result:
	return _last_result


func get_last_error() -> String:
	return _last_error


func start_quest(quest_id: StringName) -> bool:
	_reset_result()
	var quest := _load_valid_quest(quest_id)
	if quest.is_empty():
		return false
	if not _state.get_quest_state(quest_id).is_empty():
		return _fail(Result.ALREADY_STARTED, "quest %s is already started" % quest_id)

	var entry_conditions := _runtime_rules(quest.get("entry_conditions", []))
	if not _evaluator.evaluate_conditions(entry_conditions, _state):
		if not _evaluator.get_last_error().is_empty():
			return _fail(
				Result.INVALID_QUEST_RECORD,
				"quest %s has invalid entry conditions: %s" % [quest_id, _evaluator.get_last_error()]
			)
		return _fail(Result.ENTRY_CONDITIONS_NOT_MET, "entry conditions are not met for quest %s" % quest_id)

	_state.set_quest_state(quest_id, StringName(String(quest["initial_state"])))
	return true


func transition(quest_id: StringName, transition_id: StringName) -> bool:
	_reset_result()
	var quest := _load_valid_quest(quest_id)
	if quest.is_empty():
		return false

	var transition_record := _find_transition(quest, transition_id)
	if transition_record.is_empty():
		return _fail(
			Result.UNKNOWN_TRANSITION,
			"quest %s has no declared transition %s" % [quest_id, transition_id]
		)

	var current_state := _state.get_quest_state(quest_id)
	var declared_states := _state_ids(quest)
	if current_state.is_empty() or not declared_states.has(String(current_state)):
		return _fail(
			Result.INVALID_CURRENT_STATE,
			"quest %s has invalid current state %s" % [quest_id, current_state]
		)
	if String(current_state) != String(transition_record["from_state"]):
		return _fail(
			Result.INVALID_CURRENT_STATE,
			"transition %s requires state %s, current state is %s"
			% [transition_id, transition_record["from_state"], current_state]
		)

	var conditions := _runtime_rules(transition_record.get("conditions", []))
	if not _evaluator.evaluate_conditions(conditions, _state):
		if not _evaluator.get_last_error().is_empty():
			return _fail(
				Result.INVALID_QUEST_RECORD,
				"transition %s has invalid conditions: %s" % [transition_id, _evaluator.get_last_error()]
			)
		return _fail(Result.CONDITIONS_NOT_MET, "conditions are not met for transition %s" % transition_id)

	# The target state is appended last so authored effects execute in stable JSON
	# order and observers can only see the new quest state after all side effects.
	var effects := _runtime_rules(transition_record["effects"])
	effects.append({
		"op": "set_quest_state",
		"key": String(quest_id),
		"value": String(transition_record["to_state"]),
	})
	if not _evaluator.apply_effects(effects, _state):
		return _fail(
			Result.EFFECTS_REJECTED,
			"transition %s effects were rejected: %s" % [transition_id, _evaluator.get_last_error()]
		)
	return true


func _load_valid_quest(quest_id: StringName) -> Dictionary:
	if _content_db == null or _state == null or _evaluator == null:
		_fail(Result.INVALID_DEPENDENCIES, "QuestManager requires ContentDB, GameState, and StateRuleEvaluator")
		return {}

	var quest := _content_db.get_quest(quest_id)
	if quest.is_empty():
		_fail(Result.UNKNOWN_QUEST, "quest record was not found: %s" % quest_id)
		return {}

	var validation_error := _validate_quest_record(quest, quest_id)
	if not validation_error.is_empty():
		_fail(Result.INVALID_QUEST_RECORD, validation_error)
		return {}
	return quest


func _validate_quest_record(quest: Dictionary, quest_id: StringName) -> String:
	if typeof(quest.get("initial_state")) != TYPE_STRING or String(quest["initial_state"]).is_empty():
		return "quest %s requires a non-empty initial_state" % quest_id
	if typeof(quest.get("states")) != TYPE_ARRAY:
		return "quest %s requires a states array" % quest_id
	if typeof(quest.get("entry_conditions", [])) != TYPE_ARRAY:
		return "quest %s entry_conditions must be an array" % quest_id
	if typeof(quest.get("transitions")) != TYPE_ARRAY:
		return "quest %s requires a transitions array" % quest_id

	var state_ids := _state_ids(quest)
	if state_ids.is_empty():
		return "quest %s requires at least one valid state" % quest_id
	if not state_ids.has(String(quest["initial_state"])):
		return "quest %s initial_state is not declared" % quest_id

	var state_count := 0
	for value in quest["states"] as Array:
		if typeof(value) != TYPE_DICTIONARY:
			return "quest %s states must be dictionaries" % quest_id
		var state_id := String((value as Dictionary).get("id", ""))
		if state_id.is_empty():
			return "quest %s has a state without an id" % quest_id
		state_count += 1
	if state_ids.size() != state_count:
		return "quest %s has duplicate state ids" % quest_id

	var runtime_entry_conditions := _runtime_rules(quest.get("entry_conditions", []))
	_evaluator.evaluate_conditions(runtime_entry_conditions, _state)
	if not _evaluator.get_last_error().is_empty():
		return "quest %s has invalid entry conditions: %s" % [quest_id, _evaluator.get_last_error()]

	var seen_transitions: Dictionary = {}
	var transitions: Array = quest["transitions"]
	if transitions.is_empty():
		return "quest %s requires at least one transition" % quest_id
	for index in transitions.size():
		var value: Variant = transitions[index]
		if typeof(value) != TYPE_DICTIONARY:
			return "quest %s transition %d must be a dictionary" % [quest_id, index]
		var transition_record := value as Dictionary
		for field in ["id", "from_state", "to_state"]:
			if typeof(transition_record.get(field)) != TYPE_STRING or String(transition_record[field]).is_empty():
				return "quest %s transition %d requires string %s" % [quest_id, index, field]

		var transition_id := String(transition_record["id"])
		if seen_transitions.has(transition_id):
			return "quest %s has duplicate transition id %s" % [quest_id, transition_id]
		seen_transitions[transition_id] = true
		if not state_ids.has(String(transition_record["from_state"])):
			return "quest %s transition %s has unknown from_state" % [quest_id, transition_id]
		if not state_ids.has(String(transition_record["to_state"])):
			return "quest %s transition %s has unknown to_state" % [quest_id, transition_id]
		if typeof(transition_record.get("conditions", [])) != TYPE_ARRAY:
			return "quest %s transition %s conditions must be an array" % [quest_id, transition_id]
		if typeof(transition_record.get("effects")) != TYPE_ARRAY:
			return "quest %s transition %s effects must be an array" % [quest_id, transition_id]

		var runtime_conditions := _runtime_rules(transition_record.get("conditions", []))
		_evaluator.evaluate_conditions(runtime_conditions, _state)
		if not _evaluator.get_last_error().is_empty():
			return "quest %s transition %s has invalid conditions: %s" \
				% [quest_id, transition_id, _evaluator.get_last_error()]

		var authored_effects: Array = transition_record["effects"]
		for effect_value in authored_effects:
			if typeof(effect_value) == TYPE_DICTIONARY:
				var effect := effect_value as Dictionary
				if String(effect.get("op", "")) == "set_quest_state" \
						and String(effect.get("key", "")) == String(quest_id):
					return "quest %s transition %s must use to_state instead of setting its own quest state" \
						% [quest_id, transition_id]
		var scratch_state := GameState.new()
		var runtime_effects := _runtime_rules(authored_effects)
		if not _evaluator.apply_effects(runtime_effects, scratch_state):
			return "quest %s transition %s has invalid effects: %s" \
				% [quest_id, transition_id, _evaluator.get_last_error()]
	return ""


func _runtime_rules(authored_rules: Variant) -> Array:
	var runtime_rules: Array = []
	if typeof(authored_rules) != TYPE_ARRAY:
		return runtime_rules
	for value in authored_rules as Array:
		if typeof(value) != TYPE_DICTIONARY:
			runtime_rules.append(value)
			continue
		var rule := (value as Dictionary).duplicate(true)
		# JSON numbers enter GDScript as floats. Normalize integral amounts at the
		# ContentDB boundary so StateRuleEvaluator keeps its strict runtime API.
		if typeof(rule.get("amount")) == TYPE_FLOAT:
			var amount := float(rule["amount"])
			if amount == floor(amount):
				rule["amount"] = int(amount)
		runtime_rules.append(rule)
	return runtime_rules


func _state_ids(quest: Dictionary) -> Dictionary:
	var ids: Dictionary = {}
	var states: Variant = quest.get("states", [])
	if typeof(states) != TYPE_ARRAY:
		return ids
	for value in states as Array:
		if typeof(value) == TYPE_DICTIONARY:
			var state_id := String((value as Dictionary).get("id", ""))
			if not state_id.is_empty():
				ids[state_id] = true
	return ids


func _find_transition(quest: Dictionary, transition_id: StringName) -> Dictionary:
	for value in quest["transitions"] as Array:
		var transition_record := value as Dictionary
		if String(transition_record["id"]) == String(transition_id):
			return transition_record
	return {}


func _reset_result() -> void:
	_last_result = Result.OK
	_last_error = ""


func _fail(result: Result, message: String) -> bool:
	_last_result = result
	_last_error = message
	return false
