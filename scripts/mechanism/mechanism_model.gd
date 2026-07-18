class_name MechanismModel
extends RefCounted

## Builds player-facing mechanism snapshots from authored content and GameState.

const EVALUATOR_SCRIPT := preload("res://scripts/state/state_rule_evaluator.gd")


static func build_snapshot(
	mechanism_id: StringName,
	state: GameState,
	content_db: ContentDB,
	evaluator: StateRuleEvaluator = null
) -> Dictionary:
	var empty := _empty_snapshot(mechanism_id)
	if state == null or content_db == null or not content_db.is_loaded():
		return empty

	var mechanism := content_db.get_mechanism(mechanism_id)
	if mechanism.is_empty():
		return empty

	var rule_evaluator := evaluator if evaluator != null else EVALUATOR_SCRIPT.new()
	var response := _resolve_response(mechanism, state, rule_evaluator)
	if response.is_empty():
		return empty

	return {
		"mechanism_id": mechanism_id,
		"title": String(mechanism.get("title", String(mechanism_id))),
		"commission_id": StringName(String(mechanism.get("commission_id", ""))),
		"object_item_id": StringName(String(mechanism.get("object_item_id", ""))),
		"location_id": StringName(String(mechanism.get("location_id", ""))),
		"response_id": StringName(String(response.get("id", ""))),
		"behavior": String(response.get("behavior", "idle")),
		"summary": String(response.get("summary", "")),
		"effects": _runtime_rules(response.get("effects", [])),
	}


static func _resolve_response(
	mechanism: Dictionary,
	state: GameState,
	evaluator: StateRuleEvaluator
) -> Dictionary:
	for response_value in mechanism.get("responses", []) as Array:
		if typeof(response_value) != TYPE_DICTIONARY:
			continue
		var response := response_value as Dictionary
		var requires: Array = response.get("requires", [])
		if requires.is_empty() or evaluator.evaluate_conditions(_runtime_rules(requires), state):
			return response

	var default_response: Variant = mechanism.get("default_response", {})
	if typeof(default_response) == TYPE_DICTIONARY:
		return default_response as Dictionary
	return {}


static func _empty_snapshot(mechanism_id: StringName) -> Dictionary:
	return {
		"mechanism_id": mechanism_id,
		"title": "",
		"commission_id": &"",
		"object_item_id": &"",
		"location_id": &"",
		"response_id": &"",
		"behavior": "idle",
		"summary": "",
		"effects": [],
	}


static func _runtime_rules(authored_rules: Variant) -> Array:
	var runtime_rules: Array = []
	if typeof(authored_rules) != TYPE_ARRAY:
		return runtime_rules
	for value in authored_rules as Array:
		if typeof(value) != TYPE_DICTIONARY:
			runtime_rules.append(value)
			continue
		var rule := (value as Dictionary).duplicate(true)
		if typeof(rule.get("amount")) == TYPE_FLOAT:
			var amount := float(rule["amount"])
			if amount == floor(amount):
				rule["amount"] = int(amount)
		runtime_rules.append(rule)
	return runtime_rules
