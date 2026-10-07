extends "res://tests/godot/test_case.gd"

## ADR 0033 / SD-02: the dialogue runner exposes spirit-duel move tags.

const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const TestPresenterScript := preload("res://tests/godot/dialogue_test_presenter.gd")
const DUEL_ID := &"dialogue.test_duel"
const PLAIN_ID := &"dialogue.test_runner.intro"
const CONTENT_DIRS: Array[String] = [
	"res://content/examples/valid",
	"res://content/examples/support",
]


func test_duel_and_node_move_are_exposed() -> void:
	var runner := _runner()
	assert_true(runner.start(DUEL_ID))
	assert_eq(runner.get_duel().get("stakes"), ["respect", "secret"])
	assert_eq(runner.get_duel().get("resolution_node_ids"), ["yield", "stand"])
	var move: Dictionary = runner.get_current_move()
	assert_eq(move.get("kind"), "attack")
	assert_eq(move.get("element"), "shame")
	assert_eq(move.get("spirit_image_id"), "ledger_chain")


func test_choices_carry_their_move() -> void:
	var runner := _runner()
	var presenter: RefCounted = runner._presenter
	assert_true(runner.start(DUEL_ID))
	runner.advance_for_test()
	var kinds: Dictionary = {}
	for choice: Dictionary in presenter.last_choices:
		kinds[choice["id"]] = (choice["move"] as Dictionary).get("kind")
	assert_eq(kinds, {"deny": "defense", "confess": "appeal"})


func test_untagged_dialogue_has_no_move_or_duel() -> void:
	var runner := _runner()
	assert_true(runner.start(PLAIN_ID))
	assert_eq(runner.get_duel(), {})
	assert_eq(runner.get_current_move(), {})


func test_duel_clears_when_the_dialogue_closes() -> void:
	var runner := _runner()
	assert_true(runner.start(DUEL_ID))
	runner.advance_for_test()
	assert_true(runner.select_choice("confess"))
	runner.advance_for_test()
	assert_false(runner.is_active())
	assert_eq(runner.get_duel(), {})


func _runner() -> Node:
	var root := _make_root()
	var db := ContentDB.new()
	assert_true(db.load_from_directories(CONTENT_DIRS))
	var runner = RunnerScript.new()
	root.add_child(runner)
	runner.configure(db, GameState.new(), TestPresenterScript.new())
	return runner


func _make_root() -> Node:
	var root := Node.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	return root
