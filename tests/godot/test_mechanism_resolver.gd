extends "res://tests/godot/test_case.gd"

const VALID_DIR := "res://content/examples/valid"
const SUPPORT_DIR := "res://content/examples/support"

const MECHANISM_ID := &"mechanism.watch_buckle_restraint"
const COMMISSION_ID := &"commission.watch_buckle_repair"
const OBJECT_ID := &"item.watch_buckle"
const RECORD_HONEST := &"forged.watch_buckle_repair.honest_work"
const RECORD_SUBTLE := &"forged.watch_buckle_repair.subtle_defect"
const RECORD_SECRET := &"forged.watch_buckle_repair.secret_feature"
const FLAG_HOLD := &"flag.watch_buckle_tested_hold"
const FLAG_FAIL := &"flag.watch_buckle_tested_fail"
const FLAG_RELEASE := &"flag.watch_buckle_tested_release"
const REL_HENNING := &"rel.henning_trust"

const MODEL_SCRIPT := preload("res://scripts/mechanism/mechanism_model.gd")

var db: ContentDB
var state: GameState
var evaluator: StateRuleEvaluator
var resolver: MechanismResolver


func before_each() -> void:
	db = ContentDB.new()
	assert_true(db.load_from_directories([VALID_DIR, SUPPORT_DIR]))
	state = GameState.new()
	evaluator = StateRuleEvaluator.new()
	resolver = MechanismResolver.new(db, state, evaluator)


func _add_record(record_id: StringName, modification_id: StringName) -> void:
	state.add_forged_record(
		ForgedRecord.new(record_id, COMMISSION_ID, OBJECT_ID, modification_id)
	)


func test_unresolved_mechanism_uses_default_response() -> void:
	var snapshot := resolver.resolve(MECHANISM_ID)

	assert_eq(resolver.get_last_result(), MechanismResolver.Result.OK)
	assert_eq(snapshot["behavior"], "idle")
	assert_eq(String(snapshot["response_id"]), "unresolved")
	assert_true(String(snapshot["summary"]).contains("not been forged"))


func test_honest_modification_resolves_to_hold_behavior() -> void:
	_add_record(RECORD_HONEST, &"honest_work")

	var snapshot := resolver.resolve(MECHANISM_ID)

	assert_eq(snapshot["behavior"], "hold")
	assert_eq(String(snapshot["response_id"]), "holds")


func test_subtle_defect_resolves_to_fail_behavior() -> void:
	_add_record(RECORD_SUBTLE, &"subtle_defect")

	var snapshot := resolver.resolve(MECHANISM_ID)

	assert_eq(snapshot["behavior"], "fail")
	assert_eq(String(snapshot["response_id"]), "snaps")


func test_secret_feature_resolves_to_release_behavior() -> void:
	_add_record(RECORD_SECRET, &"secret_feature")

	var snapshot := resolver.resolve(MECHANISM_ID)

	assert_eq(snapshot["behavior"], "release")
	assert_eq(String(snapshot["response_id"]), "releases")


func test_trigger_applies_authored_effects_without_quest_code() -> void:
	_add_record(RECORD_SUBTLE, &"subtle_defect")

	assert_true(resolver.trigger(MECHANISM_ID))
	assert_true(state.get_flag(FLAG_FAIL))
	assert_eq(state.get_relationship(REL_HENNING), -1)


func test_alternate_content_definition_changes_behavior_without_resolver_changes() -> void:
	_add_record(RECORD_HONEST, &"honest_work")

	var authored := db.get_mechanism(MECHANISM_ID)
	var snapshot := resolver.resolve(MECHANISM_ID)
	assert_eq(snapshot["behavior"], "hold")

	var alternate := authored.duplicate(true)
	var responses: Array = alternate["responses"]
	responses.clear()
	responses.append({
		"id": "custom_hold",
		"behavior": "engage",
		"summary": "Fixture-only engage response.",
		"requires": [
			{
				"op": "forged_modification_is",
				"key": String(COMMISSION_ID),
				"value": "honest_work",
			}
		],
	})
	alternate["responses"] = responses
	alternate["default_response"] = {
		"id": "custom_idle",
		"behavior": "idle",
		"summary": "Fixture idle fallback.",
	}

	var alternate_response: Dictionary = MODEL_SCRIPT._resolve_response(alternate, state, evaluator)
	assert_eq(String(alternate_response["behavior"]), "engage")
	assert_eq(String(alternate_response["id"]), "custom_hold")
