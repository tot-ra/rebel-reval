class_name StateRuleEvaluator
extends RefCounted

## Runtime counterpart to the allowlists in schemas/common.schema.json.
## Operation dictionaries are data only: no value is ever evaluated as GDScript.

const CONDITION_OPS := [
	"always",
	"flag_is",
	"flag_not",
	"fact_known",
	"phase_is",
	"pressure_at_least",
	"relationship_at_least",
	"item_owned",
	"quest_state_is",
	"forged_modification_is",
]

const EFFECT_OPS := [
	"set_flag",
	"set_fact",
	"set_phase",
	"set_quest_state",
	"adjust_pressure",
	"adjust_relationship",
	"add_item",
	"remove_item",
	"set_location_state",
]

var _last_error := ""


func get_last_error() -> String:
	return _last_error


func evaluate_condition(condition: Dictionary, state: GameState) -> bool:
	_last_error = _validate_condition(condition, state)
	if not _last_error.is_empty():
		return false

	var op := String(condition["op"])
	var key := StringName(String(condition.get("key", "")))
	match op:
		"always":
			return true
		"flag_is":
			return state.get_flag(key) == bool(condition["value"])
		"flag_not":
			return state.get_flag(key) != bool(condition["value"])
		"fact_known":
			return state.get_fact(key)
		"phase_is":
			# Phase IDs are the allowlisted key. The generic string value is a
			# state qualifier; current authored content uses "active".
			return state.get_phase() == key and String(condition["value"]) == "active"
		"pressure_at_least":
			return state.get_pressure(key) >= int(condition["amount"])
		"relationship_at_least":
			return state.get_relationship(key) >= int(condition["amount"])
		"item_owned":
			return state.has_item(key)
		"quest_state_is":
			return state.get_quest_state(key) == StringName(String(condition["value"]))
		"forged_modification_is":
			return state.has_forged_modification(key, StringName(String(condition["value"])))
	return false


func evaluate_conditions(conditions: Array, state: GameState) -> bool:
	_last_error = ""
	if state == null:
		_last_error = "conditions require a GameState"
		return false

	# Validate every condition before short-circuiting on a legitimate false
	# result, so an unsupported expression cannot hide later in the list.
	for index in conditions.size():
		var value: Variant = conditions[index]
		if typeof(value) != TYPE_DICTIONARY:
			_last_error = "condition %d must be a dictionary" % index
			return false
		var error := _validate_condition(value as Dictionary, state)
		if not error.is_empty():
			_last_error = "condition %d: %s" % [index, error]
			return false

	for condition in conditions:
		if not evaluate_condition(condition as Dictionary, state):
			return false
	return true


func apply_effect(effect: Dictionary, state: GameState) -> bool:
	_last_error = _validate_effect(effect, state)
	if not _last_error.is_empty():
		return false
	_apply_valid_effect(effect, state)
	return true


func apply_effects(effects: Array, state: GameState) -> bool:
	_last_error = ""
	if state == null:
		_last_error = "effects require a GameState"
		return false

	# Validate the complete batch first. Invalid authored data must not leave a
	# partially mutated state when an earlier effect happened to be valid.
	for index in effects.size():
		var value: Variant = effects[index]
		if typeof(value) != TYPE_DICTIONARY:
			_last_error = "effect %d must be a dictionary" % index
			return false
		var error := _validate_effect(value as Dictionary, state)
		if not error.is_empty():
			_last_error = "effect %d: %s" % [index, error]
			return false

	for effect in effects:
		_apply_valid_effect(effect as Dictionary, state)
	return true


func _apply_valid_effect(effect: Dictionary, state: GameState) -> void:
	var op := String(effect["op"])
	var key := StringName(String(effect["key"]))
	match op:
		"set_flag":
			state.set_flag(key, bool(effect["value"]))
		"set_fact":
			state.set_fact(key, bool(effect["value"]))
		"set_phase":
			state.set_phase(key)
		"set_quest_state":
			state.set_quest_state(key, StringName(String(effect["value"])))
		"adjust_pressure":
			state.adjust_pressure(key, int(effect["amount"]))
		"adjust_relationship":
			state.adjust_relationship(key, int(effect["amount"]))
		"add_item":
			state.add_item(key)
		"remove_item":
			state.remove_item(key)
		"set_location_state":
			state.set_location_state(key, StringName(String(effect["value"])))


