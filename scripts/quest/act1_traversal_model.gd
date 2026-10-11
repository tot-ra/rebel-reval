class_name Act1TraversalModel
extends RefCounted

## Authored Act 1 act-boundary endings, cycle test delegation, and deliberate invalid
## transitions for P4-011.
## WHY: Act 1 gate needs one matrix that Godot traversal tests and the Python report
## tool reference without duplicating branch logic across five quest cycles.

const MANIFEST_PATH := "res://docs/data/act1_traversal_manifest.json"
const FIXTURES_MANIFEST_PATH := "res://content/saves/act1_fixtures_manifest.json"

const StGeorgesModel := preload("res://scripts/quest/st_georges_night_quest_model.gd")
const Act1AftermathModel := preload("res://scripts/quest/act1_aftermath_model.gd")

const INTENDED_BOUNDARY_ENDINGS: Array[String] = ["seal", "break", "open"]

const CYCLE_TEST_FILTERS: Array[String] = [
	"test_bell_and_chain_cycle",
	"test_bread_and_iron_cycle",
	"test_price_of_a_name_cycle",
	"test_root_and_ember_cycle",
	"test_st_georges_night_cycle",
	"test_act1_aftermath",
]

const INVALID_TRANSITIONS: Array[Dictionary] = [
	{"id": "invalid.climax.before_approach", "category": "climax_before_approach"},
	{"id": "invalid.climax.terminal_recommit", "category": "climax_terminal_recommit"},
	{"id": "invalid.climax.unknown_transition", "category": "climax_unknown_transition"},
	{"id": "invalid.act1.premature_envelope", "category": "premature_envelope"},
	{"id": "invalid.act1.record_without_flag", "category": "record_without_flag"},
]


static func load_manifest() -> Dictionary:
	var source := FileAccess.get_file_as_string(MANIFEST_PATH)
	if source.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(source)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


static func load_fixtures_manifest() -> Dictionary:
	var source := FileAccess.get_file_as_string(FIXTURES_MANIFEST_PATH)
	if source.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(source)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


static func intended_ending_ids() -> Array[String]:
	var endings: Array[String] = []
	for boundary in INTENDED_BOUNDARY_ENDINGS:
		endings.append("act_boundary:%s" % boundary)
	return endings


static func invalid_transition_ids() -> Array[String]:
	var ids: Array[String] = []
	for entry: Dictionary in INVALID_TRANSITIONS:
		ids.append(String(entry["id"]))
	return ids


static func fixture_paths() -> Array[String]:
	var manifest := load_fixtures_manifest()
	var fixtures: Variant = manifest.get("fixtures", [])
	if not fixtures is Array:
		return []
	var paths: Array[String] = []
	for entry: Variant in fixtures as Array:
		if entry is Dictionary:
			var path := String((entry as Dictionary).get("path", ""))
			if not path.is_empty():
				paths.append(path)
	return paths


static func boundary_branch_for_id(boundary: String) -> Dictionary:
	match boundary:
		"seal":
			return {
				"bias": StGeorgesModel.FLAG_SEAL_BIAS,
				"transition": StGeorgesModel.TRANSITION_COMMIT_SEAL,
				"boundary_flag": &"flag.act_boundary.viru_seal",
				"terminal_state": StGeorgesModel.STATE_AFTERMATH_SEAL,
			}
		"break":
			return {
				"bias": StGeorgesModel.FLAG_BREAK_BIAS,
				"transition": StGeorgesModel.TRANSITION_COMMIT_BREAK,
				"boundary_flag": &"flag.act_boundary.viru_break",
				"terminal_state": StGeorgesModel.STATE_AFTERMATH_BREAK,
			}
		"open":
			return {
				"bias": StGeorgesModel.FLAG_OPEN_BIAS,
				"transition": StGeorgesModel.TRANSITION_COMMIT_OPEN,
				"boundary_flag": &"flag.act_boundary.viru_open",
				"terminal_state": StGeorgesModel.STATE_AFTERMATH_OPEN,
			}
		_:
			return {}


static func build_report(reachable_endings: Array, rejected_invalid_ids: Array) -> Dictionary:
	var intended := intended_ending_ids()
	var invalid_ids := invalid_transition_ids()
	var missing_endings: Array[String] = []
	for ending_id in intended:
		if not reachable_endings.has(ending_id):
			missing_endings.append(ending_id)
	var accepted_invalid: Array[String] = []
	for invalid_id in invalid_ids:
		if not rejected_invalid_ids.has(invalid_id):
			accepted_invalid.append(invalid_id)
	return {
		"intended_endings": intended,
		"reachable_endings": reachable_endings,
		"invalid_transition_ids": invalid_ids,
		"rejected_invalid_transitions": rejected_invalid_ids,
		"missing_endings": missing_endings,
		"accepted_invalid_transitions": accepted_invalid,
		"all_intended_endings_reachable": missing_endings.is_empty(),
		"all_invalid_transitions_rejected": accepted_invalid.is_empty(),
	}


static func validate_manifest() -> Dictionary:
	var manifest := load_manifest()
	var errors: Array[String] = []
	if manifest.is_empty():
		errors.append("manifest missing or invalid")
		return {"valid": false, "errors": errors}
	if String(manifest.get("task_id", "")) != "P4-011":
		errors.append("unexpected task_id")
	if String(manifest.get("godot_model", "")) != "scripts/quest/act1_traversal_model.gd":
		errors.append("godot_model drift")
	var endings: Variant = manifest.get("intended_endings", [])
	if not endings is Array or (endings as Array).size() != INTENDED_BOUNDARY_ENDINGS.size():
		errors.append("intended_endings drift")
	var invalid_ids: Variant = manifest.get("invalid_transition_ids", [])
	if not invalid_ids is Array or (invalid_ids as Array).size() != INVALID_TRANSITIONS.size():
		errors.append("invalid_transition_ids drift")
	var filters: Variant = manifest.get("cycle_test_filters", [])
	if not filters is Array or (filters as Array).size() != CYCLE_TEST_FILTERS.size():
		errors.append("cycle_test_filters drift")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
	}
