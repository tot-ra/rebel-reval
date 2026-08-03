extends "res://tests/godot/test_case.gd"

const ModelScript := preload("res://scripts/world/market_day_model.gd")
const ControllerScript := preload("res://scripts/world/market_day_controller.gd")
const ProfileScript := preload("res://scripts/world/urban_population_profile.gd")
const LowerTownSlice := preload(
	"res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd"
)
const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const PresenterScript := preload("res://tests/godot/dialogue_test_presenter.gd")
const INNKEEPER_RIG := preload("res://assets/characters/variants/innkeeper.tscn")

const VALID_DIR := "res://content/examples/valid"
const SUPPORT_DIR := "res://content/examples/support"
const DIALOGUE_ID := &"dialogue.merchant.market_day"
const FLAG_MARKET_DAY := &"flag.market_day_active"


class PopulationProbe:
	extends RefCounted

	const PopulationProfileScript := preload("res://scripts/world/urban_population_profile.gd")

	var received_states: Array[bool] = []
	var profile_snapshots: Array[Dictionary] = []

	func set_market_day_active(active: bool) -> void:
		received_states.append(active)
		var date := {
			"day": 24 if active else 22,
			"month": 4,
			"year": 1343,
		}
		var snapshot := PopulationProfileScript.market_day(
			GameState.PHASE_INVESTIGATION_MORNING,
			date,
			0
		) if active else PopulationProfileScript.day(
			GameState.PHASE_INVESTIGATION_MORNING,
			date,
			0
		)
		profile_snapshots.append(snapshot)

	func record_signal(active: bool) -> void:
		received_states.append(active)


var db: ContentDB
var state: GameState
var presenter: DialogueTestPresenter
var runner: DialogueRunner


func before_each() -> void:
	db = ContentDB.new()
	assert_true(db.load_from_directories([VALID_DIR, SUPPORT_DIR]))
	state = GameState.new()
	presenter = PresenterScript.new()
	runner = RunnerScript.new()
	runner.configure(db, state, presenter)


func test_game_calendar_weekday_index_matches_julian_1343() -> void:
	var sunday := {"day": 21, "month": 4, "year": 1343}
	var wednesday := {"day": 24, "month": 4, "year": 1343}
	assert_eq(GameCalendar.weekday_index(sunday), 6)
	assert_eq(GameCalendar.weekday_index(wednesday), 2)


func test_market_day_model_flags_wednesday_and_saturday_only() -> void:
	assert_false(ModelScript.is_market_day({"day": 22, "month": 4, "year": 1343}))
	assert_true(ModelScript.is_market_day({"day": 24, "month": 4, "year": 1343}))
	assert_true(ModelScript.is_market_day({"day": 27, "month": 4, "year": 1343}))


func test_market_day_model_syncs_flag_from_phase_and_elapsed_days() -> void:
	state.set_phase(GameState.PHASE_INVESTIGATION_MORNING)
	assert_false(ModelScript.sync_flag(state, state.get_phase(), 0))
	assert_false(state.get_flag(FLAG_MARKET_DAY))
	assert_true(ModelScript.sync_flag(state, state.get_phase(), 2))
	assert_true(state.get_flag(FLAG_MARKET_DAY))


func test_market_day_dialogue_offers_herring_only_on_market_day() -> void:
	state.set_phase(GameState.PHASE_INVESTIGATION_MORNING)
	assert_true(runner.start(DIALOGUE_ID))
	assert_eq(presenter.last_node_id, "merchant_off_day_opening")
	runner.advance_for_test()
	assert_false("buy_herring" in presenter.enabled_choice_ids())

	state.set_flag(FLAG_MARKET_DAY, true)
	assert_true(runner.start(DIALOGUE_ID))
	assert_eq(presenter.last_node_id, "merchant_market_day_opening")
	runner.advance_for_test()
	assert_true("buy_herring" in presenter.enabled_choice_ids())


func test_market_day_herring_choice_records_fact() -> void:
	state.set_flag(FLAG_MARKET_DAY, true)
	assert_true(runner.start(DIALOGUE_ID))
	runner.advance_for_test()
	assert_true(runner.select_choice("buy_herring"))
	assert_true(state.get_fact(&"fact.market_day.sampled_herring"))


func test_market_day_bridge_notifies_population_only_when_calendar_state_changes() -> void:
	var controller := ControllerScript.new()
	var probe := PopulationProbe.new()
	controller._state = state
	controller.bind_population_controller(probe)
	controller.market_day_changed.connect(probe.record_signal)
	controller.sync_for_test(GameState.PHASE_INVESTIGATION_MORNING, 0)
	assert_eq(probe.received_states, [false], "Binding must provide the current off-day snapshot")
	controller.sync_for_test(GameState.PHASE_INVESTIGATION_MORNING, 2)
	assert_eq(probe.received_states, [false, true, true], "Population receives the market-day update and signal")
	controller.sync_for_test(GameState.PHASE_INVESTIGATION_MORNING, 2)
	assert_eq(probe.received_states, [false, true, true], "Repeated sync on one date must not duplicate the update")
	controller.sync_for_test(GameState.PHASE_INVESTIGATION_MORNING, 3)
	assert_eq(probe.received_states, [false, true, true, false, false], "Off-day transition reaches population and signal")
	controller.free()


