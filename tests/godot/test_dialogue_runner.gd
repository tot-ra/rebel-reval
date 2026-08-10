extends "res://tests/godot/test_case.gd"

const PresenterScript := preload("res://scripts/dialogue/dialogue_presenter.gd")
const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const TestPresenterScript := preload("res://tests/godot/dialogue_test_presenter.gd")

class _BarkTestPresenter:
	extends Node

	var showing := false

	func show_bark(
		_feedback: Dictionary,
		_anchor: Node2D = null,
		_view_runtime: Node = null,
		_duration_sec: float = 3.2
	) -> bool:
		showing = true
		return true

const INTRO_ID := &"dialogue.test_runner.intro"
const FOLLOWUP_ID := &"dialogue.test_runner.followup"
const BARK_ID := &"bark.prologue.watch_pressure"
const WAKE_BARK_ID := &"bark.prologue.wake_up_room"
const FLAG_TRUSTED := &"flag.test_runner_trusted"
const FLAG_DOUBTED := &"flag.test_runner_doubted"
const FACT_WARNING := &"fact.test_runner_warning_heard"
const PHASE_PROLOGUE := &"phase.prologue_day"
const LOC_SMITHY := &"loc.kalev_smithy"
const FLAG_INCIDENT := &"flag.prologue_maker_mark_incident"

const CONTENT_DIRS: Array[String] = [
	"res://content/examples/valid",
	"res://content/examples/support",
]


func test_intro_choice_sets_trusted_flag_and_followup_reaches_once_node() -> void:
	var root := _make_root()
	var presenter: RefCounted = TestPresenterScript.new()
	var db := ContentDB.new()
	assert_true(db.load_from_directories(CONTENT_DIRS))

	var state := GameState.new()
	var runner = RunnerScript.new()
	root.add_child(runner)
	runner.configure(db, state, presenter)

	assert_true(runner.start(INTRO_ID))
	assert_true(runner.is_active())
	assert_eq(presenter.last_speaker, "Mart")
	runner.advance_for_test()
	assert_eq(presenter.enabled_choice_ids(), ["trust_mart", "doubt_mart"])

	assert_true(runner.select_choice("trust_mart"))
	assert_false(runner.is_waiting_for_choice())
	assert_true(state.get_flag(FLAG_TRUSTED))
	assert_false(state.get_flag(FLAG_DOUBTED))

	runner.advance_for_test()
	assert_false(runner.is_active())
	assert_true(presenter.closed)

	assert_true(runner.start(FOLLOWUP_ID))
	assert_eq(presenter.last_text, "You came back. I kept the name you asked about.")
	runner.advance_for_test()
	assert_eq(presenter.last_text, "This warning only lands once.")
	assert_true(state.get_fact(FACT_WARNING))
	assert_true(state.has_dialogue_node_seen(FOLLOWUP_ID, "trusted_once"))

	runner.advance_for_test()
	assert_false(runner.is_active())

	assert_true(runner.start(FOLLOWUP_ID))
	assert_eq(presenter.last_text, "You came back. I kept the name you asked about.")
	runner.advance_for_test()
	assert_false(runner.is_active())
	assert_true(state.get_fact(FACT_WARNING))

	_cleanup_node(root)


func test_followup_requires_prior_branch_state() -> void:
	var root := _make_root()
	var presenter: RefCounted = TestPresenterScript.new()
	var db := ContentDB.new()
	assert_true(db.load_from_directories(CONTENT_DIRS))

	var state := GameState.new()
	var runner = RunnerScript.new()
	root.add_child(runner)
	runner.configure(db, state, presenter)

	assert_false(runner.start(FOLLOWUP_ID))

	state.set_flag(FLAG_TRUSTED, true)
	assert_true(runner.start(FOLLOWUP_ID))
	_cleanup_node(root)


func test_doubt_branch_sets_doubt_flag_without_trusted_followup() -> void:
	var root := _make_root()
	var presenter: RefCounted = TestPresenterScript.new()
	var db := ContentDB.new()
	assert_true(db.load_from_directories(CONTENT_DIRS))

	var state := GameState.new()
	var runner = RunnerScript.new()
	root.add_child(runner)
	runner.configure(db, state, presenter)

	assert_true(runner.start(INTRO_ID))
	runner.advance_for_test()
	assert_true(runner.select_choice("doubt_mart"))
	assert_true(state.get_flag(FLAG_DOUBTED))
	assert_false(state.get_flag(FLAG_TRUSTED))

	state.set_flag(FLAG_TRUSTED, false)
	assert_false(runner.start(FOLLOWUP_ID))
	_cleanup_node(root)


