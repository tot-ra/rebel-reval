extends "res://tests/godot/test_case.gd"

const PLAYER_SCENE := preload("res://player.tscn")
const COMBAT_TEST_DUMMY := preload("res://tests/godot/fixtures/combat_test_dummy.gd")
const TEST_DELTA := 0.05


func test_damage_clamps_health_and_notifies_death() -> void:
	var vitals := CombatVitals.new()
	vitals.configure(10.0, 10.0, 20.0, 20.0)
	var deaths := [0]
	vitals.died.connect(func() -> void: deaths[0] += 1)

	var result := vitals.resolve_hit(25.0, CombatDefensePose.open(), 1)
	assert_eq(result.outcome, CombatHitResult.OUTCOME_HIT)
	assert_eq(result.health_damage, 10.0, "Damage must clamp to remaining health")
	assert_eq(vitals.health, 0.0)
	assert_true(result.died)
	assert_eq(deaths[0], 1, "Death must notify exactly once")

	var again := vitals.resolve_hit(5.0, CombatDefensePose.open(), 2)
	assert_eq(again.outcome, CombatHitResult.OUTCOME_IGNORED)
	assert_eq(deaths[0], 1, "Already-dead actors must not re-emit died")


func test_hit_invulnerability_window_blocks_follow_up_damage() -> void:
	var vitals := CombatVitals.new()
	vitals.configure(40.0, 40.0, 20.0, 20.0)
	vitals.hit_invulnerability_sec = 0.2

	var first := vitals.resolve_hit(8.0, CombatDefensePose.open(), 10)
	assert_eq(first.health_damage, 8.0)
	assert_true(vitals.is_hit_invulnerable())

	var blocked := vitals.resolve_hit(8.0, CombatDefensePose.open(), 11)
	assert_eq(blocked.outcome, CombatHitResult.OUTCOME_INVULNERABLE)
	assert_eq(blocked.health_damage, 0.0)
	assert_eq(vitals.health, 32.0)

	vitals.tick(0.25)
	var after := vitals.resolve_hit(5.0, CombatDefensePose.open(), 12)
	assert_eq(after.outcome, CombatHitResult.OUTCOME_HIT)
	assert_eq(vitals.health, 27.0)


func test_guarded_hit_drains_stamina_instead_of_health() -> void:
	var vitals := CombatVitals.new()
	vitals.configure(50.0, 50.0, 30.0, 30.0)
	var pose := CombatDefensePose.open()
	pose.is_guarding = true
	pose.guard_elapsed_sec = 1.0

	var result := vitals.resolve_hit(12.0, pose, 20)
	assert_eq(result.outcome, CombatHitResult.OUTCOME_GUARDED)
	assert_eq(result.health_damage, 0.0)
	assert_eq(result.stamina_damage, 12.0)
	assert_eq(vitals.health, 50.0)
	assert_eq(vitals.stamina, 18.0)


func test_guard_break_spills_overflow_to_health() -> void:
	var vitals := CombatVitals.new()
	vitals.configure(40.0, 40.0, 5.0, 30.0)
	var pose := CombatDefensePose.open()
	pose.is_guarding = true
	pose.guard_elapsed_sec = 1.0

	var result := vitals.resolve_hit(12.0, pose, 21)
	assert_eq(result.outcome, CombatHitResult.OUTCOME_GUARDED)
	assert_eq(result.stamina_damage, 5.0)
	assert_eq(result.health_damage, 7.0, "Uncovered damage after stamina break must hit health")
	assert_eq(vitals.stamina, 0.0)
	assert_eq(vitals.health, 33.0)


func test_parry_window_negates_damage_on_early_guard() -> void:
	var vitals := CombatVitals.new()
	vitals.configure(40.0, 40.0, 25.0, 25.0)
	var pose := CombatDefensePose.open()
	pose.is_guarding = true
	pose.guard_elapsed_sec = 0.05
	pose.parry_window_sec = 0.18

	var result := vitals.resolve_hit(15.0, pose, 30)
	assert_eq(result.outcome, CombatHitResult.OUTCOME_PARRIED)
	assert_eq(result.health_damage, 0.0)
	assert_eq(result.stamina_damage, 0.0)
	assert_eq(vitals.health, 40.0)
	assert_eq(vitals.stamina, 25.0)


func test_same_swing_id_cannot_damage_twice() -> void:
	var vitals := CombatVitals.new()
	vitals.configure(40.0, 40.0, 20.0, 20.0)
	vitals.hit_invulnerability_sec = 0.0

	var first := vitals.resolve_hit(6.0, CombatDefensePose.open(), 99)
	assert_eq(first.health_damage, 6.0)
	var duplicate := vitals.resolve_hit(6.0, CombatDefensePose.open(), 99)
	assert_eq(duplicate.outcome, CombatHitResult.OUTCOME_IGNORED)
	assert_eq(duplicate.health_damage, 0.0)
	assert_eq(vitals.health, 34.0, "One swing id must never apply twice")


