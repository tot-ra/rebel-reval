extends "res://tests/godot/test_case.gd"

const EVENT_HONEST := &"ledger.black_cloaks.honest_delivery"
const EVENT_BETRAYAL := &"ledger.livonian_order.betrayal"
const QUEST_MAKERS_MARK := &"quest.makers_mark"
const COMMISSION_BITTER_BREW := &"commission.bitter_brew"
const VALID_DIR := "res://content/examples/valid"
const SUPPORT_DIR := "res://content/examples/support"
const CommissionRunnerScript := preload("res://scripts/forge/forge_commission_runner.gd")
const CommissionPresenterScript := preload("res://scripts/forge/forge_commission_presenter.gd")
const FACTION_BLACK_CLOAKS := FactionLedger.BLACK_CLOAKS
const FACTION_ORDER := FactionLedger.LIVONIAN_ORDER
const FACTION_BLACKHEADS := FactionCandidateSeats.BLACKHEADS
const EVENT_BLACKHEADS := &"ledger.blackheads.johann_contract_favour"
const BLACKHEADS_HOOKS_PATH := "res://content/examples/support/faction.blackheads.candidate_hooks.json"

var evaluator: StateRuleEvaluator
var state: GameState


func before_each() -> void:
	evaluator = StateRuleEvaluator.new()
	state = GameState.new()


func test_recorded_events_change_standing() -> void:
	assert_true(
		state.record_faction_event(
			EVENT_HONEST,
			FACTION_BLACK_CLOAKS,
			2,
			"Delivered honest forge work for the underguild."
		)
	)
	assert_eq(state.get_faction_standing(FACTION_BLACK_CLOAKS), 2)
	assert_true(state.has_faction_event(EVENT_HONEST))
	assert_false(
		state.record_faction_event(
			EVENT_HONEST,
			FACTION_BLACK_CLOAKS,
			1,
			"Duplicate must be rejected."
		)
	)


func test_content_effect_records_event_and_gates_quest_price_route() -> void:
	var record_effect := {
		"op": "record_faction_event",
		"key": String(EVENT_HONEST),
		"value": "faction.black_cloaks",
		"amount": 2,
		"summary": "Delivered honest forge work for the underguild.",
	}
	assert_true(evaluator.apply_effect(record_effect, state))

	var quest_gate := {
		"op": "faction_standing_at_least",
		"key": "faction.black_cloaks",
		"amount": 2,
	}
	assert_true(evaluator.evaluate_condition(quest_gate, state))

	var price_gate := {
		"op": "faction_standing_at_least",
		"key": "faction.black_cloaks",
		"amount": 1,
	}
	assert_true(evaluator.evaluate_condition(price_gate, state))

	var route_gate := {
		"op": "faction_standing_at_least",
		"key": "faction.black_cloaks",
		"amount": 3,
	}
	assert_false(evaluator.evaluate_condition(route_gate, state))


func test_negative_standing_from_betrayal_event() -> void:
	assert_true(
		state.record_faction_event(
			EVENT_BETRAYAL,
			FACTION_ORDER,
			-2,
			"Warned rebels about an Order inspection."
		)
	)
	assert_eq(state.get_faction_standing(FACTION_ORDER), -2)
	var gate := {
		"op": "faction_standing_at_least",
		"key": "faction.livonian_order",
		"amount": -1,
	}
	assert_false(evaluator.evaluate_condition(gate, state))


func test_snapshot_lists_only_factions_with_events() -> void:
	state.record_faction_event(
		EVENT_HONEST,
		FACTION_BLACK_CLOAKS,
		1,
		"Shared a crate tally with Mart."
	)
	var snapshot := FactionLedgerModel.build_snapshot(state)
	var factions: Array = snapshot.get("factions", [])
	assert_eq(factions.size(), FactionLedger.ACTIVE_FACTIONS.size())
	var black_row: Dictionary = factions[1]
	for row in factions:
		if row.get("faction_id", &"") == FACTION_BLACK_CLOAKS:
			black_row = row
			break
	assert_eq(int(black_row.get("standing", 0)), 1)
	assert_eq((black_row.get("events", []) as Array).size(), 1)


