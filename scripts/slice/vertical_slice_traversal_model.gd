class_name VerticalSliceTraversalModel
extends RefCounted

## Authored valid endings and deliberate invalid transitions for P3-001.
## WHY: slice validation needs one matrix that both Godot traversal tests and the
## Python report tool can reference without duplicating branch logic.

const FlowModel := preload("res://scripts/slice/vertical_slice_flow_model.gd")
const AftermathModel := preload("res://scripts/investigation/bitter_brew_aftermath_model.gd")
const ReflectionModel := preload("res://scripts/reflection/reflection_model.gd")

const RECORD_HONEST := FlowModel.RECORD_HONEST
const RECORD_SUBTLE := FlowModel.RECORD_SUBTLE
const RECORD_SECRET := FlowModel.RECORD_SECRET

const INVALID_NIGHT_ROUTE_PAIRS: Array[Dictionary] = [
	{
		"id": "invalid.night.honest_bypass",
		"record_id": RECORD_HONEST,
		"route": EncounterOutcome.KIND_BYPASS,
	},
	{
		"id": "invalid.night.honest_escape",
		"record_id": RECORD_HONEST,
		"route": EncounterOutcome.KIND_ESCAPE,
	},
	{
		"id": "invalid.night.subtle_escape",
		"record_id": RECORD_SUBTLE,
		"route": EncounterOutcome.KIND_ESCAPE,
	},
	{
		"id": "invalid.night.secret_bypass",
		"record_id": RECORD_SECRET,
		"route": EncounterOutcome.KIND_BYPASS,
	},
]

const INVALID_STATIC_CASES: Array[Dictionary] = [
	{"id": "invalid.aftermath.premature", "category": "aftermath_premature"},
	{"id": "invalid.reflection.wrong_phase", "category": "reflection_wrong_phase"},
	{"id": "invalid.encounter.unknown_kind", "category": "unknown_encounter"},
	{"id": "invalid.investigation.wrong_phase", "category": "investigation_wrong_phase"},
	{"id": "invalid.commission.before_investigation_ready", "category": "commission_before_ready"},
]


static func intended_ending_ids() -> Array[String]:
	var endings: Array[String] = []
	for branch: Dictionary in FlowModel.BRANCHES:
		var branch_id := String(branch["id"])
		var aftermath := String(branch["aftermath_outcome"])
		endings.append("%s:%s" % [branch_id, aftermath])
	return endings


static func invalid_transition_ids() -> Array[String]:
	var ids: Array[String] = []
	for entry: Dictionary in INVALID_NIGHT_ROUTE_PAIRS:
		ids.append(String(entry["id"]))
	for entry: Dictionary in INVALID_STATIC_CASES:
		ids.append(String(entry["id"]))
	return ids


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
		"rejected_invalid_transition_ids": rejected_invalid_ids,
		"missing_endings": missing_endings,
		"accepted_invalid_transitions": accepted_invalid,
		"all_intended_endings_reachable": missing_endings.is_empty(),
		"all_invalid_transitions_rejected": accepted_invalid.is_empty(),
	}
