class_name DebugStatePresets
extends RefCounted

## Loads authored debug presets and applies deterministic GameState jumps for
## slice phase and branch testing (P1-009). Presets never mutate save files.

const MANIFEST_PATH := "res://content/debug/debug_state_presets.json"

enum Result {
	OK,
	MANIFEST_MISSING,
	MANIFEST_INVALID,
	UNKNOWN_PRESET,
	FIXTURE_LOAD_FAILED,
	STATE_APPLY_FAILED,
}

var _presets_by_id: Dictionary = {}
var _ordered_ids: Array[String] = []
var _evaluator: StateRuleEvaluator = StateRuleEvaluator.new()
var _last_result := Result.OK
var _last_error := ""


func load_manifest() -> bool:
	_presets_by_id.clear()
	_ordered_ids.clear()
	_last_result = Result.OK
	_last_error = ""

	if not FileAccess.file_exists(MANIFEST_PATH):
		return _fail(Result.MANIFEST_MISSING, "debug preset manifest not found: %s" % MANIFEST_PATH)

	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return _fail(Result.MANIFEST_INVALID, "could not open debug preset manifest")

	var parsed := JSON.new()
	if parsed.parse(file.get_as_text()) != OK:
		file.close()
		return _fail(Result.MANIFEST_INVALID, "invalid JSON in debug preset manifest")
	file.close()

	var root: Variant = parsed.data
	if not root is Dictionary:
		return _fail(Result.MANIFEST_INVALID, "debug preset manifest root must be an object")

	var presets: Variant = (root as Dictionary).get("presets", [])
	if not presets is Array:
		return _fail(Result.MANIFEST_INVALID, "debug preset manifest requires presets array")

	var seen: Dictionary = {}
	for index in (presets as Array).size():
		var value: Variant = presets[index]
		if not value is Dictionary:
			return _fail(Result.MANIFEST_INVALID, "preset %d must be an object" % index)
		var preset := value as Dictionary
		var preset_id := String(preset.get("id", ""))
		if preset_id.is_empty():
			return _fail(Result.MANIFEST_INVALID, "preset %d is missing id" % index)
		if seen.has(preset_id):
			return _fail(Result.MANIFEST_INVALID, "duplicate debug preset id %s" % preset_id)
		if not preset.has("fixture") and not preset.has("game_state"):
			return _fail(
				Result.MANIFEST_INVALID,
				"preset %s requires fixture or game_state" % preset_id
			)
		seen[preset_id] = true
		_presets_by_id[preset_id] = preset.duplicate(true)
		_ordered_ids.append(preset_id)

	return true


func get_preset_ids() -> Array[String]:
	return _ordered_ids.duplicate()


func get_preset(preset_id: String) -> Dictionary:
	return (_presets_by_id.get(preset_id, {}) as Dictionary).duplicate(true)


func preset_ids_for_category(category: String) -> Array[String]:
	var ids: Array[String] = []
	for preset_id in _ordered_ids:
		var preset: Dictionary = _presets_by_id[preset_id]
		if String(preset.get("category", "")) == category:
			ids.append(preset_id)
	return ids


func get_last_result() -> Result:
	return _last_result


func get_last_error() -> String:
	return _last_error


func apply_preset(preset_id: String) -> Dictionary:
	_reset_result()
	if _presets_by_id.is_empty() and not load_manifest():
		return _result_dict(null)

	var preset: Dictionary = _presets_by_id.get(preset_id, {})
	if preset.is_empty():
		_fail(Result.UNKNOWN_PRESET, "unknown debug preset %s" % preset_id)
		return _result_dict(null)

	var state := _load_base_state(preset)
	if state == null:
		return _result_dict(null)

	var phase_override := String(preset.get("phase", ""))
	if not phase_override.is_empty():
		state.set_phase(StringName(phase_override))

	var effects: Variant = preset.get("effects", [])
	if effects is Array and not (effects as Array).is_empty():
		if not _evaluator.apply_effects(_runtime_rules(effects), state):
			_fail(
				Result.STATE_APPLY_FAILED,
				"preset %s effects rejected: %s" % [preset_id, _evaluator.get_last_error()]
			)
			return _result_dict(null)

	return _result_dict(state)


func slice_phase_preset_ids() -> Array[String]:
	return preset_ids_for_category("phase")


func branch_preset_ids() -> Array[String]:
	return preset_ids_for_category("branch")


func _load_base_state(preset: Dictionary) -> GameState:
	if preset.has("game_state"):
		var payload: Variant = preset["game_state"]
		if not payload is Dictionary:
			_fail(Result.MANIFEST_INVALID, "preset game_state must be an object")
			return null
		var state := GameState.new()
		var errors := state.load_payload(payload as Dictionary)
		if not errors.is_empty():
			_fail(Result.STATE_APPLY_FAILED, ", ".join(errors))
			return null
		return state

	var fixture := String(preset.get("fixture", ""))
	if fixture.is_empty():
		_fail(Result.MANIFEST_INVALID, "preset %s has no fixture" % String(preset.get("id", "")))
		return null

	var parsed := SaveEnvelope.parse_file(SaveEnvelope.released_fixture_path(fixture))
	if not parsed["ok"]:
		_fail(
			Result.FIXTURE_LOAD_FAILED,
			"fixture %s failed: %s" % [fixture, ", ".join(parsed["errors"])]
		)
		return null
	return parsed["state"] as GameState


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


func _result_dict(state: GameState) -> Dictionary:
	return {
		"ok": _last_result == Result.OK and state != null,
		"state": state,
		"error": _last_error,
		"result": _last_result,
	}


func _reset_result() -> void:
	_last_result = Result.OK
	_last_error = ""


func _fail(result: Result, message: String) -> bool:
	_last_result = result
	_last_error = message
	return false
