extends "res://tests/godot/test_case.gd"

## ADR 0033 / SD-06: observing other people's conflicts as spirit duels.

const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const QUARREL := &"dialogue.prologue.almshouse_quarrel"
const PLAIN := &"dialogue.test_runner.intro"
const MATRON := &"char.almshouse_matron"
const CONTENT_DIRS: Array[String] = [
	"res://content/prologue",
	"res://content/examples/valid",
	"res://content/examples/support",
]

var _state: GameState
var _db: ContentDB
var _runner: Node
var _watch: SpiritObservation


func before_each() -> void:
	super.before_each()
	_state = GameState.new()
	_db = ContentDB.new()
	assert_true(_db.load_from_directories(CONTENT_DIRS))
	var root := Node.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	_runner = RunnerScript.new()
	root.add_child(_runner)
	_watch = SpiritObservation.new()


func test_move_ids_are_stable_strings() -> void:
	assert_eq(SpiritObservation.move_id({"kind": "attack", "element": "shame"}), &"move.attack.shame")
	assert_eq(SpiritObservation.move_id({}), &"")


func test_watching_teaches_each_move_once() -> void:
	assert_true(_watch.begin(_runner, _db, _state, QUARREL))
	var outcome := _watch.play_all()
	assert_true(_watch.is_over())
	assert_eq(outcome["resolution_node_id"], "porter_yields")
	assert_eq(
		outcome["moves_learned"],
		[&"move.attack.duty", &"move.feint.shame", &"move.pressure.fear"]
	)
	assert_true(_state.knows_move(&"move.pressure.fear"))
	var again := SpiritObservation.new()
	assert_true(again.begin(_runner, _db, _state, QUARREL))
	assert_eq(again.play_all()["moves_learned"], [])
	assert_eq(again.play_all()["moves_seen"].size(), 3)


func test_learned_moves_survive_save_and_load() -> void:
	assert_true(_watch.begin(_runner, _db, _state, QUARREL))
	_watch.play_all()
	var restored := GameState.new()
	assert_eq(restored.load_payload(_state.save_payload()), [])
	assert_eq(restored.get_learned_moves(), _state.get_learned_moves())
	var legacy := GameState.new().save_payload()
	legacy.erase("learned_moves")
	assert_eq(GameState.new().load_payload(legacy), [])


func test_intervention_sides_once_and_only_with_a_participant() -> void:
	assert_true(_watch.begin(_runner, _db, _state, QUARREL))
	assert_false(_watch.intervene(&"char.someone_else"))
	_watch.step()
	assert_true(_watch.intervene(MATRON))
	assert_false(_watch.intervene(&"char.almshouse_porter"))
	assert_true(_state.get_flag(SpiritObservation.intervention_flag(QUARREL, MATRON)))
	assert_eq(_watch.play_all()["intervened_for"], "char.almshouse_matron")
	assert_false(_watch.intervene(MATRON))


func test_each_beat_reports_the_move_seen() -> void:
	var seen: Array[String] = []
	_watch.move_seen.connect(
		func(speaker: StringName, move: Dictionary, _new: bool) -> void:
			seen.append("%s:%s" % [speaker, move.get("kind")])
	)
	assert_true(_watch.begin(_runner, _db, _state, QUARREL))
	_watch.play_all()
	assert_eq(seen.size(), 3)
	assert_eq(seen[0], "char.almshouse_matron:attack")
	assert_eq(seen[1], "char.almshouse_porter:feint")


func test_a_plain_dialogue_cannot_be_observed() -> void:
	assert_false(_watch.begin(_runner, _db, _state, PLAIN))
	assert_true(_watch.is_over())
	assert_false(_watch.step())


func test_host_observes_freezes_the_world_and_reports_the_outcome() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var host := SpiritArenaHost.new()
	tree.root.add_child(host)
	var closed: Array[Dictionary] = []
	host.closed.connect(func(outcome: Dictionary) -> void: closed.append(outcome))
	assert_true(host.observe(_db, _state, QUARREL))
	assert_true(tree.paused and host.is_open() and host.visible)
	assert_false(host.observe(_db, _state, QUARREL))
	host.observation.play_all()
	host.close()
	assert_false(tree.paused)
	assert_eq(closed.size(), 1)
	assert_eq(closed[0]["moves_learned"].size(), 3)
	host.free()
