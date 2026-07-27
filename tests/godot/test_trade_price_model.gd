extends "res://tests/godot/test_case.gd"

const TradePriceModelScript := preload("res://scripts/economy/trade_price_model.gd")
const DistrictPressureModelScript := preload("res://scripts/faction/district_pressure_model.gd")
const ForgeCommissionModelScript := preload("res://scripts/forge/forge_commission_model.gd")
const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const PresenterScript := preload("res://tests/godot/dialogue_test_presenter.gd")

const VALID_DIR := "res://content/examples/valid"
const SUPPORT_DIR := "res://content/examples/support"

const DISTRICT_LOWER_TOWN := &"district.lower_town"
const LOC_LOWER_TOWN := &"loc.lower_town_slice"
const LOC_SMITHY := &"loc.kalev_smithy"
const DIALOGUE_MERCHANT := &"dialogue.merchant.trade_prices"
const COMMISSION_WATCH := &"commission.watch_buckle_repair"

const EVENT_ORDER_HOSTILE := &"ledger.test.order.hostile"
const EVENT_ORDER_TRUSTED := &"ledger.test.order.trusted"
const EVENT_KINGS_TRUSTED := &"ledger.test.kings.trusted"

var state: GameState
var db: ContentDB


func before_each() -> void:
	state = GameState.new()
	state.player.location_id = LOC_LOWER_TOWN
	db = ContentDB.new()
	assert_true(db.load_from_directories([VALID_DIR, SUPPORT_DIR]))


func test_iron_price_rises_when_district_unrest_flag_is_set() -> void:
	var calm := TradePriceModelScript.resolve(
		TradePriceModelScript.TRADE_IRON,
		DISTRICT_LOWER_TOWN,
		state
	)
	state.set_flag(DistrictPressureModelScript.district_flag(DISTRICT_LOWER_TOWN, &"unrest"), true)
	var tense := TradePriceModelScript.resolve(
		TradePriceModelScript.TRADE_IRON,
		DISTRICT_LOWER_TOWN,
		state
	)
	assert_true(int(tense.get("price_pfennigs", 0)) > int(calm.get("price_pfennigs", 0)))
	assert_true(int(tense.get("price_tier", 0)) >= TradePriceModelScript.TIER_NORMAL)


func test_bread_price_falls_when_rebel_market_controls_supply() -> void:
	var baseline := TradePriceModelScript.resolve(
		TradePriceModelScript.TRADE_BREAD,
		DISTRICT_LOWER_TOWN,
		state
	)
	state.record_faction_event(
		EVENT_KINGS_TRUSTED,
		FactionLedger.HARJU_KINGS,
		3,
		"Rebel sympathizers keep the market lane open."
	)
	state.set_flag(DistrictPressureModelScript.district_flag(DISTRICT_LOWER_TOWN, &"market_open"), true)
	var relieved := TradePriceModelScript.resolve(
		TradePriceModelScript.TRADE_BREAD,
		DISTRICT_LOWER_TOWN,
		state
	)
	assert_true(int(relieved.get("price_pfennigs", 0)) < int(baseline.get("price_pfennigs", 0)))
	assert_true(int(relieved.get("price_tier", 0)) <= int(baseline.get("price_tier", 0)))


func test_each_essential_good_has_at_least_two_price_tiers() -> void:
	for good_id: StringName in TradePriceModelScript.ESSENTIAL_GOODS:
		var low_state := GameState.new()
		if good_id == TradePriceModelScript.TRADE_BREAD:
			low_state.record_faction_event(
				EVENT_KINGS_TRUSTED,
				FactionLedger.HARJU_KINGS,
				3,
				"Fixture for low bread tier."
			)
			low_state.set_flag(
				DistrictPressureModelScript.district_flag(DISTRICT_LOWER_TOWN, &"market_open"),
				true
			)
		else:
			low_state.record_faction_event(
				EVENT_ORDER_TRUSTED,
				FactionLedger.LIVONIAN_ORDER,
				3,
				"Fixture for low iron tier."
			)

		var high_state := GameState.new()
		high_state.set_flag(DistrictPressureModelScript.district_flag(DISTRICT_LOWER_TOWN, &"unrest"), true)
		high_state.set_flag(DistrictPressureModelScript.district_flag(DISTRICT_LOWER_TOWN, &"martial_law"), true)
		if good_id == TradePriceModelScript.TRADE_IRON:
			high_state.set_flag(
				DistrictPressureModelScript.district_flag(DISTRICT_LOWER_TOWN, &"iron_restricted"),
				true
			)
		high_state.record_faction_event(
			EVENT_ORDER_HOSTILE,
			FactionLedger.LIVONIAN_ORDER,
			-3,
			"Fixture for high tier."
		)

		var low_tier := int(
			TradePriceModelScript.resolve(good_id, DISTRICT_LOWER_TOWN, low_state).get("price_tier", 0)
		)
		var high_tier := int(
			TradePriceModelScript.resolve(good_id, DISTRICT_LOWER_TOWN, high_state).get("price_tier", 0)
		)
		assert_true(low_tier != high_tier, "Expected two tiers for %s" % String(good_id))


func test_merchant_dialogue_quotes_change_with_district_pressure() -> void:
	var calm_bundle := _start_merchant_dialogue(GameState.new())
	var calm_text: String = calm_bundle["presenter"].last_text

	var tense_state := GameState.new()
	tense_state.player.location_id = LOC_LOWER_TOWN
	tense_state.set_flag(DistrictPressureModelScript.district_flag(DISTRICT_LOWER_TOWN, &"unrest"), true)
	tense_state.set_flag(DistrictPressureModelScript.district_flag(DISTRICT_LOWER_TOWN, &"martial_law"), true)
	var tense_bundle := _start_merchant_dialogue(tense_state)
	var tense_text: String = tense_bundle["presenter"].last_text

	assert_ne(calm_text, tense_text)
	assert_false(calm_text.contains("{trade_price:"))
	assert_true(calm_text.contains("iron"))
	assert_true(tense_text.contains("pfennig"))


func test_commission_material_cost_tracks_iron_market_price() -> void:
	state.player.location_id = LOC_SMITHY
	var calm_snapshot := ForgeCommissionModelScript.build_snapshot(COMMISSION_WATCH, state, db)
	state.set_flag(DistrictPressureModelScript.district_flag(DISTRICT_LOWER_TOWN, &"unrest"), true)
	state.set_flag(DistrictPressureModelScript.district_flag(DISTRICT_LOWER_TOWN, &"iron_restricted"), true)
	state.record_faction_event(
		EVENT_ORDER_HOSTILE,
		FactionLedger.LIVONIAN_ORDER,
		-3,
		"Order seized iron shipments."
	)
	var tense_snapshot := ForgeCommissionModelScript.build_snapshot(COMMISSION_WATCH, state, db)

	var calm_cost := int(calm_snapshot.get("material_cost_pfennigs", 0))
	var tense_cost := int(tense_snapshot.get("material_cost_pfennigs", 0))
	assert_true(tense_cost > calm_cost)
	assert_true(String(tense_snapshot.get("material_cost_display", "")).contains("pfennig"))


func _start_merchant_dialogue(game_state: GameState) -> Dictionary:
	var presenter := PresenterScript.new()
	var runner := RunnerScript.new()
	runner.configure(db, game_state, presenter, StateRuleEvaluator.new())
	game_state.player.location_id = LOC_LOWER_TOWN
	assert_true(runner.start(DIALOGUE_MERCHANT))
	return {"runner": runner, "presenter": presenter}
