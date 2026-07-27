extends "res://tests/godot/test_case.gd"

const ModelScript := preload("res://scripts/world/market_day_model.gd")
const ControllerScript := preload("res://scripts/world/market_day_controller.gd")
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
