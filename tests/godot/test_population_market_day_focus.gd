extends "res://tests/godot/test_case.gd"

## R-412 focused contract coverage for the calendar-to-population bridge.
## WHY: the broader controller and lifecycle suites cover individual systems;
## this file keeps the cross-system transition matrix explicit and small.

const ControllerScript := preload("res://scripts/world/market_day_controller.gd")
const ProfileScript := preload("res://scripts/world/urban_population_profile.gd")

const PHASE_DAY := GameState.PHASE_INVESTIGATION_MORNING
const DATE_OFF_DAY := {"day": 22, "month": 4, "year": 1343}
const DATE_MARKET_DAY := {"day": 24, "month": 4, "year": 1343}
const REPLAY_SEED := 412
const FLAG_MARKET_DAY := &"flag.market_day_active"


class PopulationProbe:
	extends RefCounted

	var calls: Array[String] = []
	var snapshots: Array[Dictionary] = []

	func set_market_day_active(active: bool) -> void:
		calls.append("population:%s" % str(active))
		var date := DATE_MARKET_DAY if active else DATE_OFF_DAY
		snapshots.append(ProfileScript.resolve_for_context(
			PHASE_DAY,
			date,
			REPLAY_SEED,
			{"market_day": active},
		))

	func record_signal(active: bool) -> void:
		calls.append("signal:%s" % str(active))


func test_calendar_transitions_drive_population_once_per_state_change() -> void:
	var state := GameState.new()
	state.set_phase(PHASE_DAY)
	var controller := ControllerScript.new()
	var probe := PopulationProbe.new()
	controller._state = state
	controller.bind_population_controller(probe)
	controller.market_day_changed.connect(probe.record_signal)

	controller.sync_for_test(PHASE_DAY, 0)
	controller.sync_for_test(PHASE_DAY, 2)
	controller.sync_for_test(PHASE_DAY, 2)
	controller.sync_for_test(PHASE_DAY, 3)
	controller.sync_for_test(PHASE_DAY, 5)

	assert_eq(
		probe.calls,
		[
			"population:false",
			"signal:true",
			"population:true",
			"signal:false",
			"population:false",
			"signal:true",
			"population:true",
		],
		"market-day updates must be ordered and emitted only when the calendar state changes",
	)
	assert_eq(probe.snapshots.size(), 4)
	assert_eq(probe.snapshots[0]["profile_id"], ProfileScript.PROFILE_DAY)
	assert_eq(probe.snapshots[1]["profile_id"], ProfileScript.PROFILE_MARKET_DAY)
	assert_eq(probe.snapshots[2]["profile_id"], ProfileScript.PROFILE_DAY)
	assert_eq(probe.snapshots[3]["profile_id"], ProfileScript.PROFILE_MARKET_DAY)
	assert_true(state.get_flag(FLAG_MARKET_DAY))
	controller.free()


func test_market_day_profile_contains_both_trade_sides_without_authored_keeper_duplication() -> void:
	var profile := ProfileScript.resolve_for_context(
		PHASE_DAY,
		DATE_MARKET_DAY,
		REPLAY_SEED,
		{"market_day": true},
	)
	var market_merchants := 0
	var market_customers := 0
	var actor_plan: Array[Dictionary] = profile["actor_plan"]

	for actor: Dictionary in actor_plan:
		assert_ne(actor["role"], &"keeper")
		assert_ne(actor["occupation"], &"keeper")
		if actor["role"] != &"civilian" or actor["zone_id"] != ProfileScript.ZONE_MARKET:
			continue
		if actor["occupation"] == &"merchant":
			market_merchants += 1
		else:
			market_customers += 1

	assert_eq(profile["profile_id"], ProfileScript.PROFILE_MARKET_DAY)
	assert_true(profile["calendar_market_day"])
	assert_true(profile["market_day"])
	assert_true(profile["civilian_count"] > ProfileScript.day(PHASE_DAY, DATE_OFF_DAY)["civilian_count"])
	assert_true(market_merchants > 0, "market lane must receive merchant activity")
	assert_true(market_customers > 0, "market lane must receive customer traffic")
	assert_eq(actor_plan.size(), profile["total_count"])


func test_population_profiles_preserve_role_counts_and_authored_caps_across_contexts() -> void:
	var contexts: Array[Dictionary] = [
		{
			"profile": ProfileScript.resolve_for_context(PHASE_DAY, DATE_OFF_DAY, REPLAY_SEED),
			"expected_civilians": 18,
			"expected_watch": 3,
		},
		{
			"profile": ProfileScript.resolve_for_context(PHASE_DAY, DATE_MARKET_DAY, REPLAY_SEED),
			"expected_civilians": 28,
			"expected_watch": 5,
		},
		{
			"profile": ProfileScript.night(GameState.PHASE_INVESTIGATION_NIGHT, DATE_OFF_DAY, REPLAY_SEED),
			"expected_civilians": 6,
			"expected_watch": 6,
		},
	]

	for context: Dictionary in contexts:
		var profile: Dictionary = context["profile"]
		var civilian_roles := 0
		var watch_roles := 0
		for actor: Dictionary in profile["actor_plan"]:
			if actor["role"] == &"civilian":
				civilian_roles += 1
			elif actor["role"] == &"watch":
				watch_roles += 1
			else:
				fail("unknown generated population role: %s" % String(actor["role"]))
			assert_array_contains(profile["zone_ids"], actor["zone_id"])
			assert_eq(actor["movement_mode"], profile["movement_mode"])
			assert_eq(actor["anchor_mode"], profile["anchor_mode"])

		assert_eq(civilian_roles, context["expected_civilians"])
		assert_eq(watch_roles, context["expected_watch"])
		assert_eq(profile["total_count"], civilian_roles + watch_roles)
		assert_true(profile["civilian_count"] <= profile["civilian_cap"])
		assert_true(profile["watch_count"] <= profile["watch_cap"])
		assert_true(profile["total_count"] <= profile["actor_cap"])


func test_market_day_transition_only_changes_its_own_game_state_flag() -> void:
	var state := GameState.new()
	state.set_phase(PHASE_DAY)
	state.set_pressure(GameState.PRESSURE_SUSPICION, 2)
	state.set_pressure(GameState.PRESSURE_SOLIDARITY, 1)
	state.set_relationship(&"rel.r412", -1)
	state.set_fact(&"fact.r412.setup", true)
	var controller := ControllerScript.new()
	controller._state = state
	controller.bind_population_controller(PopulationProbe.new())

	controller.sync_for_test(PHASE_DAY, 2)

	assert_true(state.get_flag(FLAG_MARKET_DAY))
	assert_eq(state.get_phase(), PHASE_DAY)
	assert_eq(state.get_pressure(GameState.PRESSURE_SUSPICION), 2)
	assert_eq(state.get_pressure(GameState.PRESSURE_SOLIDARITY), 1)
	assert_eq(state.get_relationship(&"rel.r412"), -1)
	assert_true(state.get_fact(&"fact.r412.setup"))
	controller.free()
