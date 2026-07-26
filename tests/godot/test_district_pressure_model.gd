extends "res://tests/godot/test_case.gd"

const DistrictPressureModelScript := preload("res://scripts/faction/district_pressure_model.gd")

const EVENT_ORDER_TRUSTED := &"ledger.test.order.trusted"
const EVENT_ORDER_HOSTILE := &"ledger.test.order.hostile"
const EVENT_HANSE_TRUSTED := &"ledger.test.hanse.trusted"
const EVENT_CLOAKS_STRONG := &"ledger.test.cloaks.strong"

const LOC_LOWER_TOWN := &"loc.lower_town_slice"
const DISTRICT_LOWER_TOWN := &"district.lower_town"
const DISTRICT_NORTH_MERCHANT := &"district.north_merchant"


var state: GameState


func before_each() -> void:
	state = GameState.new()


func test_lower_town_relaxes_when_order_standing_is_high() -> void:
	state.record_faction_event(
		EVENT_ORDER_TRUSTED,
		FactionLedger.LIVONIAN_ORDER,
		3,
		"Order patrols trust the smith."
	)
	var snapshot: Dictionary = DistrictPressureModelScript.resolve_for_location(LOC_LOWER_TOWN, state)
	assert_eq(snapshot.get("pressure_tier"), DistrictPressureModelScript.TIER_RELAXED)
	assert_eq(snapshot.get("bark_pool_id"), &"bark.district.lower_town.relaxed")
	assert_true(float(snapshot.get("patrol_speed_scale")) < 1.0)
	assert_true(float(snapshot.get("price_multiplier")) < 1.0)


func test_lower_town_tightens_when_order_is_hostile_and_unrest_flag_is_set() -> void:
	state.record_faction_event(
		EVENT_ORDER_HOSTILE,
		FactionLedger.LIVONIAN_ORDER,
		-3,
		"Order suspects the forge."
	)
	state.set_flag(DistrictPressureModelScript.district_flag(DISTRICT_LOWER_TOWN, &"unrest"), true)
	var snapshot: Dictionary = DistrictPressureModelScript.resolve_for_location(LOC_LOWER_TOWN, state)
	assert_eq(snapshot.get("pressure_tier"), DistrictPressureModelScript.TIER_CRACKDOWN)
	assert_eq(snapshot.get("bark_pool_id"), &"bark.district.lower_town.crackdown")
	assert_true(float(snapshot.get("patrol_speed_scale")) > 1.0)
	assert_true(bool(snapshot.get("secondary_patrol_enabled")))


func test_north_merchant_diverges_from_lower_town_under_same_ledger_fixture() -> void:
	state.record_faction_event(
		EVENT_ORDER_TRUSTED,
		FactionLedger.LIVONIAN_ORDER,
		3,
		"Order patrols keep Lower Town calm."
	)
	state.record_faction_event(
		EVENT_HANSE_TRUSTED,
		FactionLedger.HANSEATIC,
		3,
		"Hanseatic guilds control the merchant lane."
	)
	state.record_faction_event(
		EVENT_CLOAKS_STRONG,
		FactionLedger.BLACK_CLOAKS,
		2,
		"Black Cloaks move openly on Pikk."
	)
	var lower: Dictionary = DistrictPressureModelScript.resolve(DISTRICT_LOWER_TOWN, state)
	var north: Dictionary = DistrictPressureModelScript.resolve(DISTRICT_NORTH_MERCHANT, state)
	assert_ne(lower.get("pressure_tier"), north.get("pressure_tier"))
	assert_ne(lower.get("bark_pool_id"), north.get("bark_pool_id"))
	assert_ne(lower.get("price_multiplier"), north.get("price_multiplier"))


func test_state_rule_evaluator_gates_on_district_pressure_and_price_tiers() -> void:
	var evaluator := StateRuleEvaluator.new()
	state.record_faction_event(
		EVENT_ORDER_HOSTILE,
		FactionLedger.LIVONIAN_ORDER,
		-3,
		"Order suspects the forge."
	)
	state.set_flag(DistrictPressureModelScript.district_flag(DISTRICT_LOWER_TOWN, &"unrest"), true)
	var pressure_gate := {
		"op": "district_pressure_at_least",
		"key": "district.lower_town",
		"amount": DistrictPressureModelScript.TIER_CRACKDOWN,
	}
	var price_gate := {
		"op": "district_price_tier_at_least",
		"key": "district.lower_town",
		"amount": DistrictPressureModelScript.TIER_TENSE,
	}
	assert_true(evaluator.evaluate_condition(pressure_gate, state))
	assert_true(evaluator.evaluate_condition(price_gate, state))
