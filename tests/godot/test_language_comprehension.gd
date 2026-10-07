extends "res://tests/godot/test_case.gd"

## ADR 0033 / SD-08: foreign speech reaches the hero as imagery, fragments, then text.

const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const TestPresenterScript := preload("res://tests/godot/dialogue_test_presenter.gd")
const SettingsScript := preload("res://scripts/settings/dialogue_settings.gd")
const DIALOGUE := &"dialogue.test_language"
const GERMAN := &"lang.german"
const CONTENT_DIRS: Array[String] = [
	"res://content/examples/valid",
	"res://content/examples/support",
]

var _state: GameState
var _db: ContentDB
var _runner: Node


func before_each() -> void:
	super.before_each()
	_state = GameState.new()
	_db = ContentDB.new()
	assert_true(_db.load_from_directories(CONTENT_DIRS))
	var root := Node.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	_runner = RunnerScript.new()
	root.add_child(_runner)


func test_tiers_follow_comprehension_and_estonian_is_native() -> void:
	assert_eq(_state.language_tier(GERMAN), 0)
	assert_eq(_state.train_language(GERMAN, 10), 20)
	assert_eq(_state.language_tier(GERMAN), 1)
	assert_eq(_state.train_language(GERMAN, 30), 50)
	assert_eq(_state.language_tier(GERMAN), 2)
	_state.train_language(GERMAN, 99)
	assert_eq(_state.get_language_comprehension(GERMAN), 100)
	assert_eq(_state.language_tier(GERMAN), 3)
	assert_eq(_state.get_language_comprehension(&"lang.estonian"), 100)
	assert_eq(_state.train_language(&"lang.estonian", 5), -1)
	assert_eq(_state.train_language(&"lang.klingon", 5), -1)


func test_render_by_tier_and_accessibility_override() -> void:
	var node: Dictionary = _db.get_dialogue(DIALOGUE)["nodes"][0]
	var text := String(node["text"])
	assert_eq(DialogueLanguage.render(node, text, _state, false), node["imagery"])
	_state.train_language(GERMAN, 10)
	assert_eq(DialogueLanguage.render(node, text, _state, false), node["gist"])
	_state.train_language(GERMAN, 30)
	assert_eq(DialogueLanguage.render(node, text, _state, false), text)
	var fresh := GameState.new()
	assert_eq(DialogueLanguage.render(node, text, fresh, true), text)
	assert_eq(DialogueLanguage.render({"text": "Tere"}, "Tere", fresh, false), "Tere")


func test_runner_shows_imagery_then_the_real_line() -> void:
	var presenter: RefCounted = TestPresenterScript.new()
	_runner.configure(_db, _state, presenter)
	assert_true(_runner.start(DIALOGUE))
	assert_true(String(presenter.last_text).begins_with("[A heavy voice"))
	assert_false(_runner.current_speech_readable())
	_state.train_language(GERMAN, 40)
	assert_true(_runner.start(DIALOGUE))
	assert_eq(presenter.last_text, "Du bezahlst mir das Eisen, oder du gehst.")
	assert_true(_runner.current_speech_readable())


func test_a_reply_needs_comprehension() -> void:
	var presenter: RefCounted = TestPresenterScript.new()
	_runner.configure(_db, _state, presenter)
	assert_true(_runner.start(DIALOGUE))
	_runner.advance_for_test()
	assert_eq(presenter.enabled_choice_ids(), ["stay_silent"])
	var blocked: Dictionary = {}
	for choice: Dictionary in presenter.last_choices:
		if choice["id"] == "answer_back":
			blocked = choice
	assert_false(String(blocked["disabled_reason"]).is_empty())
	assert_false(_runner.select_choice("answer_back"))
	_state.train_language(GERMAN, 40)
	assert_true(_runner.start(DIALOGUE))
	_runner.advance_for_test()
	assert_eq(presenter.enabled_choice_ids(), ["answer_back", "stay_silent"])


func test_the_arena_hides_the_element_of_a_blow_in_an_unknown_tongue() -> void:
	var duel := SpiritDuel.new()
	duel.hero_id = &"char.mart"
	var shown: Array[Dictionary] = []
	duel.line_presented.connect(
		func(_speaker: StringName, _text: String, move: Dictionary) -> void: shown.append(move)
	)
	assert_true(duel.begin(_runner, _db, _state, DIALOGUE))
	assert_eq(shown[0], {"kind": "pressure"})
	_state.train_language(GERMAN, 40)
	assert_true(duel.begin(_runner, _db, _state, DIALOGUE))
	assert_eq(shown[1].get("element"), "coin")


func test_observing_an_unknown_tongue_teaches_nothing() -> void:
	var watch := SpiritObservation.new()
	assert_true(watch.begin(_runner, _db, _state, DIALOGUE))
	var outcome := watch.play_all()
	assert_eq(outcome["moves_learned"], [])
	assert_false(_state.knows_move(&"move.pressure.coin"))
	_state.train_language(GERMAN, 40)
	var again := SpiritObservation.new()
	assert_true(again.begin(_runner, _db, _state, DIALOGUE))
	assert_eq(again.play_all()["moves_learned"], [&"move.pressure.coin"])


func test_comprehension_saves_and_legacy_saves_load() -> void:
	_state.train_language(GERMAN, 45)
	var restored := GameState.new()
	assert_eq(restored.load_payload(_state.save_payload()), [])
	assert_eq(restored.get_language_comprehension(GERMAN), 55)
	var legacy := GameState.new().save_payload()
	legacy.erase("language_comprehension")
	var fresh := GameState.new()
	assert_eq(fresh.load_payload(legacy), [])
	assert_eq(fresh.get_language_comprehension(GERMAN), 10)
	var corrupt := GameState.new().save_payload()
	corrupt["language_comprehension"] = {"lang.klingon": 40}
	assert_true(GameState.new().load_payload(corrupt).size() > 0)


func test_always_translate_setting_round_trips() -> void:
	var settings = SettingsScript.default_settings()
	assert_false(settings.always_translate)
	settings.always_translate = true
	var restored = SettingsScript.from_dict(settings.to_dict())
	assert_true(restored.always_translate)
	assert_true(settings.duplicate_settings().always_translate)
	assert_false(SettingsScript.from_dict({}).always_translate)
