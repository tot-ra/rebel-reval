extends "res://tests/godot/test_case.gd"

## ADR 0033 / SD-05: the almshouse prologue records play through the dialogue
## runner and the spirit duel, and write their flags.

const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const TestPresenterScript := preload("res://tests/godot/dialogue_test_presenter.gd")
const QUARREL := &"dialogue.prologue.almshouse_quarrel"
const CONFRONT := &"dialogue.prologue.porter_confrontation"
const KALEV := &"dialogue.prologue.kalev_arrives"
const CONTENT_DIRS: Array[String] = [
	"res://content/prologue",
	"res://content/examples/valid",
	"res://content/examples/support",
]

var _state: GameState
var _db: ContentDB
var _runner: Node
var _duel: SpiritDuel


func before_each() -> void:
	super.before_each()
	_state = GameState.new()
	_db = ContentDB.new()
	assert_true(_db.load_from_directories(CONTENT_DIRS))
	var root := Node.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	_runner = RunnerScript.new()
	root.add_child(_runner)
	_duel = SpiritDuel.new()
	# Duel replies are spells, so the hero needs the starter magic and willpower.
	for grant_id: StringName in AlmshouseOpening.STARTER_GRANTS:
		MagicResolver.apply_grant_operation(_state, _db, grant_id)
	_state.set_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER, 8)


func test_cast_and_dialogues_are_loaded() -> void:
	for dialogue_id: StringName in [QUARREL, CONFRONT, KALEV]:
		assert_false(_db.get_dialogue(dialogue_id).is_empty(), String(dialogue_id))


func test_observed_quarrel_reaches_its_resolution() -> void:
	var presenter: RefCounted = TestPresenterScript.new()
	_runner.configure(_db, _state, presenter)
	assert_true(_runner.start(QUARREL))
	assert_eq(_runner.get_current_move().get("kind"), "attack")
	for i in 3:
		_runner.advance_for_test()
	assert_eq(_runner.get_current_node_id(), "porter_yields")
	assert_true(_runner.get_duel().get("resolution_node_ids").has("porter_yields"))


func test_mercy_path_spares_the_hero() -> void:
	assert_true(_duel.begin(_runner, _db, _state, CONFRONT))
	_duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_true(_duel.answer("still_hunger"))
	_duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_true(_duel.answer("still_duty"))
	_duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_true(_duel.answer("still_mercy"))
	assert_eq(_duel.last_outcome["resolution_node_id"], "resolved_spared")
	assert_false(_state.get_flag(&"flag.prologue.struck_porter"))


func test_fire_path_breaks_the_porter() -> void:
	assert_true(_duel.begin(_runner, _db, _state, CONFRONT))
	for choice_id in ["fire_hands", "fire_lock", "fire_secret"]:
		_duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
		assert_true(_duel.answer(choice_id), choice_id)
	assert_eq(_duel.last_outcome["resolution_node_id"], "resolved_broken")
	assert_true(_state.get_flag(&"flag.prologue.broke_porter"))


func test_spell_replies_spend_willpower_and_stop_when_it_runs_out() -> void:
	_state.set_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER, 1)
	assert_true(_duel.begin(_runner, _db, _state, CONFRONT))
	_duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_false(_duel.answer("fire_hands"))
	assert_eq(_duel.phase, SpiritDuel.PHASE_ANSWER)
	assert_true(_duel.answer("still_hunger"), "earth tremor costs 1")


func test_silence_is_punished_and_flagged() -> void:
	assert_true(_duel.begin(_runner, _db, _state, CONFRONT))
	_duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_true(_duel.answer("ward_rod"))
	_duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_true(_duel.answer("say_nothing"))
	assert_eq(_duel.last_outcome["resolution_node_id"], "resolved_punished")
	assert_true(_state.get_flag(&"flag.prologue.punished_by_porter"))


func test_the_physical_option_ends_the_duel_and_marks_the_blow() -> void:
	assert_true(_duel.begin(_runner, _db, _state, CONFRONT))
	_duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_true(_duel.answer("shove"))
	assert_eq(_duel.last_outcome["resolution_node_id"], "resolved_struck")
	assert_true(_state.get_flag(&"flag.prologue.struck_porter"))


func test_kalev_takes_the_apprentice() -> void:
	var presenter: RefCounted = TestPresenterScript.new()
	_runner.configure(_db, _state, presenter)
	assert_true(_runner.start(KALEV))
	_runner.advance_for_test()
	assert_true(_runner.select_choice("stare"))
	assert_true(_state.get_flag(&"flag.prologue.apprenticed"))
