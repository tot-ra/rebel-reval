extends "res://tests/godot/test_case.gd"

const CommissionDeadlineModelScript := preload("res://scripts/commission/commission_deadline_model.gd")

const FLAG_INCIDENT := &"flag.prologue_maker_mark_incident"
const FACT_SPEARHEAD := &"fact.seized_spearhead_seen"
const PHASE_NIGHT := &"phase.investigation_night"
const PRESSURE_SUSPICION := &"pressure.suspicion"
const REL_HENNING := &"rel.henning_trust"
const ITEM_SPEARHEAD := &"item.seized_spearhead"
const QUEST_MAKERS_MARK := &"quest.makers_mark"
const LOCATION_SMITHY := &"loc.kalev_smithy"

var evaluator: StateRuleEvaluator
var state: GameState


func before_each() -> void:
	evaluator = StateRuleEvaluator.new()
	state = GameState.new()


func test_all_condition_operators() -> void:
	state.set_flag(FLAG_INCIDENT, true)
	state.set_fact(FACT_SPEARHEAD, true)
	state.set_phase(PHASE_NIGHT)
	state.set_pressure(PRESSURE_SUSPICION, 2)
	state.set_relationship(REL_HENNING, 1)
	state.record_faction_event(
		&"ledger.test.black_cloaks.neutral",
		FactionLedger.BLACK_CLOAKS,
		0,
		"Fixture neutral contact."
	)
	state.add_item(ITEM_SPEARHEAD)
	state.set_quest_state(QUEST_MAKERS_MARK, &"incident_known")

	var conditions := [
		{"op": "always"},
		{"op": "flag_is", "key": String(FLAG_INCIDENT), "value": true},
		{"op": "flag_not", "key": String(FLAG_INCIDENT), "value": false},
		{"op": "fact_known", "key": String(FACT_SPEARHEAD)},
		{"op": "phase_is", "key": String(PHASE_NIGHT), "value": "active"},
		{"op": "pressure_at_least", "key": String(PRESSURE_SUSPICION), "amount": 2},
		{"op": "relationship_at_least", "key": String(REL_HENNING), "amount": 1},
		{"op": "faction_standing_at_least", "key": "faction.black_cloaks", "amount": 0},
		{
			"op": "district_pressure_at_least",
			"key": "district.lower_town",
			"amount": 1,
		},
		{"op": "item_owned", "key": String(ITEM_SPEARHEAD)},
		{"op": "quest_state_is", "key": String(QUEST_MAKERS_MARK), "value": "incident_known"},
	]

	for condition in conditions:
		assert_true(evaluator.evaluate_condition(condition, state), "Expected condition to pass: %s" % condition)
	assert_true(evaluator.evaluate_conditions(conditions, state))
	assert_eq(evaluator.get_last_error(), "")

	state.add_forged_record(
		ForgedRecord.new(
			&"forged.watch_buckle_repair.honest_work",
			&"commission.watch_buckle_repair",
			&"item.watch_buckle",
			&"honest_work"
		)
	)
	var forged_condition := {
		"op": "forged_modification_is",
		"key": "commission.watch_buckle_repair",
		"value": "honest_work",
	}
	assert_true(evaluator.evaluate_condition(forged_condition, state))
	assert_false(
		evaluator.evaluate_condition(
			{
				"op": "forged_modification_is",
				"key": "commission.watch_buckle_repair",
				"value": "subtle_defect",
			},
			state
		)
	)

	state.record_relationship_memory(&"memory.mart.helped")
	var memory_condition := {"op": "memory_recorded", "key": "memory.mart.helped"}
	assert_true(evaluator.evaluate_condition(memory_condition, state))

	state.set_commission_deadline_status(&"commission.watch_buckle_repair", CommissionDeadlineModelScript.STATUS_MET)
	assert_true(
		evaluator.evaluate_condition(
			{"op": "commission_deadline_met", "key": "commission.watch_buckle_repair"},
			state
		)
	)
	state.set_commission_deadline_status(&"commission.lantern_hook_rush", CommissionDeadlineModelScript.STATUS_MISSED)
	assert_true(
		evaluator.evaluate_condition(
			{"op": "commission_deadline_missed", "key": "commission.lantern_hook_rush"},
			state
		)
	)


func test_false_condition_is_not_an_error() -> void:
	var condition := {"op": "flag_is", "key": String(FLAG_INCIDENT), "value": true}

	assert_false(evaluator.evaluate_condition(condition, state))
	assert_eq(evaluator.get_last_error(), "")


