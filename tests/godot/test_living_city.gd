extends "res://tests/godot/test_case.gd"

const EVENT_HOLD := &"living.bell_and_chain.honest_hold"

var state: GameState

func before_each() -> void:
	state = GameState.new()

func test_named_event_updates_independent_meters_and_is_idempotent() -> void:
	assert_eq(state.get_living_city_hope(), GameState.LIVING_CITY_DEFAULT)
	assert_true(state.record_living_city_event(EVENT_HOLD, 0, 1, "The gate holds."))
	assert_eq(state.get_living_city_hope(), 8)
	assert_eq(state.get_living_city_fear(), 9)
	assert_false(state.record_living_city_event(EVENT_HOLD, 2, 0, "Replay."))

func test_event_conditions_and_save_round_trip_are_explicit() -> void:
	var evaluator := StateRuleEvaluator.new()
	var effect := {
		"op": "record_living_city_event",
		"key": String(EVENT_HOLD),
		"hope_delta": 0,
		"fear_delta": 1,
		"summary": "The gate holds.",
	}
	assert_true(evaluator.apply_effect(effect, state))
	assert_true(evaluator.evaluate_condition({"op": "living_city_fear_at_least", "amount": 9}, state))
	assert_true(evaluator.evaluate_condition({"op": "living_city_hope_at_most", "amount": 8}, state))
	var payload := state.save_payload()
	assert_true(payload.has("living_city"))
	assert_false(payload.has("morality"))
	var restored := GameState.new()
	assert_eq(restored.load_payload(payload), [])
	assert_eq(restored.get_living_city_fear(), 9)
	assert_true(restored.has_living_city_event(EVENT_HOLD))

func test_district_bridge_uses_authored_hope_threshold() -> void:
	state.record_living_city_event(&"living.hope.public_defiance", 5, 0, "The street talks.")
	state.record_living_city_event(&"living.hope.public_defiance_two", 1, 0, "The street dares.")
	state.record_faction_event(&"ledger.test.kings", FactionLedger.HARJU_KINGS, 2, "Trusted rebels.")
	var snapshot := DistrictPressureModel.resolve(DistrictPressureModel.DISTRICT_LOWER_TOWN, state)
	assert_eq(snapshot.get("pressure_tier"), DistrictPressureModel.TIER_CRACKDOWN)