func test_market_day_bridge_builds_market_merchant_and_customer_activity_without_keeper_duplication() -> void:
	var controller := ControllerScript.new()
	var probe := PopulationProbe.new()
	state.set_phase(GameState.PHASE_INVESTIGATION_MORNING)
	state.set_pressure(GameState.PRESSURE_SUSPICION, 2)
	state.set_pressure(GameState.PRESSURE_SOLIDARITY, 1)
	state.set_pressure(GameState.PRESSURE_SCARCITY, 3)
	state.set_relationship(&"rel.market_day_test", 1)
	state.set_fact(&"fact.market_day.test_setup", true)
	var unrelated_state_before := {
		"phase": state.get_phase(),
		"suspicion": state.get_pressure(GameState.PRESSURE_SUSPICION),
		"solidarity": state.get_pressure(GameState.PRESSURE_SOLIDARITY),
		"scarcity": state.get_pressure(GameState.PRESSURE_SCARCITY),
		"relationship": state.get_relationship(&"rel.market_day_test"),
		"fact": state.get_fact(&"fact.market_day.test_setup"),
	}
	controller._state = state
	controller.bind_population_controller(probe)
	controller.market_day_changed.connect(probe.record_signal)
	controller.sync_for_test(GameState.PHASE_INVESTIGATION_MORNING, 0)
	assert_false(state.get_flag(FLAG_MARKET_DAY))
	controller.sync_for_test(GameState.PHASE_INVESTIGATION_MORNING, 2)
	assert_true(state.get_flag(FLAG_MARKET_DAY))
	assert_eq(
		probe.received_states,
		[false, true, true],
		"The population bridge must receive the off-day snapshot and market-day transition"
	)

	var off_day: Dictionary = probe.profile_snapshots[0]
	var market_day: Dictionary = probe.profile_snapshots[1]
	assert_eq(probe.profile_snapshots.size(), 2)
	assert_eq(off_day["profile_id"], ProfileScript.PROFILE_DAY)
	assert_eq(market_day["profile_id"], ProfileScript.PROFILE_MARKET_DAY)
	assert_true(
		int(market_day["civilian_count"]) > int(off_day["civilian_count"]),
		"Market day must increase civilian population over an off-day"
	)
	assert_eq(market_day["civilian_policy"], &"market_day_trade_and_delivery")
	assert_eq(market_day["movement_mode"], ProfileScript.MOVEMENT_ROUTE_BETWEEN_ZONES)
	assert_array_contains(market_day["zone_ids"], ProfileScript.ZONE_MARKET)
	assert_false(
		market_day["occupation_mix"].has(&"keeper"),
		"The authored stall keeper must not be part of the generated crowd"
	)

	var market_merchants := 0
	var market_customers := 0
	var actor_plan: Array[Dictionary] = market_day["actor_plan"]
	for actor: Dictionary in actor_plan:
		assert_ne(actor["role"], &"keeper")
		assert_ne(actor["occupation"], &"keeper")
		if actor["role"] != &"civilian" or actor["zone_id"] != ProfileScript.ZONE_MARKET:
			continue
		if actor["occupation"] == &"merchant":
			market_merchants += 1
		else:
			# The profile has no separate customer role: non-merchant civilians
			# represent customer traffic in the market activity zone.
			market_customers += 1
	assert_eq(actor_plan.size(), market_day["total_count"])
	assert_true(market_merchants > 0, "Market lane must receive merchant activity")
	assert_true(market_customers > 0, "Market lane must receive customer activity")

	assert_eq(state.get_phase(), unrelated_state_before["phase"])
	assert_eq(state.get_pressure(GameState.PRESSURE_SUSPICION), unrelated_state_before["suspicion"])
	assert_eq(state.get_pressure(GameState.PRESSURE_SOLIDARITY), unrelated_state_before["solidarity"])
	assert_eq(state.get_pressure(GameState.PRESSURE_SCARCITY), unrelated_state_before["scarcity"])
	assert_eq(state.get_relationship(&"rel.market_day_test"), unrelated_state_before["relationship"])
	assert_eq(state.get_fact(&"fact.market_day.test_setup"), unrelated_state_before["fact"])
	controller.free()


func test_market_stall_has_visible_keeper_with_talk_sensor() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var root := Node2D.new()
	tree.root.add_child(root)
	var actors := Node2D.new()
	actors.name = "Actors"
	root.add_child(actors)
	var runtime := MapViewRuntime.new()
	runtime._definition = LowerTownSlice.create()
	runtime.view = MapView3D.new()
	runtime.view.definition = runtime._definition
	runtime._actor_controller.configure(
		runtime,
		runtime._definition,
		null,
		null,
		runtime.view,
		Callable(),
		Callable()
	)
	root.add_child(runtime)
	var controller := ControllerScript.new()
	root.add_child(controller)
	controller._scene_root = root
	controller._definition = runtime._definition
	controller._view_runtime = runtime
	controller._view_binder = InteractableViewBinder.new()
	controller._view_binder.setup(null, controller._definition)
	controller.add_child(controller._view_binder)

	controller._spawn_merchant_interactable()

	var keeper := controller.get_stall_keeper()
	var stall_position := MapVerification.prop_position(
		controller._definition,
		ModelScript.MERCHANT_PROP_ID
	)
	assert_true(keeper != null, "The market stall must have a visible keeper")
	assert_true(keeper.get_parent() == actors, "The keeper must live in the map Actors layer")
	assert_eq(
		keeper.global_position,
		stall_position + ControllerScript.KEEPER_STALL_OFFSET,
		"The keeper must stand beside the stall rather than inside its footprint"
	)
	assert_true(keeper.is_in_group(&"map_view_actor"))
	assert_true(keeper.rig_scene == INNKEEPER_RIG)
	var rig := runtime.get_actor_rig(keeper)
	assert_true(rig != null, "Late-spawned keeper must have a visible 3D rig")
	assert_eq(rig.name, &"MarketStallKeeperRig")
	var talk := controller.get_merchant_interactable()
	assert_true(talk != null)
	assert_true(talk.get_parent() == keeper, "Talk focus must track the visible keeper")
	assert_eq(talk.global_position, keeper.global_position)
	root.free()
