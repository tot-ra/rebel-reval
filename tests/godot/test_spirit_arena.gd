extends "res://tests/godot/test_case.gd"

## ADR 0033 / SD-04: spirit duel model on the dialogue runner and combat vitals.

const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const DUEL_ID := &"dialogue.test_duel"
const PLAIN_ID := &"dialogue.test_runner.intro"
const CONTENT_DIRS: Array[String] = [
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
	_duel.hero_id = &"char.mart"


func test_begin_telegraphs_the_opening_blow() -> void:
	assert_true(_duel.begin(_runner, _db, _state, DUEL_ID))
	assert_eq(_duel.phase, SpiritDuel.PHASE_TELEGRAPH)
	assert_eq(_duel.incoming_move().get("kind"), "attack")
	assert_true(_duel.checkpoint.is_armed)


func test_a_plain_dialogue_is_not_a_duel() -> void:
	assert_false(_duel.begin(_runner, _db, _state, PLAIN_ID))
	assert_true(_duel.is_over())


func test_open_blow_hurts_then_counter_reply_wins() -> void:
	assert_true(_duel.begin(_runner, _db, _state, DUEL_ID))
	_duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_eq(_duel.hero.health, SpiritDuel.COMPOSURE_MAX - 20.0)
	assert_eq(_duel.phase, SpiritDuel.PHASE_ANSWER)
	assert_true(_duel.answer("deny"))
	# defense counters attack: 30 pressure, no element match (fear vs shame).
	assert_eq(_duel.opponent.health, SpiritDuel.PRESSURE_MAX - 30.0)
	assert_eq(_duel.phase, SpiritDuel.PHASE_WON)
	assert_eq(_duel.last_outcome["resolution_node_id"], "stand")
	assert_false(_duel.checkpoint.is_armed)


func test_well_timed_guard_parries_and_returns_pressure() -> void:
	assert_true(_duel.begin(_runner, _db, _state, DUEL_ID))
	_duel.tick(SpiritDuel.TELEGRAPH_SEC - 0.1)
	_duel.set_guard(true)
	_duel.tick(0.11)
	assert_eq(_duel.hero.health, SpiritDuel.COMPOSURE_MAX)
	assert_eq(_duel.opponent.health, SpiritDuel.PRESSURE_MAX - SpiritDuel.PARRY_RETURN_PRESSURE)
	assert_eq(_duel.phase, SpiritDuel.PHASE_ANSWER)


func test_early_guard_holds_but_costs_resolve() -> void:
	assert_true(_duel.begin(_runner, _db, _state, DUEL_ID))
	_duel.set_guard(true)
	_duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_eq(_duel.hero.health, SpiritDuel.COMPOSURE_MAX)
	assert_true(_duel.hero.stamina < SpiritDuel.RESOLVE_MAX)


func test_dodge_avoids_the_blow_once_and_costs_resolve() -> void:
	assert_true(_duel.begin(_runner, _db, _state, DUEL_ID))
	assert_true(_duel.dodge())
	assert_false(_duel.dodge())
	_duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_eq(_duel.hero.health, SpiritDuel.COMPOSURE_MAX)
	assert_eq(_duel.hero.stamina, SpiritDuel.RESOLVE_MAX - SpiritDuel.DODGE_RESOLVE_COST)


func test_resonant_appeal_resolves_to_the_other_ending() -> void:
	assert_true(_duel.begin(_runner, _db, _state, DUEL_ID))
	_duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_true(_duel.answer("confess"))
	assert_eq(_duel.last_outcome["resolution_node_id"], "yield")
	assert_eq(_duel.opponent.health, SpiritDuel.PRESSURE_MAX - SpiritDuel.REPLY_NEUTRAL)


func test_reply_damage_table() -> void:
	var attack := {"kind": "attack", "element": "shame"}
	assert_eq(SpiritDuel.reply_damage({"kind": "defense", "element": "fear"}, attack), 30.0)
	assert_eq(SpiritDuel.reply_damage({"kind": "defense", "element": "shame"}, attack), 38.0)
	assert_eq(SpiritDuel.reply_damage({"kind": "feint", "element": "fear"}, attack), 4.0)
	assert_eq(SpiritDuel.reply_damage({"kind": "appeal", "element": "love"}, attack), 12.0)
	assert_eq(SpiritDuel.reply_damage({}, attack), 0.0)


func test_losing_restores_the_checkpoint_and_retry_restarts() -> void:
	_state.set_flag(&"flag.before_duel", true)
	assert_true(_duel.begin(_runner, _db, _state, DUEL_ID))
	_state.set_flag(&"flag.mid_duel", true)
	_duel.hero.health = 5.0
	_duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_eq(_duel.phase, SpiritDuel.PHASE_LOST)
	assert_true(_duel.is_over())
	assert_true(_duel.retry())
	assert_false(_state.get_flag(&"flag.mid_duel"))
	assert_true(_state.get_flag(&"flag.before_duel"))
	assert_eq(_duel.phase, SpiritDuel.PHASE_TELEGRAPH)
	assert_eq(_duel.hero.health, SpiritDuel.COMPOSURE_MAX)


func test_actions_outside_their_phase_are_ignored() -> void:
	assert_false(_duel.dodge())
	assert_false(_duel.answer("deny"))
	assert_false(_duel.acknowledge())
	assert_true(_duel.begin(_runner, _db, _state, DUEL_ID))
	assert_false(_duel.answer("deny"))


func test_host_freezes_the_world_and_restores_it_on_close() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var host := SpiritArenaHost.new()
	host.duel.hero_id = &"char.mart"
	tree.root.add_child(host)
	var closed: Array[Dictionary] = []
	host.closed.connect(func(outcome: Dictionary) -> void: closed.append(outcome))
	assert_false(tree.paused)
	assert_true(host.open(_db, _state, DUEL_ID))
	assert_true(host.is_open())
	assert_true(tree.paused)
	assert_true(host.visible)
	host.duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_true(host.duel.answer("confess"))
	assert_eq(host.duel.phase, SpiritDuel.PHASE_WON)
	host.close()
	assert_false(tree.paused)
	assert_false(host.is_open())
	assert_eq(closed.size(), 1)
	assert_eq(closed[0]["resolution_node_id"], "yield")
	host.free()


func test_host_refuses_a_dialogue_that_is_not_a_duel() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var host := SpiritArenaHost.new()
	tree.root.add_child(host)
	assert_false(host.open(_db, _state, PLAIN_ID))
	assert_false(host.is_open())
	assert_false(tree.paused)
	host.free()
