extends "res://tests/godot/test_case.gd"

## P1-024d: Iron forge technique layers onto AttackProfile / CombatVitals without
## a parallel state machine or enemy-id branching.

const PLAYER_SCENE := preload("res://player.tscn")
const COMBAT_TEST_DUMMY := preload("res://tests/godot/fixtures/combat_test_dummy.gd")
const TEST_DELTA := 0.05
const ITEM_HAMMER := &"item.forge_hammer"


func test_iron_layers_guard_pierce_and_stamina_onto_resolved_profile() -> void:
	_ensure_content_loaded()
	SessionState.state.set_equipped_forge_technique(&"")
	_equip_item(&"right_hand", ITEM_HAMMER)

	var base := AttackProfileResolver.resolve_for_state(SessionState.state, SessionState.content_db)
	assert_false(base.pierces_guard)
	assert_eq(base.technique, &"")
	assert_eq(base.stamina_cost, 12.0)

	assert_true(SessionState.state.set_equipped_forge_technique(ForgeTechnique.ID_IRON))
	var ironed := AttackProfileResolver.resolve_for_state(SessionState.state, SessionState.content_db)
	assert_true(ironed.pierces_guard)
	assert_eq(ironed.technique, ForgeTechnique.ID_IRON)
	assert_eq(ironed.animation, base.animation)
	assert_eq(ironed.damage, base.damage)
	assert_eq(
		ironed.stamina_cost,
		base.stamina_cost + ForgeTechnique.IRON_STAMINA_COST_BONUS,
		"Iron must layer stamina cost onto the same attack contract"
	)

	assert_false(SessionState.state.set_equipped_forge_technique(&"NotATechnique"))
	assert_eq(SessionState.state.equipped_forge_technique(), ForgeTechnique.ID_IRON)
	SessionState.state.set_equipped_forge_technique(&"")


func test_iron_jams_braced_guard_into_open_hit() -> void:
	var vitals := CombatVitals.new()
	vitals.configure(40.0, 40.0, 30.0, 30.0)
	var pose := CombatDefensePose.open()
	pose.is_guarding = true
	pose.guard_elapsed_sec = 1.0

	var without_iron := vitals.resolve_hit(10.0, pose, 1, false)
	assert_eq(without_iron.outcome, CombatHitResult.OUTCOME_GUARDED)
	assert_eq(without_iron.health_damage, 0.0)
	assert_eq(vitals.health, 40.0)
	assert_eq(vitals.stamina, 20.0)

	vitals.tick(vitals.hit_invulnerability_sec + 0.05)
	var with_iron := vitals.resolve_hit(10.0, pose, 2, true)
	assert_eq(with_iron.outcome, CombatHitResult.OUTCOME_HIT)
	assert_true(with_iron.guard_pierced)
	assert_eq(with_iron.health_damage, 10.0)
	assert_eq(vitals.health, 30.0)
	assert_eq(vitals.stamina, 20.0, "Iron jam must spend health, not guard stamina")


func test_iron_does_not_beat_parry_or_dodge() -> void:
	var vitals := CombatVitals.new()
	vitals.configure(40.0, 40.0, 25.0, 25.0)

	var parry_pose := CombatDefensePose.open()
	parry_pose.is_guarding = true
	parry_pose.guard_elapsed_sec = 0.05
	parry_pose.parry_window_sec = 0.18
	var parried := vitals.resolve_hit(12.0, parry_pose, 10, true)
	assert_eq(parried.outcome, CombatHitResult.OUTCOME_PARRIED)
	assert_false(parried.guard_pierced)
	assert_eq(vitals.health, 40.0)

	vitals.tick(vitals.hit_invulnerability_sec + 0.05)
	var dodge_pose := CombatDefensePose.open()
	dodge_pose.is_action_invulnerable = true
	var dodged := vitals.resolve_hit(12.0, dodge_pose, 11, true)
	assert_eq(dodged.outcome, CombatHitResult.OUTCOME_INVULNERABLE)
	assert_eq(vitals.health, 40.0)


