extends "res://tests/godot/test_case.gd"

const CommissionDeadlineModelScript := preload("res://scripts/commission/commission_deadline_model.gd")

const VALID_DIR := "res://content/examples/valid"
const SUPPORT_DIR := "res://content/examples/support"

const COMMISSION_WATCH := &"commission.watch_buckle_repair"
const COMMISSION_LANTERN := &"commission.lantern_hook_rush"
const REL_HENNING := &"rel.henning_trust"
const REL_MART := &"rel.mart_trust"
const PHASE_PROLOGUE := &"phase.prologue_day"
const PHASE_MORNING := &"phase.investigation_morning"
const FLAG_WATCH_MISSED := &"flag.watch_buckle_deadline_missed"
const FLAG_LANTERN_BONUS := &"flag.lantern_hook_on_time_bonus"
const FLAG_LANTERN_DEFECT := &"flag.lantern_hook_rushed_defect"

var db: ContentDB
var state: GameState
var evaluator: StateRuleEvaluator


func before_each() -> void:
	db = ContentDB.new()
	assert_true(db.load_from_directories([VALID_DIR, SUPPORT_DIR]))
	SessionState.content_db = db
	state = GameState.new()
	evaluator = StateRuleEvaluator.new()
	state.set_phase(PHASE_PROLOGUE)


func test_watch_buckle_met_before_deadline_preserves_trust() -> void:
	_complete_commission(COMMISSION_WATCH, "honest_work")
	CommissionDeadlineModelScript.sync_on_phase_change(state, db, PHASE_PROLOGUE, PHASE_MORNING, evaluator)

	assert_true(CommissionDeadlineModelScript.is_deadline_met(state, COMMISSION_WATCH))
	assert_false(state.get_flag(FLAG_WATCH_MISSED))
	assert_eq(state.get_relationship(REL_HENNING), 1)


func test_watch_buckle_missed_deadline_applies_penalty() -> void:
	CommissionDeadlineModelScript.sync_on_phase_change(state, db, PHASE_PROLOGUE, PHASE_MORNING, evaluator)

	assert_true(CommissionDeadlineModelScript.is_deadline_missed(state, COMMISSION_WATCH))
	assert_true(state.get_flag(FLAG_WATCH_MISSED))
	assert_eq(state.get_relationship(REL_HENNING), -1)


func test_lantern_hook_on_time_unlocks_bonus_outcome() -> void:
	_complete_commission(COMMISSION_LANTERN, "secret_feature")
	CommissionDeadlineModelScript.sync_on_phase_change(state, db, PHASE_PROLOGUE, PHASE_MORNING, evaluator)

	assert_true(CommissionDeadlineModelScript.is_deadline_met(state, COMMISSION_LANTERN))
	assert_true(state.get_flag(FLAG_LANTERN_BONUS))
	assert_eq(state.get_relationship(REL_MART), 2)
	assert_false(state.get_flag(FLAG_LANTERN_DEFECT))


func test_lantern_hook_late_completion_keeps_missed_penalty_and_defect_route() -> void:
	CommissionDeadlineModelScript.sync_on_phase_change(state, db, PHASE_PROLOGUE, PHASE_MORNING, evaluator)
	assert_eq(state.get_relationship(REL_MART), -1)

	var defect := _find_option(COMMISSION_LANTERN, "subtle_defect")
	assert_false(defect.is_empty())
	assert_true(evaluator.evaluate_conditions(defect.get("requires", []), state))
	evaluator.apply_effects(defect.get("effects", []), state)
	_complete_commission(COMMISSION_LANTERN, "subtle_defect")

	assert_true(CommissionDeadlineModelScript.is_deadline_missed(state, COMMISSION_LANTERN))
	assert_true(state.get_flag(FLAG_LANTERN_DEFECT))
	assert_eq(state.get_relationship(REL_MART), -1)


func test_deadline_state_survives_save_round_trip() -> void:
	CommissionDeadlineModelScript.sync_on_phase_change(state, db, PHASE_PROLOGUE, PHASE_MORNING, evaluator)
	assert_true(CommissionDeadlineModelScript.is_deadline_missed(state, COMMISSION_WATCH))

	var payload := state.save_payload()
	var restored := GameState.new()
	assert_eq(restored.load_payload(payload).size(), 0)
	assert_true(CommissionDeadlineModelScript.is_deadline_missed(restored, COMMISSION_WATCH))


func test_journal_lists_active_commission_deadlines() -> void:
	var snapshot := JournalModel.build_snapshot(state, db)
	var deadlines: Array = snapshot.get("commission_deadlines", [])
	assert_true(deadlines.size() >= 2)
	var titles: Array[String] = []
	for entry in deadlines:
		titles.append(String((entry as Dictionary).get("title", "")))
	assert_true(titles.has("Repair the watchman's buckle"))
	assert_true(titles.has("Rush the lantern hook"))


func _complete_commission(commission_id: StringName, option_id: String) -> void:
	var option := _find_option(commission_id, option_id)
	assert_false(option.is_empty())
	CommissionDeadlineModelScript.mark_commission_met_if_timely(state, commission_id, db)
	var requires: Array = option.get("requires", [])
	if not requires.is_empty():
		assert_true(evaluator.evaluate_conditions(_runtime_rules(requires), state))
	assert_true(evaluator.apply_effects(_runtime_rules(option.get("effects", [])), state))
	var commission := db.get_commission(commission_id)
	var record := ForgedRecord.new(
		ForgeCommissionModel.record_id_for(commission_id, option_id),
		commission_id,
		StringName(String(commission.get("object_item_id", ""))),
		StringName(option_id)
	)
	assert_true(state.add_forged_record(record))
	CommissionDeadlineModelScript.mark_commission_met(state, commission_id, db)


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


func _find_option(commission_id: StringName, option_id: String) -> Dictionary:
	var commission := db.get_commission(commission_id)
	for option_value in commission.get("forging_options", []) as Array:
		if typeof(option_value) != TYPE_DICTIONARY:
			continue
		var option := option_value as Dictionary
		if String(option.get("id", "")) == option_id:
			return option
	return {}