func test_resolve_bark_returns_first_valid_entry_for_phase_and_location() -> void:
	var db := ContentDB.new()
	assert_true(db.load_from_directories(CONTENT_DIRS))

	var state := GameState.new()
	var runner = RunnerScript.new()
	runner.configure(db, state, PresenterScript.new())

	var fallback := runner.resolve_bark(BARK_ID, PHASE_PROLOGUE, LOC_SMITHY)
	assert_eq(String(fallback.get("entry_id", "")), "watch_mutter")
	assert_eq(String(fallback.get("text", "")), "Every mark has an owner.")

	state.set_flag(FLAG_INCIDENT, true)
	var priority := runner.resolve_bark(BARK_ID, PHASE_PROLOGUE, LOC_SMITHY)
	assert_eq(String(priority.get("entry_id", "")), "ledger_waiting")
	assert_eq(String(priority.get("text", "")), "The ledger, smith. Before the bell.")


func test_play_bark_does_not_change_active_blocking_dialogue() -> void:
	var root := _make_root()
	var presenter: RefCounted = TestPresenterScript.new()
	var db := ContentDB.new()
	assert_true(db.load_from_directories(CONTENT_DIRS))

	var state := GameState.new()
	var runner = RunnerScript.new()
	root.add_child(runner)
	runner.configure(db, state, presenter)

	assert_true(runner.start(INTRO_ID))
	var active_node := runner.get_current_node_id()
	var bark_presenter := _BarkTestPresenter.new()
	root.add_child(bark_presenter)
	assert_true(runner.play_bark(WAKE_BARK_ID, bark_presenter, null, null, PHASE_PROLOGUE, LOC_SMITHY))
	assert_true(bark_presenter.showing)
	assert_eq(runner.get_current_node_id(), active_node)
	assert_true(runner.is_active())
	assert_false(runner.is_waiting_for_choice())
	_cleanup_node(root)


func test_dialogue_nodes_seen_round_trip_in_game_state_payload() -> void:
	var state := GameState.new()
	state.mark_dialogue_node_seen(FOLLOWUP_ID, "trusted_once")

	var restored := GameState.new()
	assert_eq(restored.load_payload(state.save_payload()).size(), 0)
	assert_true(restored.has_dialogue_node_seen(FOLLOWUP_ID, "trusted_once"))


func _make_root() -> Node:
	var root := Node.new()
	(_tree().root as Node).add_child(root)
	return root


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _cleanup_node(node: Node) -> void:
	if is_instance_valid(node):
		node.free()


func test_localization_resolves_line_choice_and_bark_text_with_inline_fallback() -> void:
	var db := ContentDB.new()
	assert_true(db.load_from_directories(CONTENT_DIRS))
	var localization = preload("res://scripts/dialogue/dialogue_localization.gd").new()
	localization.add_catalog("en", {
		"dialogue.test_runner.intro.mart_opens": "Localized greeting.",
		"dialogue.test_runner.intro.trust_mart": "Localized trust choice.",
		"bark.prologue.wake_up_room.henning_stew_comment": "Localized bark.",
	})
	var presenter: RefCounted = TestPresenterScript.new()
	var runner = RunnerScript.new()
	runner.configure(db, GameState.new(), presenter, null, localization)
	assert_true(runner.start(INTRO_ID))
	assert_eq(presenter.last_text, "Localized greeting.")
	runner.advance_for_test()
	assert_eq(presenter.last_choices[0]["text"], "Localized trust choice.")
	var bark := runner.resolve_bark(WAKE_BARK_ID, PHASE_PROLOGUE, LOC_SMITHY)
	assert_eq(String(bark.get("text", "")), "Localized bark.")


func test_localization_falls_back_to_inline_text_for_missing_key() -> void:
	var localization = preload("res://scripts/dialogue/dialogue_localization.gd").new()
	localization.add_catalog("en", {"known": "Translated"})
	assert_eq(localization.resolve("missing", "Authored fallback"), "Authored fallback")
	assert_eq(localization.resolve("missing"), "")
