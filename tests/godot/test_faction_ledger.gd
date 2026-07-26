extends "res://tests/godot/test_case.gd"

const EVENT_HONEST := &"ledger.black_cloaks.honest_delivery"
const EVENT_BETRAYAL := &"ledger.livonian_order.betrayal"
const FACTION_BLACK_CLOAKS := FactionLedger.BLACK_CLOAKS
const FACTION_ORDER := FactionLedger.LIVONIAN_ORDER

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
