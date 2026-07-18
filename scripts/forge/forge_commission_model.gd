class_name ForgeCommissionModel
extends RefCounted

## Builds player-facing commission snapshots from authored content and GameState.

const EVALUATOR_SCRIPT := preload("res://scripts/state/state_rule_evaluator.gd")

const MATERIAL_LABELS := {
	"common": "Common iron",
	"fine": "Fine steel",
	"rare": "Rare alloy",
}


static func build_snapshot(
	commission_id: StringName,
	state: GameState,
	content_db: ContentDB,
	evaluator: StateRuleEvaluator = null
) -> Dictionary:
	var empty := _empty_snapshot(commission_id)
	if state == null or content_db == null or not content_db.is_loaded():
		return empty

	var commission := content_db.get_commission(commission_id)
	if commission.is_empty():
		return empty

	var rule_evaluator := evaluator if evaluator != null else EVALUATOR_SCRIPT.new()
	var client_id := StringName(String(commission.get("client_id", "")))
	var object_item_id := StringName(String(commission.get("object_item_id", "")))
	var item := content_db.get_item(object_item_id)

	return {
		"commission_id": commission_id,
		"title": String(commission.get("title", String(commission_id))),
		"customer_name": _character_name(content_db, client_id),
		"customer_id": client_id,
		"object_name": _item_name(item, object_item_id),
		"object_item_id": object_item_id,
		"known_purpose": String(commission.get("concrete_order", "")),
		"materials": _format_materials(item),
		"discovered_leverage": _discovered_leverage(commission, state),
		"forging_options": _resolve_forging_options(commission, state, rule_evaluator),
		"already_resolved": is_commission_resolved(state, commission_id),
		"night_consequence": String(commission.get("night_consequence", "")),
	}


static func is_commission_resolved(state: GameState, commission_id: StringName) -> bool:
	if state == null:
		return false
	for record in state.get_forged_records():
		if record.commission_id == commission_id:
			return true
	return false


static func record_id_for(commission_id: StringName, option_id: String) -> StringName:
	var suffix := String(commission_id)
	if suffix.begins_with("commission."):
		suffix = suffix.substr("commission.".length())
	return StringName("forged.%s.%s" % [suffix, option_id])


static func _empty_snapshot(commission_id: StringName) -> Dictionary:
	return {
		"commission_id": commission_id,
		"title": "",
		"customer_name": "",
		"customer_id": &"",
		"object_name": "",
		"object_item_id": &"",
		"known_purpose": "",
		"materials": "",
		"discovered_leverage": [],
		"forging_options": [],
		"already_resolved": false,
		"night_consequence": "",
	}


static func _character_name(content_db: ContentDB, character_id: StringName) -> String:
	if character_id.is_empty():
		return ""
	var character := content_db.get_character(character_id)
	if character.is_empty():
		return String(character_id)
	return String(character.get("name", character_id))


static func _item_name(item: Dictionary, item_id: StringName) -> String:
	if item.is_empty():
		return String(item_id)
	return String(item.get("name", item_id))


static func _format_materials(item: Dictionary) -> String:
	if item.is_empty():
		return "Unknown materials"
	var grade := String(item.get("material_grade", ""))
	var label: String = String(MATERIAL_LABELS.get(grade, grade.capitalize()))
	if label.is_empty():
		return "Unknown materials"
	return label


static func _discovered_leverage(commission: Dictionary, state: GameState) -> Array[String]:
	var leverage: Array[String] = []
	for clue_value in commission.get("investigation_clues", []) as Array:
		if typeof(clue_value) != TYPE_DICTIONARY:
			continue
		var clue := clue_value as Dictionary
		var fact_id := StringName(String(clue.get("reveals_fact_id", "")))
		if fact_id.is_empty() or not state.get_fact(fact_id):
			continue
		var summary := String(clue.get("summary", ""))
		if not summary.is_empty():
			leverage.append(summary)

	if leverage.is_empty():
		return leverage

	var clues: Array = commission.get("investigation_clues", [])
	var all_facts_known := true
	for clue_value in clues:
		if typeof(clue_value) != TYPE_DICTIONARY:
			continue
		var fact_id := StringName(String((clue_value as Dictionary).get("reveals_fact_id", "")))
		if fact_id.is_empty():
			continue
		if not state.get_fact(fact_id):
			all_facts_known = false
			break

	if all_facts_known:
		var hidden := String(commission.get("hidden_contradiction", ""))
		if not hidden.is_empty():
			leverage.append(hidden)
	return leverage


static func _resolve_forging_options(
	commission: Dictionary,
	state: GameState,
	evaluator: StateRuleEvaluator
) -> Array:
	var resolved: Array = []
	for option_value in commission.get("forging_options", []) as Array:
		if typeof(option_value) != TYPE_DICTIONARY:
			continue
		var option := option_value as Dictionary
		var option_id := String(option.get("id", ""))
		if option_id.is_empty():
			continue
		var requires: Array = option.get("requires", [])
		var enabled := true
		var disabled_reason := ""
		if not requires.is_empty():
			enabled = evaluator.evaluate_conditions(_runtime_rules(requires), state)
			if not enabled:
				disabled_reason = "Requirements not met."
		resolved.append({
			"id": option_id,
			"label": String(option.get("label", option_id)),
			"enabled": enabled,
			"disabled_reason": disabled_reason,
		})
	return resolved


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
