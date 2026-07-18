class_name MechanismResolver
extends RefCounted

## Resolves authored mechanism responses from forged records and applies their effects.

const MODEL_SCRIPT := preload("res://scripts/mechanism/mechanism_model.gd")

enum Result {
	OK,
	INVALID_DEPENDENCIES,
	UNKNOWN_MECHANISM,
	INVALID_MECHANISM_RECORD,
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


func resolve(mechanism_id: StringName) -> Dictionary:
	_reset_result()
	var mechanism := _load_valid_mechanism(mechanism_id)
	if mechanism.is_empty():
		return {}
	return MODEL_SCRIPT.build_snapshot(mechanism_id, _state, _content_db, _evaluator)


func trigger(mechanism_id: StringName) -> bool:
	_reset_result()
	var snapshot := resolve(mechanism_id)
	if snapshot.is_empty():
		return false

	var effects: Array = snapshot.get("effects", [])
	if effects.is_empty():
		return true
	if not _evaluator.apply_effects(effects, _state):
		_fail(
			Result.EFFECTS_REJECTED,
			"mechanism %s effects were rejected: %s" % [mechanism_id, _evaluator.get_last_error()]
		)
		return false
	return true


func _load_valid_mechanism(mechanism_id: StringName) -> Dictionary:
	if _content_db == null or _state == null or _evaluator == null:
		_fail(Result.INVALID_DEPENDENCIES, "MechanismResolver requires ContentDB, GameState, and StateRuleEvaluator")
		return {}
	if not _content_db.is_loaded():
		return _fail(Result.INVALID_DEPENDENCIES, "ContentDB is not loaded")
	var mechanism := _content_db.get_mechanism(mechanism_id)
	if mechanism.is_empty():
		return _fail(Result.UNKNOWN_MECHANISM, "unknown mechanism %s" % mechanism_id)
	if mechanism.get("responses", []).is_empty():
		return _fail(Result.INVALID_MECHANISM_RECORD, "mechanism %s has no responses" % mechanism_id)
	var default_response: Variant = mechanism.get("default_response", {})
	if typeof(default_response) != TYPE_DICTIONARY or String((default_response as Dictionary).get("id", "")).is_empty():
		return _fail(Result.INVALID_MECHANISM_RECORD, "mechanism %s is missing default_response" % mechanism_id)
	return mechanism


func _reset_result() -> void:
	_last_result = Result.OK
	_last_error = ""


func _fail(result: Result, message: String) -> Dictionary:
	_last_result = result
	_last_error = message
	return {}