func test_dodge_pose_is_invulnerable_for_shared_actors() -> void:
	var dummy = COMBAT_TEST_DUMMY.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(dummy)
	dummy.set_dodging(true)
	assert_eq(dummy.take_damage(9.0, null, &"blunt", 40), 0.0)
	assert_eq(dummy.health, 20.0)
	assert_eq(dummy.last_result.outcome, CombatHitResult.OUTCOME_INVULNERABLE)
	dummy.free()


func test_player_guard_and_parry_use_shared_vitals() -> void:
	var player := _create_player()
	player.health = 80.0
	player.stamina = 40.0
	player.action_state_machine.set_guard_held(true)
	assert_eq(player.action_state_machine.state, PlayerActionState.State.GUARD)

	# Fresh guard is inside the parry window.
	assert_eq(player.take_damage(10.0, null, &"blunt", 50), 0.0)
	assert_eq(player.health, 80.0)
	assert_eq(player.last_hit_result().outcome, CombatHitResult.OUTCOME_PARRIED)
	assert_eq(player.action_state_machine.state, PlayerActionState.State.GUARD, "Parry must not force hit stun")

	# Advance past parry window while still guarding.
	_advance_machine(player.action_state_machine, player.combat_vitals.parry_window_sec + 0.05)
	player.combat_vitals.tick(player.combat_vitals.hit_invulnerability_sec + 0.05)
	assert_eq(player.take_damage(10.0, null, &"blunt", 51), 0.0)
	assert_eq(player.last_hit_result().outcome, CombatHitResult.OUTCOME_GUARDED)
	assert_eq(player.health, 80.0)
	assert_eq(player.stamina, 30.0, "Guarded hits must spend stamina")
	player.free()


func test_player_death_signal_and_dodge_invulnerability() -> void:
	var player := _create_player()
	var deaths := [0]
	player.died.connect(func() -> void: deaths[0] += 1)
	player.health = 4.0
	assert_eq(player.take_damage(10.0, null, &"blunt", 60), 4.0)
	assert_eq(player.health, 0.0)
	assert_true(player.is_combat_dead())
	assert_eq(deaths[0], 1)

	player.free()
	player = _create_player()
	player.health = 50.0
	assert_true(player.action_state_machine.try_start_action(PlayerActionKind.Kind.DODGE))
	assert_eq(player.take_damage(12.0, null, &"blunt", 61), 0.0)
	assert_eq(player.health, 50.0)
	assert_eq(player.last_hit_result().outcome, CombatHitResult.OUTCOME_INVULNERABLE)
	player.free()


func test_melee_swing_id_prevents_duplicate_hit_on_dummy() -> void:
	var attacker := _create_player()
	attacker.global_position = Vector2.ZERO
	attacker._facing_direction = Vector2.RIGHT
	var dummy = COMBAT_TEST_DUMMY.new()
	dummy.global_position = Vector2(32.0, 0.0)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(dummy)

	var hits := MeleeAttackResolver.strike(
		attacker,
		Vector2.RIGHT,
		48.0,
		0.35,
		8.0,
		&"blunt"
	)
	assert_eq(hits.size(), 1)
	assert_eq(dummy.health, 12.0)
	assert_eq(dummy.hit_count, 1)

	# Re-apply the same swing id through take_damage directly.
	var swing_id: int = dummy.last_result.swing_id
	assert_true(swing_id > 0)
	assert_eq(dummy.take_damage(8.0, attacker, &"blunt", swing_id), 0.0)
	assert_eq(dummy.hit_count, 1)
	assert_eq(dummy.health, 12.0)

	dummy.free()
	attacker.free()


func _create_player() -> Player:
	if not SessionState.content_db.is_loaded():
		assert_true(SessionState.content_db.load_from_directories(SessionState.DEMO_CONTENT_DIRS))
	if SessionState.state == null:
		SessionState.state = GameState.new()
		SessionState.state.bag.set_content_db(SessionState.content_db)
	SessionState.state.bag.set_content_db(SessionState.content_db)
	var player := PLAYER_SCENE.instantiate() as Player
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(player)
	return player


func _advance_machine(machine: PlayerActionStateMachine, duration_sec: float) -> void:
	var remaining := duration_sec + TEST_DELTA
	while remaining > 0.0:
		var step := minf(TEST_DELTA, remaining)
		machine.tick(step)
		remaining -= step
