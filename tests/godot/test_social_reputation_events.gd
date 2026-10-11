extends "res://tests/godot/test_case.gd"

const ModelScript := preload("res://scripts/faction/social_reputation_model.gd")
const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const PresenterScript := preload("res://tests/godot/dialogue_test_presenter.gd")

const VALID_DIR := "res://content/examples/valid"
const SUPPORT_DIR := "res://content/examples/support"
const LOC_LOWER_TOWN := &"loc.lower_town_slice"
const FLAG_TRUSTED := &"flag.reputation.harju_kings_trusted"
const DIALOGUE_ID := &"dialogue.reputation.harju_kings_trusted"
const BARK_POOL := &"bark.reputation.harju_kings_trusted"

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


func test_reputation_event_fires_when_harju_kings_standing_reaches_threshold() -> void:
	assert_true(
		state.record_faction_event(
			&"ledger.makers_mark.preserve",
			FactionLedger.HARJU_KINGS,
			1,
			"Supported the yard once."
		)
	)
	assert_true(
		state.record_faction_event(
			&"ledger.bitter_brew.honest",
			FactionLedger.HARJU_KINGS,
			1,
			"Kept the brewery route honest."
		)
	)
	assert_eq(state.get_faction_standing(FactionLedger.HARJU_KINGS), 2)
	var pending := ModelScript.events_to_fire(state, LOC_LOWER_TOWN)
	assert_eq(pending.size(), 1)
	assert_eq(pending[0].get("bark_pool_id", &""), BARK_POOL)
	ModelScript.mark_fired(state, pending[0])
	assert_true(state.get_flag(FLAG_TRUSTED))
	assert_eq(ModelScript.events_to_fire(state, LOC_LOWER_TOWN).size(), 0)


func test_reputation_bark_resolves_after_event_fires() -> void:
	state.set_phase(GameState.PHASE_INVESTIGATION_MORNING)
	state.record_faction_event(
		&"ledger.makers_mark.preserve",
		FactionLedger.HARJU_KINGS,
		2,
		"Trusted by the yard."
	)
	var pending := ModelScript.events_to_fire(state, LOC_LOWER_TOWN)
	ModelScript.mark_fired(state, pending[0])
	var bark := runner.resolve_bark(BARK_POOL, state.get_phase(), LOC_LOWER_TOWN)
	assert_false(bark.is_empty())
	assert_true(String(bark.get("text", "")).contains("nod"))


func test_reputation_flag_gates_merchant_gossip_dialogue() -> void:
	assert_true(runner.start(DIALOGUE_ID))
	assert_eq(presenter.last_node_id, "merchant_default_opening")

	state.set_flag(FLAG_TRUSTED, true)
	assert_true(runner.start(DIALOGUE_ID))
	assert_eq(presenter.last_node_id, "merchant_rebel_gossip")
	assert_true(presenter.last_text.contains("cheer you"))


func test_reputation_flag_persists_across_save() -> void:
	state.set_flag(FLAG_TRUSTED, true)
	var payload := state.save_payload()
	var restored := GameState.new()
	assert_eq(restored.load_payload(payload).size(), 0)
	assert_true(restored.get_flag(FLAG_TRUSTED))