func test_game_state_has_no_universal_morality_meter() -> void:
	state.record_faction_event(
		EVENT_HONEST,
		FACTION_BLACK_CLOAKS,
		1,
		"Test event."
	)
	var payload := state.save_payload()
	for forbidden_key in ["morality", "balance_of_power", "rebel_score", "ruler_score", "ledger_total"]:
		assert_false(payload.has(forbidden_key), "GameState must not expose %s" % forbidden_key)
	for key in payload.keys():
		var lowered := String(key).to_lower()
		assert_false(lowered.contains("morality"), "unexpected morality aggregate key %s" % String(key))
		assert_false(lowered.contains("balance_of_power"), "unexpected balance key %s" % String(key))


func test_faction_ledger_survives_save_round_trip() -> void:
	state.record_faction_event(
		EVENT_HONEST,
		FACTION_BLACK_CLOAKS,
		2,
		"Delivered honest forge work for the underguild."
	)
	var before := FactionLedgerModel.build_snapshot(state)
	var payload := state.save_payload()
	var restored := GameState.new()
	assert_eq(restored.load_payload(payload).size(), 0)
	var after := FactionLedgerModel.build_snapshot(restored)
	assert_eq(after, before)


func test_blackheads_candidate_events_are_accepted_without_launch_seat() -> void:
	assert_eq(FactionLedger.ACTIVE_FACTIONS.size(), 8)
	assert_false(FactionLedger.is_active_faction(FACTION_BLACKHEADS))
	assert_true(FactionCandidateSeats.is_candidate_faction(FACTION_BLACKHEADS))
	assert_true(FactionCandidateSeats.is_recordable_faction(FACTION_BLACKHEADS))
	assert_false(FactionCandidateSeats.is_recordable_faction(&"lizard_union"))

	var record_effect := {
		"op": "record_faction_event",
		"key": String(EVENT_BLACKHEADS),
		"value": "faction.blackheads",
		"amount": 1,
		"summary": "Johann von Minden secured a favourable harbour contract for Kalev's forge.",
	}
	assert_true(evaluator.apply_effect(record_effect, state))
	assert_true(state.has_faction_event(EVENT_BLACKHEADS))
	assert_eq(state.get_faction_standing(FACTION_BLACKHEADS), 1)

	var standing_gate := {
		"op": "faction_standing_at_least",
		"key": "faction.blackheads",
		"amount": 1,
	}
	assert_true(evaluator.evaluate_condition(standing_gate, state))

	var snapshot := FactionLedgerModel.build_snapshot(state)
	var factions: Array = snapshot.get("factions", [])
	assert_eq(factions.size(), 8)
	for row in factions:
		assert_false(row.get("faction_id", &"") == FACTION_BLACKHEADS)

	assert_false(
		state.record_faction_event(
			&"ledger.lizard_union.illegal",
			&"lizard_union",
			1,
			"Lizard Union must remain intrigue-cell-only."
		)
	)

	var payload := state.save_payload()
	var restored := GameState.new()
	assert_eq(restored.load_payload(payload).size(), 0)
	assert_true(restored.has_faction_event(EVENT_BLACKHEADS))
	assert_eq(restored.get_faction_standing(FACTION_BLACKHEADS), 1)


func test_readme_still_lists_exactly_eight_launch_factions() -> void:
	var readme := FileAccess.get_file_as_string("res://README.md")
	assert_false(readme.is_empty())
	assert_true(readme.contains("`danish_crown`"))
	assert_true(readme.contains("`livonian_order`"))
	assert_true(readme.contains("`hanseatic`"))
	assert_true(readme.contains("`harju_kings`"))
	assert_true(readme.contains("`black_cloaks`"))
	assert_true(readme.contains("`cult_metsik`"))
	assert_true(readme.contains("`pskov_novgorod`"))
	assert_true(readme.contains("`vitalienbruder`"))
	assert_false(readme.contains("`blackheads`"))
	assert_false(readme.contains("faction.blackheads"))
	assert_false(readme.contains("`lizard_union`"))


func test_blackheads_candidate_hooks_content_stub_exists() -> void:
	assert_true(FileAccess.file_exists(BLACKHEADS_HOOKS_PATH))
	var raw := FileAccess.get_file_as_string(BLACKHEADS_HOOKS_PATH)
	assert_false(raw.is_empty())
	var parsed: Variant = JSON.parse_string(raw)
	assert_true(parsed is Dictionary)
	var quest: Dictionary = parsed
	assert_eq(String(quest.get("id", "")), "quest.blackheads_candidate_hooks")
	var transitions: Array = quest.get("transitions", [])
	assert_eq(transitions.size(), 3)
	for transition in transitions:
		var found_blackheads := false
		for effect in transition.get("effects", []):
			if String(effect.get("value", "")) == "faction.blackheads":
				found_blackheads = true
				break
		assert_true(found_blackheads, "each stub transition must target faction.blackheads")


