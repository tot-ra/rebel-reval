extends "res://tests/godot/test_case.gd"

## ADR 0033 / SD-03: per-school guilt weights, idempotence, absolution, saves.


func test_weights_are_per_school_and_depend_on_circumstance() -> void:
	assert_eq(
		GuiltLedger.weights_for(&"act.self_defence", false),
		{&"guilt.church": 1, &"guilt.folk": 0, &"guilt.civic": 0}
	)
	assert_eq(
		GuiltLedger.weights_for(&"act.unarmed_victim", false),
		{&"guilt.church": 4, &"guilt.folk": 3, &"guilt.civic": 3}
	)
	assert_eq(
		GuiltLedger.weights_for(&"act.provoked", true),
		{&"guilt.church": 5, &"guilt.folk": 5, &"guilt.civic": 3}
	)
	assert_eq(GuiltLedger.weights_for(&"act.nonsense", false), {})


func test_self_defence_weighs_less_than_striking_the_unarmed() -> void:
	var defender := GuiltLedger.new()
	defender.record_act(&"act.a", &"act.self_defence", false)
	var bully := GuiltLedger.new()
	bully.record_act(&"act.a", &"act.unarmed_victim", false)
	for school in GuiltLedger.SCHOOLS:
		assert_true(defender.level(school) <= bully.level(school), String(school))
	assert_true(defender.level(&"guilt.folk") == 0 and bully.level(&"guilt.folk") > 0)


func test_an_act_is_recorded_once() -> void:
	var ledger := GuiltLedger.new()
	assert_false(ledger.record_act(&"act.brawl_1", &"act.provoked").is_empty())
	assert_true(ledger.record_act(&"act.brawl_1", &"act.provoked").is_empty())
	assert_true(ledger.record_act(&"", &"act.provoked").is_empty())
	assert_true(ledger.record_act(&"act.x", &"act.unknown").is_empty())
	assert_eq(ledger.level(&"guilt.church"), 2)


func test_levels_cap_and_map_to_debuff_tiers() -> void:
	var ledger := GuiltLedger.new()
	assert_eq(ledger.debuff_tier(&"guilt.church"), 0)
	for i in 5:
		ledger.record_act(StringName("act.k%d" % i), &"act.unarmed_victim", true)
	assert_eq(ledger.level(&"guilt.church"), GuiltLedger.MAX_LEVEL)
	assert_eq(ledger.debuff_tier(&"guilt.church"), 3)
	var small := GuiltLedger.new()
	small.record_act(&"act.one", &"act.self_defence")
	assert_eq(small.debuff_tier(&"guilt.church"), 1)
	assert_eq(small.debuff_tier(&"guilt.civic"), 0)


func test_absolution_is_per_school_and_once_per_rite() -> void:
	var ledger := GuiltLedger.new()
	ledger.record_act(&"act.a", &"act.unarmed_victim")
	assert_eq(ledger.absolve(&"guilt.church", 3, &"rite.confession_1"), 3)
	assert_eq(ledger.level(&"guilt.church"), 1)
	assert_eq(ledger.level(&"guilt.folk"), 3)
	assert_eq(ledger.absolve(&"guilt.church", 3, &"rite.confession_1"), 0)
	assert_eq(ledger.absolve(&"guilt.nonsense", 1, &"rite.x"), 0)
	assert_eq(ledger.absolve(&"guilt.folk", 99, &"rite.cleansing"), 3)
	assert_eq(ledger.level(&"guilt.folk"), 0)


func test_guilt_round_trips_through_game_state_save() -> void:
	var state := GameState.new()
	state.guilt.record_act(&"act.brawl", &"act.provoked", true)
	state.guilt.absolve(&"guilt.civic", 1, &"rite.apology")
	var restored := GameState.new()
	assert_eq(restored.load_payload(state.save_payload()), [])
	assert_eq(restored.guilt.levels(), state.guilt.levels())
	assert_true(restored.guilt.record_act(&"act.brawl", &"act.provoked", true).is_empty())
	assert_eq(restored.guilt.absolve(&"guilt.civic", 1, &"rite.apology"), 0)


func test_legacy_save_without_guilt_loads_clean() -> void:
	var payload := GameState.new().save_payload()
	payload.erase("guilt")
	var state := GameState.new()
	state.guilt.record_act(&"act.old", &"act.provoked")
	assert_eq(state.load_payload(payload), [])
	assert_eq(state.guilt.level(&"guilt.church"), 0)


func test_corrupt_guilt_reports_errors() -> void:
	var payload := GameState.new().save_payload()
	payload["guilt"] = {"version": 1, "levels": {"guilt.nonsense": 3}}
	var errors := GameState.new().load_payload(payload)
	assert_true(errors.size() > 0)
