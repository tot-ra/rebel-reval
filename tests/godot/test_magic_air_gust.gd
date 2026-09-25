extends "res://tests/godot/test_case.gd"

const CONTENT_DIRS: Array[String] = [
	"res://content/examples/valid",
	"res://content/examples/support",
]
const GUST := &"spell.pagan.air_gust"
const GRANT_GUST := &"magic.grant.starter_air_gust"
const AIR: Array[StringName] = [&"element.air"]
const CAST_EXECUTOR := preload("res://scripts/magic/magic_cast_executor_2d.gd")
const DUMMY_SCRIPT := preload("res://scripts/combat/combat_training_dummy.gd")
const ENEMY_SCRIPT := preload("res://scripts/combat/combat_room_enemy.gd")
const GUST_DISTANCE := 96.0


func test_air_gust_cone_filters_targets_pushes_away_and_spends_willpower() -> void:
	var db := ContentDB.new()
	assert_true(db.load_from_directories(CONTENT_DIRS))
	var state := GameState.new()
	state.set_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER, 1)
	var locked := MagicResolver.cast(state, db, &"", AIR)
	assert_false(locked["ok"], "air gust must stay locked until explicitly granted")
	assert_true(MagicResolver.apply_grant_operation(state, db, GRANT_GUST))

	var result := MagicResolver.cast(state, db, &"", AIR)
	assert_true(result["ok"])
	assert_eq(result["target_id"], GUST)
	assert_eq(state.get_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER), 0)
	var effect: Dictionary = result["effect"]
	assert_eq(effect["delivery"]["kind"], "area_pulse")
	assert_eq(effect["delivery"]["arc_deg"], 90.0)
	assert_eq(effect["impact"]["kind"], "knockback")

	var tree := Engine.get_main_loop() as SceneTree
	var host := Node2D.new()
	tree.root.add_child(host)
	var caster := _add_dummy(host, Vector2.ZERO)
	var ahead := _add_dummy(host, Vector2(60.0, 0.0))
	var cone_edge := _add_dummy(host, Vector2.from_angle(deg_to_rad(45.0)) * 80.0)
	var off_cone := _add_dummy(host, Vector2.from_angle(deg_to_rad(50.0)) * 80.0)
	var behind := _add_dummy(host, Vector2(-40.0, 0.0))
	var radius_edge := _add_dummy(host, Vector2(112.0, 0.0))
	var outside := _add_dummy(host, Vector2(113.0, 0.0))
	var friendly := _add_dummy(host, Vector2(30.0, 0.0))
	friendly.hostile_to_source = false

	var pulse := CAST_EXECUTOR.execute(result, caster, Vector2.RIGHT, host)
	assert_true(pulse != null)
	assert_false(caster.is_knocked_back(), "caster must be excluded")
	assert_true(ahead.is_knocked_back(), "target ahead inside the cone must be pushed")
	assert_true(cone_edge.is_knocked_back(), "cone edge must be included")
	assert_true(radius_edge.is_knocked_back(), "radius boundary must be included")
	assert_false(off_cone.is_knocked_back(), "target outside the arc must be ignored")
	assert_false(behind.is_knocked_back(), "target behind the caster must be ignored")
	assert_false(outside.is_knocked_back(), "target outside radius must be ignored")
	assert_false(friendly.is_knocked_back(), "non-hostile target must be ignored")
	assert_true(ahead.is_staggered(), "knockback must hold the target in react")

	var edge_start := cone_edge.global_position
	ahead._process(CombatKnockbackEffect.SLIDE_SEC)
	cone_edge._process(CombatKnockbackEffect.SLIDE_SEC)
	assert_almost_eq(ahead.global_position.x, 60.0 + GUST_DISTANCE, 0.01)
	assert_almost_eq(ahead.global_position.y, 0.0, 0.01)
	assert_almost_eq(
		cone_edge.global_position.distance_to(edge_start), GUST_DISTANCE, 0.01,
		"push must point away from the caster, not along the cast axis"
	)
	assert_almost_eq(cone_edge.global_position.normalized().angle(), deg_to_rad(45.0), 0.001)
	assert_false(ahead.is_knocked_back(), "slide must finish after its window")
	host.free()


## Real AI hosts: the gust cancels an unlanded attack, slides the enemy the
## authored distance, then lets it re-engage once the short hold ends.
func test_air_gust_interrupts_enemy_and_slides_deterministically() -> void:
	var result := _cast_gust()
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
	assert_true(enemy.is_knocked_back())
	assert_eq(enemy.get_machine().state, EnemyCombatState.State.REACT)
	assert_eq(enemy.view_animation(), &"hit")

	_step(enemy, player, 0.25)
	assert_almost_eq(enemy.global_position.x, 40.0 + GUST_DISTANCE, 0.01)
	assert_false(enemy.is_knocked_back())
	assert_eq(enemy.get_machine().state, EnemyCombatState.State.REACT, "hold outlasts the slide")
	assert_eq(impacts[0], 0, "a shoved enemy must not land its attack")
	_step(enemy, player, 0.4)
	assert_false(enemy.is_staggered())
	assert_true(
		enemy.get_machine().state != EnemyCombatState.State.REACT,
		"enemy must re-engage once the hold expires"
	)

	# One big step and many small steps must land on the same position.
	var coarse := _add_enemy(host, Vector2.ZERO, player)
	var fine := _add_enemy(host, Vector2.ZERO, player)
	coarse.apply_knockback(Vector2(0.0, 80.0), 0.5)
	fine.apply_knockback(Vector2(0.0, 80.0), 0.5)
	coarse.tick_ai(0.3, player)
	for _i in 30:
		fine.tick_ai(0.01, player)
	assert_almost_eq(coarse.global_position.y, 80.0, 0.001)
	assert_almost_eq(fine.global_position.y, 80.0, 0.001)
	host.free()


