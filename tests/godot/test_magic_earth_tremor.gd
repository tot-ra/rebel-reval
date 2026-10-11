extends "res://tests/godot/test_case.gd"

const CONTENT_DIRS: Array[String] = [
	"res://content/examples/valid",
	"res://content/examples/support",
]
const TREMOR := &"spell.pagan.earth_tremor"
const GRANT_TREMOR := &"magic.grant.starter_earth_tremor"
const EARTH: Array[StringName] = [&"element.earth"]
const CAST_EXECUTOR := preload("res://scripts/magic/magic_cast_executor_2d.gd")
const DUMMY_SCRIPT := preload("res://scripts/combat/combat_training_dummy.gd")
const ENEMY_SCRIPT := preload("res://scripts/combat/combat_room_enemy.gd")


func test_earth_tremor_pulses_radius_filters_targets_and_spends_willpower() -> void:
	var db := ContentDB.new()
	assert_true(db.load_from_directories(CONTENT_DIRS))
	var state := GameState.new()
	state.set_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER, 1)
	assert_true(MagicResolver.apply_grant_operation(state, db, GRANT_TREMOR))

	var result := MagicResolver.cast(state, db, &"", EARTH)
	assert_true(result["ok"])
	assert_eq(result["target_id"], TREMOR)
	assert_eq(state.get_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER), 0)
	var effect: Dictionary = result["effect"]
	assert_eq(effect["delivery"]["kind"], "area_pulse")
	assert_eq(effect["delivery"]["radius"], 96.0)
	assert_eq(effect["impact"]["kind"], "stagger")
	assert_eq(effect["impact"]["duration_sec"], 1.5)

	var tree := Engine.get_main_loop() as SceneTree
	var host := Node2D.new()
	tree.root.add_child(host)
	var caster := _add_dummy(host, Vector2.ZERO)
	var inside := _add_dummy(host, Vector2(72.0, 0.0))
	var edge := _add_dummy(host, Vector2(96.0, 0.0))
	var outside := _add_dummy(host, Vector2(97.0, 0.0))
	var friendly := _add_dummy(host, Vector2(24.0, 0.0))
	friendly.hostile_to_source = false

	var pulse := CAST_EXECUTOR.execute(result, caster, Vector2.RIGHT, host)
	assert_true(pulse != null)
	assert_false(caster.is_staggered(), "caster must be excluded")
	assert_true(inside.is_staggered(), "target inside radius must stagger")
	assert_true(edge.is_staggered(), "radius boundary must be included")
	assert_false(outside.is_staggered(), "target outside radius must be ignored")
	assert_false(friendly.is_staggered(), "non-hostile target must be ignored")

	inside._process(0.5)
	assert_almost_eq(inside.stagger_remaining_sec(), 1.0, 0.01)
	inside._process(1.1)
	assert_false(inside.is_staggered(), "stagger must expire after its duration")
	host.free()


## Real AI hosts, not only the dummy: the pulse must cancel a telegraphed
## attack, hold REACT for the authored window, then let the enemy re-engage.
func test_earth_tremor_interrupts_enemy_attack_and_holds_react() -> void:
	var result := _cast_tremor()
	var tree := Engine.get_main_loop() as SceneTree
	var host := Node2D.new()
	tree.root.add_child(host)
	var player := Node2D.new()
	host.add_child(player)
	var enemy := _add_enemy(host, Vector2(40.0, 0.0), player)
	var impacts: Array[int] = [0]
	enemy.get_machine().attack_impact.connect(func() -> void: impacts[0] += 1)
	_drive_to_state(enemy, player, EnemyCombatState.State.TELEGRAPH, 4.0)
	assert_eq(enemy.get_machine().state, EnemyCombatState.State.TELEGRAPH)

	CAST_EXECUTOR.execute(result, player, Vector2.RIGHT, host)
	assert_true(enemy.is_staggered(), "enemy inside radius must stagger")
	assert_eq(enemy.get_machine().state, EnemyCombatState.State.REACT)
	assert_eq(enemy.view_animation(), &"hit")

	# Hold the whole window even when it outlasts the archetype react beat.
	var archetype := enemy.get_machine().archetype
	assert_true(archetype.react_duration_sec < 1.5, "fixture needs stagger > react beat")
	_step(enemy, player, 1.4)
	assert_eq(enemy.get_machine().state, EnemyCombatState.State.REACT)
	assert_eq(impacts[0], 0, "a staggered enemy must not land its attack")
	_step(enemy, player, 0.2)
	assert_false(enemy.is_staggered())
	assert_true(
		enemy.get_machine().state != EnemyCombatState.State.REACT,
		"enemy must re-engage once the stagger expires"
	)
	host.free()


