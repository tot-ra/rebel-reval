class_name ForgeCommissionRunner
extends Node

## Content-driven forge commission flow: snapshot display and forging-option resolution.

signal started(commission_id: StringName)
signal finished(commission_id: StringName)
signal option_selected(commission_id: StringName, option_id: String)

enum Result {
	OK,
	INVALID_DEPENDENCIES,
	UNKNOWN_COMMISSION,
	ALREADY_RESOLVED,
	UNKNOWN_OPTION,
	OPTION_LOCKED,
	EFFECTS_REJECTED,
}

var _content_db: ContentDB
var _state: GameState
var _evaluator: StateRuleEvaluator
var _presenter: RefCounted
var _commission_id := &""
var _snapshot: Dictionary = {}
var _active := false
var _last_result := Result.OK
var _last_error := ""


func configure(
	content_db: ContentDB,
	state: GameState,
	presenter: RefCounted,
	evaluator: StateRuleEvaluator = null
) -> void:
	_content_db = content_db
	_state = state
	_presenter = presenter
	_evaluator = evaluator if evaluator != null else StateRuleEvaluator.new()


func is_active() -> bool:
	return _active


func get_commission_id() -> StringName:
	return _commission_id


func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func get_last_result() -> Result:
	return _last_result


func get_last_error() -> String:
	return _last_error


func open(commission_id: StringName) -> bool:
	_reset_result()
	if _content_db == null or _state == null or _presenter == null:
		return _fail(Result.INVALID_DEPENDENCIES, "ForgeCommissionRunner requires ContentDB, GameState, and presenter")

	var commission := _content_db.get_commission(commission_id)
	if commission.is_empty():
		return _fail(Result.UNKNOWN_COMMISSION, "commission record was not found: %s" % commission_id)

	_snapshot = ForgeCommissionModel.build_snapshot(commission_id, _state, _content_db, _evaluator)
	if _snapshot.is_empty() or String(_snapshot.get("title", "")).is_empty():
		return _fail(Result.UNKNOWN_COMMISSION, "commission snapshot is empty: %s" % commission_id)

	_commission_id = commission_id
	_active = true
	started.emit(commission_id)
	_presenter.present_commission(_snapshot)
	return true


func select_option(option_id: String) -> bool:
	_reset_result()
	if not _active or option_id.is_empty():
		return false

	if ForgeCommissionModel.is_commission_resolved(_state, _commission_id):
		return _fail(Result.ALREADY_RESOLVED, "commission %s is already resolved" % _commission_id)

	var commission := _content_db.get_commission(_commission_id)
	var selected := _find_forging_option(commission, option_id)
	if selected.is_empty():
		return _fail(Result.UNKNOWN_OPTION, "commission %s has no option %s" % [_commission_id, option_id])

	var requires: Array = selected.get("requires", [])
	if not requires.is_empty() \
			and not _evaluator.evaluate_conditions(_runtime_rules(requires), _state):
		return _fail(Result.OPTION_LOCKED, "option %s is locked for commission %s" % [option_id, _commission_id])

	var effects: Array = selected.get("effects", [])
	if not effects.is_empty() and not _evaluator.apply_effects(_runtime_rules(effects), _state):
		return _fail(Result.EFFECTS_REJECTED, _evaluator.get_last_error())

	var object_item_id := StringName(String(commission.get("object_item_id", "")))
	var record := ForgedRecord.new(
		ForgeCommissionModel.record_id_for(_commission_id, option_id),
		_commission_id,
		object_item_id,
		StringName(option_id)
	)
	if not _state.add_forged_record(record):
		return _fail(Result.ALREADY_RESOLVED, "forged record already exists for commission %s" % _commission_id)

	option_selected.emit(_commission_id, option_id)
	_close()
	return true


func cancel() -> void:
	if not _active:
		return
	_close()


func _find_forging_option(commission: Dictionary, option_id: String) -> Dictionary:
	for option_value in commission.get("forging_options", []) as Array:
		if typeof(option_value) != TYPE_DICTIONARY:
			continue
		var option := option_value as Dictionary
		if String(option.get("id", "")) == option_id:
			return option
	return {}


func _close() -> void:
	var finished_id := _commission_id
	_active = false
	_commission_id = &""
	_snapshot = {}
	if _presenter != null:
		_presenter.close()
	finished.emit(finished_id)


func _runtime_rules(authored_rules: Variant) -> Array:
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


func _reset_result() -> void:
	_last_result = Result.OK
	_last_error = ""


func _fail(result: Result, message: String) -> bool:
	_last_result = result
	_last_error = message
	return false