func test_overlapping_knockback_replaces_slide_and_dead_or_reset_enemies_stay_put() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var host := Node2D.new()
	tree.root.add_child(host)
	var player := Node2D.new()
	host.add_child(player)
	var enemy := _add_enemy(host, Vector2.ZERO, player)
	enemy.apply_knockback(Vector2(100.0, 0.0), 0.5)
	enemy.tick_ai(0.1, player)
	var partial := enemy.global_position.x
	assert_true(partial > 0.0 and partial < 100.0)
	enemy.apply_knockback(Vector2(100.0, 0.0), 0.5)
	enemy.tick_ai(0.5, player)
	assert_almost_eq(
		enemy.global_position.x, partial + 100.0, 0.01, "recast replaces, it does not add the remainder"
	)

	var corpse := _add_enemy(host, Vector2(50.0, 0.0), player)
	corpse.take_damage(999.0, player, &"test", 1, true)
	corpse.apply_knockback(Vector2(90.0, 0.0), 0.5)
	corpse.tick_ai(0.5, player)
	assert_false(corpse.is_knocked_back())
	assert_eq(corpse.global_position, Vector2(50.0, 0.0), "dead enemies must not slide")

	var reset_enemy := _add_enemy(host, Vector2.ZERO, player)
	reset_enemy.apply_knockback(Vector2(90.0, 0.0), 0.5)
	reset_enemy.reset_actor()
	assert_false(reset_enemy.is_knocked_back())
	assert_false(reset_enemy.is_staggered())
	host.free()


func test_target_on_caster_is_pushed_along_cast_direction() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var host := Node2D.new()
	tree.root.add_child(host)
	var caster := _add_dummy(host, Vector2.ZERO)
	var overlapping := _add_dummy(host, Vector2.ZERO)
	var pulse := MagicAreaPulse2D.new()
	host.add_child(pulse)
	assert_false(
		pulse.configure(caster, &"spell.test", 64.0, {"kind": "knockback"}, Vector2.UP, 0.0),
		"zero arc must fail closed"
	)
	assert_true(pulse.configure(
		caster, &"spell.test", 64.0,
		{"kind": "knockback", "distance": 50.0, "duration_sec": 0.5}, Vector2.UP, 60.0
	))
	var affected := pulse.pulse()
	assert_true(affected.has(overlapping))
	overlapping._process(CombatKnockbackEffect.SLIDE_SEC)
	assert_almost_eq(overlapping.global_position.y, -50.0, 0.01)
	host.free()


## Hosts with walls clamp the shove through _constrain_knockback_position; the
## Workers' District bandit snaps to its navmesh there. The headless harness
## cannot await a NavigationServer sync, so the hook is proven with a walled
## subclass and the bandit's unsynced-map path must fail open, not freeze.
func test_knockback_respects_host_constraint_and_bandit_fails_open() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var host := Node2D.new()
	tree.root.add_child(host)
	var player := Node2D.new()
	host.add_child(player)
	var walled_script := GDScript.new()
	walled_script.source_code = """extends CombatRoomEnemy
func _constrain_knockback_position(_from: Vector2, to: Vector2) -> Vector2:
	return Vector2(minf(to.x, 100.0), to.y)
"""
	assert_eq(walled_script.reload(), OK)
	var walled := walled_script.new() as CombatRoomEnemy
	host.add_child(walled)
	walled.configure(EnemyArchetype.watchman(), Color.WHITE)
	walled.global_position = Vector2(60.0, 0.0)
	walled.apply_knockback(Vector2(96.0, 0.0), 0.5)
	walled.tick_ai(CombatKnockbackEffect.SLIDE_SEC, player)
	assert_almost_eq(walled.global_position.x, 100.0, 0.001, "shove must stop at the wall")

	var map := NavigationServer2D.map_create()
	var bandit := WorkersDistrictBandit.new()
	var agent := NavigationAgent2D.new()
	agent.name = "NavigationAgent2D"
	bandit.add_child(agent)
	host.add_child(bandit)
	bandit.configure_bandit(player)
	bandit.global_position = Vector2(60.0, 0.0)
	bandit.set_navigation_map(map)
	bandit.apply_knockback(Vector2(96.0, 0.0), 0.5)
	bandit.tick_ai(CombatKnockbackEffect.SLIDE_SEC)
	assert_almost_eq(bandit.global_position.x, 156.0, 0.001, "unsynced map must not pin the bandit")
	host.free()
	NavigationServer2D.free_rid(map)


func test_natural_scales_hold_but_not_distance() -> void:
	var effect := {
		"delivery": {"kind": "area_pulse", "radius": 112.0, "arc_deg": 90.0},
		"impact": {"kind": "knockback", "distance": 96.0, "duration_sec": 0.6},
	}
	MagicResolver._scale_effect(effect, 1.5)
	assert_almost_eq(float(effect["impact"]["duration_sec"]), 0.9, 0.0001)
	assert_eq(effect["impact"]["distance"], 96.0, "distance is placement, never NATURAL-scaled")
	assert_eq(effect["delivery"]["arc_deg"], 90.0)
	assert_eq(effect["delivery"]["radius"], 112.0)


func _cast_gust() -> Dictionary:
	var db := ContentDB.new()
	assert_true(db.load_from_directories(CONTENT_DIRS))
	var state := GameState.new()
	state.set_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER, 1)
	assert_true(MagicResolver.apply_grant_operation(state, db, GRANT_GUST))
	var result := MagicResolver.cast(state, db, &"", AIR)
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
