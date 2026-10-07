extends "res://tests/godot/test_case.gd"

## ADR 0033 / SD-07: a physical blow opens guilt by circumstance and the guilt
## weakens spirit-duel replies and sharpens the opponent's blows.

const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const DUEL_ID := &"dialogue.test_duel"
const CONTENT_DIRS: Array[String] = [
	"res://content/examples/valid",
	"res://content/examples/support",
]


class FakeTarget:
	extends Node2D

	var context: Dictionary = {}
	var dead := false

	func guilt_context() -> Dictionary:
		return context

	func is_combat_dead() -> bool:
		return dead


func test_classify_by_circumstance() -> void:
	assert_eq(PhysicalBlowGuilt.classify({"animal": true, "aggressor": true}), &"")
	assert_eq(PhysicalBlowGuilt.classify({"aggressor": true}), &"act.self_defence")
	assert_eq(
		PhysicalBlowGuilt.classify({"aggressor": true, "defending_other": true}), &"act.defend_other"
	)
	assert_eq(PhysicalBlowGuilt.classify({"armed": false}), &"act.unarmed_victim")
	assert_eq(PhysicalBlowGuilt.classify({"armed": true}), &"act.provoked")


func test_blows_count_once_per_target_and_kill_adds_lethal_weight() -> void:
	var state := GameState.new()
	var target := FakeTarget.new()
	target.context = {"id": "watchman_1", "aggressor": false, "armed": true}
	var events := PhysicalBlowGuilt.record_hits(state, [target])
	assert_eq(events.size(), 1)
	assert_eq(state.guilt.level(&"guilt.church"), 2)
	assert_eq(PhysicalBlowGuilt.record_hits(state, [target]).size(), 0)
	assert_eq(state.guilt.level(&"guilt.church"), 2)
	target.dead = true
	var kill := PhysicalBlowGuilt.record_hits(state, [target])
	assert_eq(kill.size(), 1)
	assert_true(kill[0]["lethal"])
	assert_eq(state.guilt.level(&"guilt.church"), 5)
	assert_eq(state.guilt.level(&"guilt.folk"), 5)
	assert_eq(state.guilt.level(&"guilt.civic"), 3)
	assert_eq(PhysicalBlowGuilt.record_hits(state, [target]).size(), 0)
	target.free()


func test_self_defence_weighs_less_than_striking_the_unarmed() -> void:
	var defender := GameState.new()
	var victim := GameState.new()
	var guard := FakeTarget.new()
	guard.context = {"id": "guard", "aggressor": true}
	var beggar := FakeTarget.new()
	beggar.context = {"id": "beggar", "armed": false}
	PhysicalBlowGuilt.record_hits(defender, [guard])
	PhysicalBlowGuilt.record_hits(victim, [beggar])
	assert_eq(defender.guilt.level(&"guilt.folk"), 0)
	assert_true(victim.guilt.level(&"guilt.folk") >= 3)
	guard.free()
	beggar.free()


func test_targets_without_a_guilt_context_and_a_null_state_are_ignored() -> void:
	var state := GameState.new()
	var plain := Node2D.new()
	assert_eq(PhysicalBlowGuilt.record_hits(state, [plain]).size(), 0)
	assert_eq(PhysicalBlowGuilt.record_hits(null, [plain]).size(), 0)
	assert_eq(state.guilt.levels(), {&"guilt.church": 0, &"guilt.folk": 0, &"guilt.civic": 0})
	plain.free()


func test_a_real_strike_on_a_patrolling_guard_is_provoked_and_on_an_aggressor_is_self_defence() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var attacker := Node2D.new()
	tree.root.add_child(attacker)
	var calm := CombatRoomEnemy.new()
	calm.configure(EnemyArchetype.watchman(), Color.WHITE)
	calm.guilt_actor_id = &"calm_guard"
	tree.root.add_child(calm)
	calm.global_position = Vector2(10.0, 0.0)
	var angry := CombatRoomEnemy.new()
	angry.configure(EnemyArchetype.watchman(), Color.WHITE)
	angry.guilt_actor_id = &"angry_guard"
	tree.root.add_child(angry)
	angry.global_position = Vector2(0.0, 10.0)
	angry.machine.state = EnemyCombatState.State.CHASE

	var state := GameState.new()
	var hits := MeleeAttackResolver.strike(attacker, Vector2.RIGHT, 40.0, 0.5, 5.0)
	assert_eq(hits, [calm])
	var events := PhysicalBlowGuilt.record_hits(state, hits)
	assert_eq(events[0]["circumstance"], "act.provoked")
	var angry_hits := MeleeAttackResolver.strike(attacker, Vector2.DOWN, 40.0, 0.5, 5.0)
	assert_eq(angry_hits, [angry])
	assert_eq(PhysicalBlowGuilt.record_hits(state, angry_hits)[0]["circumstance"], "act.self_defence")
	for node: Node in [attacker, calm, angry]:
		node.free()


func test_multipliers_follow_school_tiers() -> void:
	var state := GameState.new()
	assert_eq(PhysicalBlowGuilt.reply_multiplier(state, &"fear"), 1.0)
	assert_eq(PhysicalBlowGuilt.incoming_multiplier(state), 1.0)
	state.guilt.record_act(&"act.a", &"act.unarmed_victim")
	# church 4, folk 3, civic 3 -> tier 2 in every school.
	assert_almost_eq(PhysicalBlowGuilt.reply_multiplier(state, &"fear"), 0.7, 0.001)
	assert_almost_eq(PhysicalBlowGuilt.reply_multiplier(state, &"duty"), 0.7, 0.001)
	assert_eq(PhysicalBlowGuilt.reply_multiplier(state, &"unknown_element"), 1.0)
	assert_almost_eq(PhysicalBlowGuilt.incoming_multiplier(state), 1.6, 0.001)


func test_guilt_weakens_replies_and_sharpens_blows_in_the_arena() -> void:
	var state := GameState.new()
	state.guilt.record_act(&"act.struck", &"act.unarmed_victim")
	var db := ContentDB.new()
	assert_true(db.load_from_directories(CONTENT_DIRS))
	var root := Node.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	var runner := RunnerScript.new()
	root.add_child(runner)
	var duel := SpiritDuel.new()
	duel.hero_id = &"char.mart"
	assert_true(duel.begin(runner, db, state, DUEL_ID))
	duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_almost_eq(duel.hero.health, SpiritDuel.COMPOSURE_MAX - 20.0 * 1.6, 0.001)
	assert_true(duel.answer("deny"))
	# defense counters attack (30), fear belongs to the folk school (tier 2 -> x0.7).
	assert_almost_eq(duel.opponent.health, SpiritDuel.PRESSURE_MAX - 30.0 * 0.7, 0.001)
