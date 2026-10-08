extends "res://tests/godot/test_case.gd"

## ADR 0038 / SA3D-4: duel topic multiplier and authored topic lines.

const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const DUEL := &"dialogue.test_duel_topic"
const CONTENT_DIRS: Array[String] = [
	"res://content/examples/valid",
	"res://content/examples/support",
]

var _duel: SpiritDuel


func before_each() -> void:
	super.before_each()
	var db := ContentDB.new()
	assert_true(db.load_from_directories(CONTENT_DIRS))
	var root := Node.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	var runner: Node = RunnerScript.new()
	root.add_child(runner)
	_duel = SpiritDuel.new()
	_duel.hero_id = &"char.mart"
	assert_true(_duel.begin(runner, db, GameState.new(), DUEL))


func test_multiplier_on_off_and_untagged() -> void:
	assert_eq(_duel.topic_multiplier({"topic_tags": ["theft"]}), SpiritDuel.TOPIC_ON)
	assert_eq(_duel.topic_multiplier({"topic_tags": ["weather"]}), SpiritDuel.TOPIC_OFF)
	assert_eq(_duel.topic_multiplier({"kind": "attack"}), 1.0)


func test_topic_line_prefers_best_overlap_and_is_deterministic() -> void:
	var line := _duel.topic_line_for(&"shame", ["iron"])
	assert_true(String(line.get("text", "")).begins_with("The ledger"))
	assert_eq(_duel.topic_line_for(&"shame", ["iron"]), line)
	assert_true(_duel.topic_line_for(&"coin", ["iron"]).is_empty())