func test_makers_mark_ledger_branches_record_faction_events() -> void:
	var db := ContentDB.new()
	assert_true(db.load_from_directories([VALID_DIR, SUPPORT_DIR]))
	var branches := [
		{
			"transition": &"preserve_ledger",
			"event": &"ledger.makers_mark.preserve_truth",
			"faction": FactionLedger.LIVONIAN_ORDER,
			"standing": 1,
		},
		{
			"transition": &"alter_ledger",
			"event": &"ledger.makers_mark.alter_for_apprentice",
			"faction": FactionLedger.BLACK_CLOAKS,
			"standing": 1,
		},
		{
			"transition": &"destroy_ledger",
			"event": &"ledger.makers_mark.destroy_evidence",
			"faction": FactionLedger.LIVONIAN_ORDER,
			"standing": -1,
		},
	]
	for branch in branches:
		var slice_state := GameState.new()
		slice_state.set_quest_state(QUEST_MAKERS_MARK, &"incident_known")
		slice_state.set_flag(&"flag.mart_missing", true)
		var quest_manager := QuestManager.new(db, slice_state)
		assert_true(
			quest_manager.transition(QUEST_MAKERS_MARK, branch["transition"]),
			"transition %s should commit" % String(branch["transition"])
		)
		assert_true(slice_state.has_faction_event(branch["event"]))
		assert_eq(slice_state.get_faction_standing(branch["faction"]), branch["standing"])


func test_bitter_brew_forged_outcomes_record_faction_events() -> void:
	var db := ContentDB.new()
	assert_true(db.load_from_directories([VALID_DIR, SUPPORT_DIR]))
	var options := [
		{
			"option": "honest_work",
			"event": &"ledger.bitter_brew.honest_securing",
			"faction": FactionLedger.HANSEATIC,
			"standing": 1,
			"facts": [] as Array[StringName],
		},
		{
			"option": "subtle_defect",
			"event": &"ledger.bitter_brew.seal_deception",
			"faction": FactionLedger.LIVONIAN_ORDER,
			"standing": -1,
			"facts": [&"fact.bitter_brew.checkpoint_neglect"],
		},
		{
			"option": "secret_feature",
			"event": &"ledger.bitter_brew.cart_release",
			"faction": FactionLedger.BLACK_CLOAKS,
			"standing": 1,
			"facts": [
				&"fact.bitter_brew.brewery_ale_sound",
				&"fact.bitter_brew.merchant_supply_spoiled",
			],
		},
	]
	for option_row in options:
		var slice_state := GameState.new()
		slice_state.set_phase(GameState.PHASE_INVESTIGATION_MORNING)
		slice_state.set_quest_state(&"quest.bitter_brew", &"investigation_ready")
		for fact_id in option_row["facts"]:
			slice_state.set_fact(fact_id, true)
		var setup := _make_commission_runner_setup(db, slice_state)
		assert_true(setup["runner"].open(COMMISSION_BITTER_BREW))
		assert_true(setup["runner"].select_option(String(option_row["option"])))
		assert_true(slice_state.has_faction_event(option_row["event"]))
		assert_eq(slice_state.get_faction_standing(option_row["faction"]), option_row["standing"])
		_cleanup_commission_runner(setup)


func _make_commission_runner_setup(db: ContentDB, slice_state: GameState) -> Dictionary:
	var presenter := _SliceCommissionPresenter.new()
	var runner := CommissionRunnerScript.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(runner)
	runner.configure(db, slice_state, presenter)
	return {"runner": runner, "presenter": presenter}


func _cleanup_commission_runner(setup: Dictionary) -> void:
	var runner: Node = setup.get("runner")
	if runner != null and is_instance_valid(runner):
		runner.queue_free()


class _SliceCommissionPresenter extends CommissionPresenterScript:
	func present_commission(_snapshot: Dictionary) -> void:
		pass

	func close() -> void:
		pass
