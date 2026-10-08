extends "res://tests/godot/test_case.gd"

## ADR 0038 / SA3D-2: real-time footwork in the 3D arena, strike zones, guard facing, the
## position-aware hit check in SpiritDuel, and the host keeping the world live.

const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const DUEL_ID := &"dialogue.test_duel"
const CONTENT_DIRS: Array[String] = [
	"res://content/examples/valid",
	"res://content/examples/support",
]

var _root: Node3D
var _arena: SpiritArena3D
var _db: ContentDB


func before_each() -> void:
	super.before_each()
	await _tree().process_frame
	_root = Node3D.new()
	_tree().root.add_child(_root)
	_arena = SpiritArena3D.new()
	_arena.open(_root, Vector3.ZERO, [], false, 9.0)
	_db = ContentDB.new()
	assert_true(_db.load_from_directories(CONTENT_DIRS))


func after_each() -> void:
	if _arena != null and is_instance_valid(_arena) and _arena.is_open():
		_arena.close()
	_root.free()
	_tree().paused = false
	super.after_each()


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _motion(opponent_at: Vector3) -> SpiritArenaMotion:
	var motion := SpiritArenaMotion.new(_arena)
	motion.hero_position = Vector3.ZERO
	motion.opponent_position = opponent_at
	return motion


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func test_line_kind_picks_the_footwork() -> void:
	var motion := _motion(Vector3(0, 0, -5))
	motion.set_line({"kind": "attack"})
	assert_eq(motion.behaviour, SpiritArenaMotion.BEHAVIOUR_ADVANCE)
	motion.set_line({"kind": "defense"})
	assert_eq(motion.behaviour, SpiritArenaMotion.BEHAVIOUR_RETREAT)
	motion.set_line({"kind": "feint"})
	assert_eq(motion.behaviour, SpiritArenaMotion.BEHAVIOUR_CIRCLE)
	motion.set_line({"kind": "appeal"})
	assert_eq(motion.behaviour, SpiritArenaMotion.BEHAVIOUR_HOLD)
	motion.set_line({})
	assert_eq(motion.behaviour, SpiritArenaMotion.BEHAVIOUR_CIRCLE)


func test_advance_stops_close_and_retreat_stops_far() -> void:
	var motion := _motion(Vector3(0, 0, -5))
	motion.set_line({"kind": "attack"})
	for i in 60:
		motion.step(0.1)
	assert_almost_eq(_flat_distance(motion.opponent_position, Vector3.ZERO), SpiritArenaMotion.CLOSE_DISTANCE, 0.001)  # gdlint: ignore=max-line-length
	motion.set_line({"kind": "defense"})
	for i in 60:
		motion.step(0.1)
	assert_almost_eq(_flat_distance(motion.opponent_position, Vector3.ZERO), SpiritArenaMotion.FAR_DISTANCE, 0.001)  # gdlint: ignore=max-line-length


func test_circle_keeps_distance_and_moves_round() -> void:
	var motion := _motion(Vector3(0, 0, -4))
	motion.set_line({"kind": "feint"})
	motion.step(0.5)
	assert_almost_eq(_flat_distance(motion.opponent_position, Vector3.ZERO), 4.0, 0.001)
	assert_true(absf(motion.opponent_position.x) > 0.5, "moved round the hero")


func test_opponent_stays_on_the_disc() -> void:
	var motion := _motion(Vector3(0, 0, -8.5))
	motion.hero_position = Vector3(0, 0, 3)
	motion.set_line({"kind": "defense"})
	for i in 100:
		motion.step(0.1)
	assert_true(_arena.contains(motion.opponent_position))


func test_opponent_holds_while_a_blow_is_wound_up() -> void:
	var motion := _motion(Vector3(0, 0, -5))
	motion.set_line({"kind": "attack"})
	motion.lock_zone({"kind": "attack"})
	motion.step(1.0)
	assert_eq(motion.opponent_position, Vector3(0, 0, -5))


func test_attack_arc_is_left_by_a_sidestep() -> void:
	var motion := _motion(Vector3(0, 0, -4))
	var zone := motion.lock_zone({"kind": "attack", "element": "shame"})
	assert_eq(zone["shape"], SpiritArenaMotion.SHAPE_ARC)
	assert_true(motion.in_zone(Vector3.ZERO))
	assert_true(motion.in_zone(Vector3(0, 0, 1.2)), "stepping straight back stays in reach")
	assert_false(motion.in_zone(Vector3(0, 0, 2.0)), "past the reach")
	assert_false(motion.in_zone(Vector3(4.0, 0, -2.0)), "within reach but out of the arc to the side")