func test_overlapping_staggers_keep_longer_window_and_dead_enemies_are_skipped() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var host := Node2D.new()
	tree.root.add_child(host)
	var player := Node2D.new()
	host.add_child(player)
	var enemy := _add_enemy(host, Vector2(30.0, 0.0), player)
	enemy.apply_stagger(1.5)
	_step(enemy, player, 1.0)
	enemy.apply_stagger(0.2)
	assert_almost_eq(enemy.stagger_remaining_sec(), 0.5, 0.01, "shorter recast must not shorten")
	enemy.apply_stagger(1.0)
	assert_almost_eq(enemy.stagger_remaining_sec(), 1.0, 0.01, "longer recast refreshes, no sum")

	var corpse := _add_enemy(host, Vector2(50.0, 0.0), player)
	corpse.take_damage(999.0, player, &"test", 1, true)
	assert_true(corpse.is_combat_dead())
	var pulse := MagicAreaPulse2D.new()
	host.add_child(pulse)
	assert_true(pulse.configure(player, &"spell.test", 96.0, {"kind": "stagger", "duration_sec": 1.0}))
	var affected := pulse.pulse()
	assert_true(affected.has(enemy))
	assert_false(affected.has(corpse), "dead hosts must not be reported as affected")
	assert_false(corpse.is_staggered())
	assert_eq(corpse.get_machine().state, EnemyCombatState.State.DEAD)
	host.free()


func test_reset_clears_stagger() -> void:
	var enemy := ENEMY_SCRIPT.new() as CombatRoomEnemy
	enemy.configure(EnemyArchetype.watchman(), Color.WHITE)
	enemy.apply_stagger(2.0)
	assert_true(enemy.is_staggered())
	enemy.reset_actor()
	assert_false(enemy.is_staggered())
	assert_eq(enemy.get_machine().state, EnemyCombatState.State.PATROL)
	enemy.free()


func _cast_tremor() -> Dictionary:
	var db := ContentDB.new()
	assert_true(db.load_from_directories(CONTENT_DIRS))
	var state := GameState.new()
	state.set_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER, 1)
	assert_true(MagicResolver.apply_grant_operation(state, db, GRANT_TREMOR))
	var result := MagicResolver.cast(state, db, &"", EARTH)
	assert_true(result["ok"])
	return result


func _add_enemy(host: Node2D, position: Vector2, target: Node2D) -> CombatRoomEnemy:
	var enemy := ENEMY_SCRIPT.new() as CombatRoomEnemy
	host.add_child(enemy)
	enemy.configure(EnemyArchetype.watchman(), Color.WHITE)
	enemy.global_position = position
	enemy.set_ai_target(target)
	return enemy


func _drive_to_state(
	enemy: CombatRoomEnemy, target: Node2D, desired: EnemyCombatState.State, budget_sec: float
) -> void:
	var elapsed := 0.0
	while elapsed < budget_sec and enemy.get_machine().state != desired:
		enemy.tick_ai(0.05, target)
		elapsed += 0.05


func _step(enemy: CombatRoomEnemy, target: Node2D, seconds: float) -> void:
	var steps := int(round(seconds / 0.05))
	for _i in steps:
		enemy.tick_ai(0.05, target)


func _add_dummy(host: Node2D, position: Vector2) -> CombatTestDummy:
	var dummy := DUMMY_SCRIPT.new() as CombatTestDummy
	host.add_child(dummy)
	dummy.global_position = position
	return dummy