func test_player_iron_strike_pierces_guarding_dummy_without_enemy_branching() -> void:
	_ensure_content_loaded()
	assert_true(SessionState.state.set_equipped_forge_technique(ForgeTechnique.ID_IRON))
	_equip_item(&"right_hand", ITEM_HAMMER)

	var player := _create_player()
	player.global_position = Vector2.ZERO
	player._facing_direction = Vector2.RIGHT
	player.stamina = 100.0

	var dummy = COMBAT_TEST_DUMMY.new()
	dummy.global_position = Vector2(40.0, 0.0)
	dummy.health = 40.0
	dummy.max_health = 40.0
	dummy.stamina = 40.0
	dummy.max_stamina = 40.0
	dummy.combat_vitals.configure(40.0, 40.0, 40.0, 40.0)
	# Past the parry window: a braced guard Iron should jam.
	dummy.set_guarding(true, 1.0)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(dummy)

	var profile := AttackProfileResolver.resolve_for_state(SessionState.state, SessionState.content_db)
	assert_true(profile.pierces_guard)
	player.prepare_attack_profile(profile)
	assert_true(player.action_state_machine.try_start_action(PlayerActionKind.Kind.ATTACK))
	player.stamina = maxf(0.0, player.stamina - profile.stamina_cost)
	_advance(player.action_state_machine, player.action_state_machine.attack_impact_sec)

	assert_eq(dummy.last_result.outcome, CombatHitResult.OUTCOME_HIT)
	assert_true(dummy.last_result.guard_pierced)
	assert_eq(dummy.health, 40.0 - profile.damage)
	assert_eq(dummy.stamina, 40.0, "Pierced guard must not drain defender stamina")

	dummy.free()
	player.free()
	SessionState.state.set_equipped_forge_technique(&"")


func test_without_iron_same_dummy_keeps_guarded_resolution() -> void:
	_ensure_content_loaded()
	SessionState.state.set_equipped_forge_technique(&"")
	_equip_item(&"right_hand", ITEM_HAMMER)

	var player := _create_player()
	player.global_position = Vector2.ZERO
	player._facing_direction = Vector2.RIGHT
	player.stamina = 100.0

	var dummy = COMBAT_TEST_DUMMY.new()
	dummy.global_position = Vector2(40.0, 0.0)
	dummy.health = 40.0
	dummy.max_health = 40.0
	dummy.stamina = 40.0
	dummy.max_stamina = 40.0
	dummy.combat_vitals.configure(40.0, 40.0, 40.0, 40.0)
	dummy.set_guarding(true, 1.0)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(dummy)

	var profile := AttackProfileResolver.resolve_for_state(SessionState.state, SessionState.content_db)
	assert_false(profile.pierces_guard)
	player.prepare_attack_profile(profile)
	assert_true(player.action_state_machine.try_start_action(PlayerActionKind.Kind.ATTACK))
	_advance(player.action_state_machine, player.action_state_machine.attack_impact_sec)

	assert_eq(dummy.last_result.outcome, CombatHitResult.OUTCOME_GUARDED)
	assert_eq(dummy.health, 40.0)
	assert_true(dummy.stamina < 40.0)

	dummy.free()
	player.free()


func _equip_item(slot: StringName, item_id: StringName) -> void:
	if SessionState.state.equipped_item(slot) == item_id:
		return
	if not SessionState.state.equipped_item(slot).is_empty():
		assert_true(SessionState.state.unequip_to_bag(slot))
	if SessionState.state.bag.find_placement(item_id) == null:
		assert_eq(SessionState.state.bag.try_add(item_id), InventoryBag.AddResult.OK)
	assert_true(SessionState.state.equip_from_bag(slot, item_id))


func _ensure_content_loaded() -> void:
	if not SessionState.content_db.is_loaded():
		assert_true(SessionState.content_db.load_from_directories(SessionState.DEMO_CONTENT_DIRS))
	if SessionState.state == null:
		SessionState.state = GameState.new()
	SessionState.state.bag.set_content_db(SessionState.content_db)


func _advance(machine: PlayerActionStateMachine, duration_sec: float) -> void:
	var remaining := duration_sec + TEST_DELTA
	while remaining > 0.0:
		var step := minf(TEST_DELTA, remaining)
		machine.tick(step)
		remaining -= step


func _create_player() -> Player:
	_ensure_content_loaded()
	var player := PLAYER_SCENE.instantiate() as Player
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(player)
	return player