func test_pressure_circle_is_left_by_stepping_off_the_spot() -> void:
	var motion := _motion(Vector3(0, 0, -4))
	motion.hero_position = Vector3(1, 0, 1)
	var zone := motion.lock_zone({"kind": "pressure"})
	assert_eq(zone["shape"], SpiritArenaMotion.SHAPE_CIRCLE)
	assert_true(motion.in_zone(Vector3(1, 0, 1)))
	assert_false(motion.in_zone(Vector3(1, 0, 1 + 2.5)))
	motion.clear_zone()
	assert_false(motion.in_zone(Vector3(1, 0, 1)))


func test_guard_counts_only_facing_the_opponent() -> void:
	var motion := _motion(Vector3(0, 0, -4))
	motion.hero_facing = Vector3.FORWARD
	assert_true(motion.guard_facing())
	motion.hero_facing = Vector3.RIGHT
	assert_false(motion.guard_facing())
	motion.hero_facing = Vector3.BACK
	assert_false(motion.guard_facing())


func test_motion_is_deterministic() -> void:
	var runs: Array[Vector3] = []
	for run in 2:
		var motion := _motion(Vector3(2, 0, -5))
		for kind: String in ["attack", "feint", "defense", "feint"]:
			motion.set_line({"kind": kind})
			for i in 7:
				motion.step(0.13)
		runs.append(motion.opponent_position)
	assert_eq(runs[0], runs[1])


func _duel_with(check: Callable) -> SpiritDuel:
	var runner := RunnerScript.new()
	_root.add_child(runner)
	var duel := SpiritDuel.new()
	duel.hero_id = &"char.mart"
	duel.hit_check = check
	assert_true(duel.begin(runner, _db, GameState.new(), DUEL_ID))
	return duel


func test_out_of_zone_blow_misses_without_resolve_cost() -> void:
	var duel := _duel_with(func(_move: Dictionary) -> Dictionary: return {"in_zone": false, "guard_facing": false})  # gdlint: ignore=max-line-length
	var outcomes: Array = []
	duel.exchange_resolved.connect(func(result: Dictionary) -> void: outcomes.append(result))
	duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_eq(duel.hero.health, SpiritDuel.COMPOSURE_MAX)
	assert_eq(duel.hero.stamina, SpiritDuel.RESOLVE_MAX)
	assert_eq(outcomes[0]["outcome"], CombatHitResult.OUTCOME_INVULNERABLE)
	assert_false(outcomes[0]["in_zone"])


func test_guard_turned_away_does_not_block() -> void:
	var duel := _duel_with(func(_move: Dictionary) -> Dictionary: return {"in_zone": true, "guard_facing": false})  # gdlint: ignore=max-line-length
	duel.set_guard(true)
	duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_eq(duel.hero.health, SpiritDuel.COMPOSURE_MAX - 20.0)


func test_guard_facing_in_zone_still_guards() -> void:
	var duel := _duel_with(func(_move: Dictionary) -> Dictionary: return {"in_zone": true, "guard_facing": true})  # gdlint: ignore=max-line-length
	var outcomes: Array = []
	duel.exchange_resolved.connect(func(result: Dictionary) -> void: outcomes.append(result))
	duel.set_guard(true)
	duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_eq(outcomes[0]["outcome"], CombatHitResult.OUTCOME_GUARDED)


func test_host_real_time_arena_keeps_world_live_and_clamps_hero() -> void:
	_arena.close()
	_arena = null
	var hero := Node3D.new()
	_root.add_child(hero)
	var opponent := Node3D.new()
	_root.add_child(opponent)
	opponent.position = Vector3(0, 0, -5)
	var host := SpiritArenaHost.new()
	_tree().root.add_child(host)
	assert_true(host.attach_arena(_root, Vector3.ZERO, [hero, opponent], true, hero, opponent))
	assert_false(host.freeze_world)
	assert_true(host.open(_db, GameState.new(), DUEL_ID))
	assert_false(_tree().paused, "world keeps running")
	for node: Node in _tree().get_nodes_in_group(&"modal_input_overlay"):
		assert_false(host.is_ancestor_of(node), "locomotion is not blocked")
	assert_true(host.telegraph_decal().visible, "the opening blow is drawn on the floor")
	hero.global_position = Vector3(20, 0, 0)
	host._process(0.1)
	assert_almost_eq(hero.global_position.x, host.arena_3d.radius, 0.001)
	# Step out of the arc before impact: the blow misses.
	hero.global_position = Vector3(6, 0, 0)
	host._process(SpiritDuel.TELEGRAPH_SEC)
	assert_eq(host.duel.hero.health, SpiritDuel.COMPOSURE_MAX)
	assert_false(host.telegraph_decal().visible)
	host.close()
	assert_true(host.duel.hit_check.is_null())
	assert_true(host.freeze_world, "detach restores the freeze flag")
	host.free()
