extends "res://tests/godot/test_case.gd"

const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const PresenterScript := preload("res://tests/godot/dialogue_test_presenter.gd")

const VALID_DIR := "res://content/examples/valid"
const SUPPORT_DIR := "res://content/examples/support"
const DIALOGUE_ID := &"dialogue.relationship_memory.mart"
const MEMORY_HELPED := &"memory.mart.helped"
const MEMORY_IGNORED := &"memory.mart.ignored"
const MEMORY_BETRAYED := &"memory.mart.betrayed"
const MEMORY_APOLOGY := &"memory.mart.apology_offered"
const CHAR_MART := &"char.mart"
const LOC_LOWER_TOWN := &"loc.lower_town_slice"
const LOC_SMITHY := &"loc.kalev_smithy"

var db: ContentDB
var state: GameState
var evaluator: StateRuleEvaluator
var presenter: DialogueTestPresenter
var runner: DialogueRunner


func before_each() -> void:
	db = ContentDB.new()
	assert_true(db.load_from_directories([VALID_DIR, SUPPORT_DIR]))
	state = GameState.new()
	evaluator = StateRuleEvaluator.new()
	presenter = PresenterScript.new()
	runner = RunnerScript.new()
	runner.configure(db, state, presenter, evaluator)


func test_mart_opens_with_helped_memory_line() -> void:
	state.record_relationship_memory(MEMORY_HELPED)
	assert_true(runner.start(DIALOGUE_ID))
	assert_eq(presenter.last_node_id, "mart_helped_opening")
	assert_true(presenter.last_text.contains("carried water"))


func test_mart_opens_with_ignored_memory_line() -> void:
	state.record_relationship_memory(MEMORY_IGNORED)
	assert_true(runner.start(DIALOGUE_ID))
	assert_eq(presenter.last_node_id, "mart_ignored_opening")
	assert_true(presenter.last_text.contains("walked past"))


func test_ignored_memory_unlocks_apology_choice() -> void:
	state.record_relationship_memory(MEMORY_IGNORED)
	assert_true(runner.start(DIALOGUE_ID))
	runner.advance_for_test()
	assert_true(runner.is_waiting_for_choice())
	assert_true("apologize" in presenter.enabled_choice_ids())
	assert_true(runner.select_choice("apologize"))
	assert_true(state.has_relationship_memory(MEMORY_APOLOGY))


func test_record_memory_effect_and_condition_round_trip() -> void:
	var effects := [{"op": "record_memory", "key": String(MEMORY_BETRAYED)}]
	assert_true(evaluator.apply_effects(effects, state))
	assert_true(state.has_relationship_memory(MEMORY_BETRAYED))
	var condition := {"op": "memory_recorded", "key": String(MEMORY_BETRAYED)}
	assert_true(evaluator.evaluate_condition(condition, state))


func test_relationship_memories_survive_save_and_map_transition() -> void:
	state.record_relationship_memory(MEMORY_HELPED)
	state.player.location_id = LOC_LOWER_TOWN
	state.player.spawn_id = &"street_start"

	var payload := state.save_payload()
	state.player.location_id = LOC_SMITHY
	state.player.spawn_id = &"forge_yard"

	var restored := GameState.new()
	assert_eq(restored.load_payload(payload).size(), 0)
	assert_eq(restored.player.location_id, LOC_LOWER_TOWN)
	assert_true(restored.has_relationship_memory(MEMORY_HELPED))
	assert_eq(
		restored.get_relationship_memories_for_character(CHAR_MART),
		[MEMORY_HELPED]
	)


func test_mart_memory_keys_validate_character_namespace() -> void:
	assert_false(state.record_relationship_memory(&"memory.invalid"))
	assert_false(state.record_relationship_memory(&"memory.mart"))
	assert_true(state.record_relationship_memory(MEMORY_HELPED))
