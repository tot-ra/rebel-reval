class_name DialogueEntryResolver
extends RefCounted

## Picks a dialogue entry node from optional authored entry_variants before start_node_id.


static func resolve_entry_node_id(
	dialogue: Dictionary, state: GameState, evaluator: StateRuleEvaluator
) -> String:
	var variants: Variant = dialogue.get("entry_variants", [])
	if typeof(variants) != TYPE_ARRAY or (variants as Array).is_empty():
		return ""

	var ranked: Array = (variants as Array).duplicate()
	ranked.sort_custom(
		func(a: Variant, b: Variant) -> bool:
			var priority_a := int((a as Dictionary).get("priority", 0)) if a is Dictionary else 0
			var priority_b := int((b as Dictionary).get("priority", 0)) if b is Dictionary else 0
			return priority_a > priority_b
	)

	for variant_value: Variant in ranked:
		if typeof(variant_value) != TYPE_DICTIONARY:
			continue
		var variant := variant_value as Dictionary
		var node_id := String(variant.get("node_id", ""))
		if node_id.is_empty():
			continue
		var conditions: Array = variant.get("conditions", [])
		if (
			conditions.is_empty()
			or evaluator.evaluate_conditions(_runtime_rules(conditions), state)
		):
			return node_id
	return ""


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