func _validate_condition(condition: Dictionary, state: GameState) -> String:
	if state == null:
		return "condition requires a GameState"
	if not _has_string(condition, "op"):
		return "condition requires a string op"

	var op := String(condition["op"])
	if not CONDITION_OPS.has(op):
		return "unsupported condition op: %s" % op
	match op:
		"always":
			return _require_shape(condition, ["op"])
		"flag_is", "flag_not":
			return _validate_key_value(condition, "flag.", TYPE_BOOL)
		"fact_known":
			return _validate_key_only(condition, "fact.")
		"phase_is":
			return _validate_key_value(condition, "phase.", TYPE_STRING)
		"pressure_at_least":
			return _validate_key_amount(condition, "pressure.", 0, 3)
		"relationship_at_least":
			return _validate_key_amount(condition, "rel.", 0, 3)
		"item_owned":
			return _validate_key_only(condition, "item.")
		"quest_state_is":
			return _validate_key_value(condition, "quest.", TYPE_STRING)
		"forged_modification_is":
			return _validate_forged_modification(condition)
	return "unsupported condition op: %s" % op


func _validate_forged_modification(condition: Dictionary) -> String:
	var shape_error := _require_shape(condition, ["op", "key", "value"])
	if not shape_error.is_empty():
		return shape_error
	var key_error := _validate_key(condition, "commission.")
	if not key_error.is_empty():
		return key_error
	if typeof(condition["value"]) != TYPE_STRING or String(condition["value"]).is_empty():
		return "forged_modification_is value must be a non-empty modification id"
	return ""


func _validate_effect(effect: Dictionary, state: GameState) -> String:
	if state == null:
		return "effect requires a GameState"
	if not _has_string(effect, "op"):
		return "effect requires a string op"

	var op := String(effect["op"])
	if not EFFECT_OPS.has(op):
		return "unsupported effect op: %s" % op
	match op:
		"set_flag":
			return _validate_key_value(effect, "flag.", TYPE_BOOL)
		"set_fact":
			return _validate_key_value(effect, "fact.", TYPE_BOOL)
		"set_phase":
			return _validate_key_value(effect, "phase.", TYPE_STRING)
		"set_quest_state":
			return _validate_key_value(effect, "quest.", TYPE_STRING)
		"adjust_pressure":
			return _validate_key_amount(effect, "pressure.", -3, 3)
		"adjust_relationship":
			return _validate_key_amount(effect, "rel.", -3, 3)
		"add_item", "remove_item":
			return _validate_key_only(effect, "item.")
		"set_location_state":
			return _validate_key_value(effect, "loc.", TYPE_STRING)
	return "unsupported effect op: %s" % op


func _validate_key_only(operation: Dictionary, prefix: String) -> String:
	var shape_error := _require_shape(operation, ["op", "key"])
	if not shape_error.is_empty():
		return shape_error
	return _validate_key(operation, prefix)


func _validate_key_value(operation: Dictionary, prefix: String, value_type: int) -> String:
	var shape_error := _require_shape(operation, ["op", "key", "value"])
	if not shape_error.is_empty():
		return shape_error
	var key_error := _validate_key(operation, prefix)
	if not key_error.is_empty():
		return key_error
	if typeof(operation["value"]) != value_type:
		return "%s value has the wrong type" % String(operation["op"])
	return ""


func _validate_key_amount(
	operation: Dictionary,
	prefix: String,
	minimum: int,
	maximum: int
) -> String:
	var shape_error := _require_shape(operation, ["op", "key", "amount"])
	if not shape_error.is_empty():
		return shape_error
	var key_error := _validate_key(operation, prefix)
	if not key_error.is_empty():
		return key_error
	if typeof(operation["amount"]) != TYPE_INT:
		return "%s amount must be an integer" % String(operation["op"])
	var amount := int(operation["amount"])
	if amount < minimum or amount > maximum:
		return "%s amount must be between %d and %d" % [String(operation["op"]), minimum, maximum]
	return ""


func _validate_key(operation: Dictionary, prefix: String) -> String:
	if not _has_string(operation, "key"):
		return "%s requires a string key" % String(operation["op"])
	var key := String(operation["key"])
	if not key.begins_with(prefix) or key.length() == prefix.length():
		return "%s key must use the %s namespace" % [String(operation["op"]), prefix]
	return ""


func _require_shape(operation: Dictionary, required_keys: Array[String]) -> String:
	if operation.size() != required_keys.size():
		return "%s contains missing or unsupported fields" % String(operation.get("op", "operation"))
	for key in required_keys:
		if not operation.has(key):
			return "%s requires %s" % [String(operation.get("op", "operation")), key]
	return ""


func _has_string(value: Dictionary, key: String) -> bool:
	return value.has(key) and typeof(value[key]) == TYPE_STRING and not String(value[key]).is_empty()