func test_all_effect_operators() -> void:
	state.add_item(ITEM_SPEARHEAD)
	var effects := [
		{"op": "set_flag", "key": String(FLAG_INCIDENT), "value": true},
		{"op": "set_fact", "key": String(FACT_SPEARHEAD), "value": true},
		{"op": "set_phase", "key": String(PHASE_NIGHT), "value": "active"},
		{"op": "set_quest_state", "key": String(QUEST_MAKERS_MARK), "value": "incident_known"},
		{"op": "adjust_pressure", "key": String(PRESSURE_SUSPICION), "amount": 2},
		{"op": "adjust_relationship", "key": String(REL_HENNING), "amount": -1},
		{
			"op": "record_faction_event",
			"key": "ledger.test.black_cloaks.trusted",
			"value": "faction.black_cloaks",
			"amount": 1,
			"summary": "Test ledger write.",
		},
		{"op": "remove_item", "key": String(ITEM_SPEARHEAD)},
		{"op": "add_item", "key": "item.watch_buckle"},
		{"op": "set_location_state", "key": String(LOCATION_SMITHY), "value": "after_ledger_destroyed"},
		{"op": "record_memory", "key": "memory.mart.ignored"},
	]

	assert_true(evaluator.apply_effects(effects, state))
	assert_true(state.get_flag(FLAG_INCIDENT))
	assert_true(state.get_fact(FACT_SPEARHEAD))
	assert_eq(state.get_phase(), PHASE_NIGHT)
	assert_eq(state.get_quest_state(QUEST_MAKERS_MARK), &"incident_known")
	assert_eq(state.get_pressure(PRESSURE_SUSPICION), 2)
	assert_eq(state.get_relationship(REL_HENNING), -1)
	assert_true(state.has_faction_event(&"ledger.test.black_cloaks.trusted"))
	assert_eq(state.get_faction_standing(FactionLedger.BLACK_CLOAKS), 1)
	assert_false(state.has_item(ITEM_SPEARHEAD))
	assert_true(state.has_item(&"item.watch_buckle"))
	assert_eq(state.get_location_state(LOCATION_SMITHY), &"after_ledger_destroyed")
	assert_true(state.has_relationship_memory(&"memory.mart.ignored"))


func test_unknown_condition_rejects_arbitrary_expression() -> void:
	var condition := {
		"op": "script",
		"value": "state.set_flag('flag.injected', true)",
	}

	assert_false(evaluator.evaluate_condition(condition, state))
	assert_false(state.get_flag(&"flag.injected"))
	assert_true(evaluator.get_last_error().contains("unsupported condition op"))


func test_unknown_effect_rejects_arbitrary_expression_without_partial_mutation() -> void:
	var effects := [
		{"op": "set_flag", "key": String(FLAG_INCIDENT), "value": true},
		{"op": "script", "key": "flag.injected", "value": "state.set_flag('flag.injected', true)"},
	]

	assert_false(evaluator.apply_effects(effects, state))
	assert_false(state.get_flag(FLAG_INCIDENT))
	assert_false(state.get_flag(&"flag.injected"))
	assert_true(evaluator.get_last_error().contains("unsupported effect op"))



func test_condition_batch_rejects_expression_after_false_condition() -> void:
	var conditions := [
		{"op": "flag_is", "key": String(FLAG_INCIDENT), "value": true},
		{"op": "script", "value": "state.set_flag('flag.injected', true)"},
	]

	assert_false(evaluator.evaluate_conditions(conditions, state))
	assert_false(state.get_flag(&"flag.injected"))
	assert_true(evaluator.get_last_error().contains("unsupported condition op"))

func test_invalid_shapes_and_namespaces_are_rejected() -> void:
	assert_false(evaluator.evaluate_condition({"op": "always", "value": true}, state))
	assert_false(evaluator.evaluate_condition({"op": "flag_is", "key": "fact.wrong", "value": true}, state))
	assert_false(evaluator.apply_effect({"op": "adjust_pressure", "key": "pressure.suspicion", "amount": 4}, state))
	assert_false(evaluator.apply_effect({"op": "set_fact", "key": "fact.seen", "value": "true"}, state))
	assert_false(evaluator.apply_effect({"op": "add_item", "key": "item.watch_buckle", "extra": true}, state))


func test_game_state_rule_collections_are_isolated() -> void:
	var other := GameState.new()
	state.set_flag(FLAG_INCIDENT, true)
	state.set_quest_state(QUEST_MAKERS_MARK, &"incident_known")
	state.set_location_state(LOCATION_SMITHY, &"prologue_day")
	state.add_item(ITEM_SPEARHEAD)

	assert_false(other.get_flag(FLAG_INCIDENT))
	assert_eq(other.get_quest_state(QUEST_MAKERS_MARK), &"")
	assert_eq(other.get_location_state(LOCATION_SMITHY), &"")
	assert_false(other.has_item(ITEM_SPEARHEAD))
