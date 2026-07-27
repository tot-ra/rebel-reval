extends "res://tests/godot/test_case.gd"

const ModelScript := preload("res://scripts/world/market_day_model.gd")
const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const PresenterScript := preload("res://tests/godot/dialogue_test_presenter.gd")

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
