extends "res://tests/godot/test_case.gd"

const VALID_DIR := "res://content/examples/valid"
const SUPPORT_DIR := "res://content/examples/support"
const RunnerScript := preload("res://scripts/forge/forge_commission_runner.gd")
const PresenterScript := preload("res://scripts/forge/forge_commission_presenter.gd")

const COMMISSION_ID := &"commission.watch_buckle_repair"
const CLIENT_ID := &"char.henning"
const OBJECT_ID := &"item.watch_buckle"
const RECORD_HONEST := &"forged.watch_buckle_repair.honest_work"
const FACT_SPEARHEAD := &"fact.seized_spearhead_seen"
const FACT_REJECTS := &"fact.rejected_blanks_missing"
const REL_HENNING_TRUST := &"rel.henning_trust"

var db: ContentDB
var state: GameState


func before_each() -> void:
	db = ContentDB.new()
	assert_true(db.load_from_directories([VALID_DIR, SUPPORT_DIR]))
	state = GameState.new()


func test_snapshot_exposes_commission_fields() -> void:
	var snapshot := ForgeCommissionModel.build_snapshot(COMMISSION_ID, state, db)
	assert_eq(snapshot.get("customer_name", ""), "Henning")
	assert_eq(snapshot.get("customer_id", &""), CLIENT_ID)
	assert_eq(snapshot.get("object_name", ""), "Watchman's buckle")
	assert_eq(snapshot.get("object_item_id", &""), OBJECT_ID)
	assert_true(String(snapshot.get("known_purpose", "")).contains("buckle"))
	assert_eq(snapshot.get("materials", ""), "Common iron")
	assert_eq((snapshot.get("discovered_leverage", []) as Array).size(), 0)


func test_discovered_leverage_appears_when_facts_are_known() -> void:
	state.set_fact(FACT_SPEARHEAD, true)
	var snapshot := ForgeCommissionModel.build_snapshot(COMMISSION_ID, state, db)
	var leverage: Array = snapshot.get("discovered_leverage", [])
	assert_eq(leverage.size(), 1)
	assert_true(String(leverage[0]).contains("spearhead"))

	state.set_fact(FACT_REJECTS, true)
	snapshot = ForgeCommissionModel.build_snapshot(COMMISSION_ID, state, db)
	leverage = snapshot.get("discovered_leverage", [])
	assert_eq(leverage.size(), 3)
	assert_true(String(leverage[2]).contains("rebel-marked iron"))


func test_runner_opens_content_defined_commission() -> void:
	var setup := _make_runner_setup()
	assert_true(setup.runner.open(COMMISSION_ID))
	assert_true(setup.runner.is_active())
	assert_eq(setup.presenter.last_snapshot.get("customer_name", ""), "Henning")
	assert_eq((setup.presenter.last_snapshot.get("forging_options", []) as Array).size(), 2)
	_cleanup_setup(setup)


func test_selecting_honest_work_creates_forged_record_and_applies_effects() -> void:
	var setup := _make_runner_setup()
	assert_true(setup.runner.open(COMMISSION_ID))
	assert_true(setup.runner.select_option("honest_work"))
	assert_false(setup.runner.is_active())
	assert_true(state.has_forged_record(RECORD_HONEST))
	assert_eq(state.get_relationship(REL_HENNING_TRUST), 1)

	var record := state.get_forged_record(RECORD_HONEST)
	assert_eq(record.commission_id, COMMISSION_ID)
	assert_eq(record.item_id, OBJECT_ID)
	assert_eq(record.modification_id, &"honest_work")
	_cleanup_setup(setup)


func test_resolved_commission_cannot_be_forged_again() -> void:
	var setup := _make_runner_setup()
	assert_true(setup.runner.open(COMMISSION_ID))
	assert_true(setup.runner.select_option("honest_work"))
	assert_true(setup.runner.open(COMMISSION_ID))
	assert_false(setup.runner.select_option("subtle_defect"))
	assert_eq(setup.runner.get_last_result(), RunnerScript.Result.ALREADY_RESOLVED)
	_cleanup_setup(setup)


func test_record_id_matches_save_fixture_contract() -> void:
	assert_eq(
		ForgeCommissionModel.record_id_for(COMMISSION_ID, "honest_work"),
		RECORD_HONEST
	)


func _make_runner_setup() -> Dictionary:
	var presenter := _RecordingPresenter.new()
	var runner := RunnerScript.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(runner)
	runner.configure(db, state, presenter)
	return {"runner": runner, "presenter": presenter}


func _cleanup_setup(setup: Dictionary) -> void:
	var runner: Node = setup.get("runner")
	if runner != null and is_instance_valid(runner):
		runner.queue_free()


class _RecordingPresenter extends PresenterScript:
	var last_snapshot: Dictionary = {}

	func present_commission(snapshot: Dictionary) -> void:
		last_snapshot = snapshot.duplicate(true)

	func close() -> void:
		last_snapshot = {}
