extends "res://tests/godot/test_case.gd"

const PLAYER_SCENE := preload("res://player.tscn")
const COMBAT_TEST_DUMMY := preload("res://tests/godot/fixtures/combat_test_dummy.gd")
const TEST_DELTA := 0.05

const ITEM_HAMMER := &"item.forge_hammer"
const ITEM_TEST_STICK := &"item.combat_test_stick"


func test_resolve_unarmed_profile_when_hands_empty() -> void:
	_ensure_content_loaded()
	var player := _create_unarmed_player()
	var profile := AttackProfileResolver.resolve_for_state(SessionState.state, SessionState.content_db)
	assert_eq(profile.animation, &"unarmed_attack")
	assert_eq(profile.damage, 8.0)
	assert_eq(profile.reach_px, 48.0)
	assert_eq(profile.damage_type, &"blunt")
	player.free()


func test_resolve_hammer_profile_from_content() -> void:
	_ensure_content_loaded()
	var player := _create_player()
	_equip_item(&"right_hand", ITEM_HAMMER)
	var profile := AttackProfileResolver.resolve_for_state(SessionState.state, SessionState.content_db)
	assert_eq(profile.animation, &"hammer_attack")
	assert_eq(profile.damage, 14.0)
	assert_eq(profile.reach_px, 56.0)
	assert_eq(profile.stamina_cost, 12.0)
	player.free()


func test_resolve_test_stick_profile_from_content() -> void:
	_ensure_content_loaded()
	var player := _create_player()
	_equip_item(&"right_hand", ITEM_TEST_STICK)
	var profile := AttackProfileResolver.resolve_for_state(SessionState.state, SessionState.content_db)
	assert_eq(profile.animation, &"forge_strike")
	assert_eq(profile.damage, 5.0)
	assert_eq(profile.damage_type, &"slash")
	player.free()


func test_swapping_equipped_items_changes_attack_behavior_without_item_id_branching() -> void:
	_ensure_content_loaded()
	var player := _create_unarmed_player()
	player.global_position = Vector2.ZERO
	player._facing_direction = Vector2.RIGHT
	var target := _create_dummy(Vector2(32.0, 0.0))

	# Unarmed punch
	_start_attack(player)
	assert_eq(target.health, 12.0, "Unarmed profile should apply default punch damage")

	# Hammer from content
	_clear_hit_invulnerability(target)
	_equip_item(&"right_hand", ITEM_HAMMER)
	player.stamina = 100.0
	_start_attack(player)
	assert_eq(target.health, 0.0, "Hammer profile should apply its authored damage")

	# Test stick from content
	target.health = 20.0
	_clear_hit_invulnerability(target)
	_equip_item(&"right_hand", ITEM_TEST_STICK)
	player.stamina = 100.0
	_start_attack(player)
	assert_eq(target.health, 15.0, "Test stick profile should apply its authored damage")

	target.free()
	player.free()


func test_equipped_hammer_uses_content_profile_and_drains_stamina() -> void:
	_ensure_content_loaded()
	var player := _create_player()
	_equip_item(&"right_hand", ITEM_HAMMER)
	player.stamina = 20.0
	var profile := AttackProfileResolver.resolve_for_state(SessionState.state, SessionState.content_db)
	player.prepare_attack_profile(profile)
	assert_true(player.action_state_machine.try_start_action(PlayerActionKind.Kind.ATTACK))
	player.stamina = maxf(0.0, player.stamina - profile.stamina_cost)

	assert_eq(player.action_state_machine.state, PlayerActionState.State.ATTACK)
	assert_eq(player.stamina, 8.0, "Hammer attack should spend its authored stamina cost")
	assert_eq(player.view_animation(), &"hammer_attack")
	player.free()


func test_resolve_hammer_charged_profile_from_content() -> void:
	_ensure_content_loaded()
	var player := _create_player()
	_equip_item(&"right_hand", ITEM_HAMMER)
	var light := AttackProfileResolver.resolve_for_state(SessionState.state, SessionState.content_db, false)
	var charged := AttackProfileResolver.resolve_for_state(SessionState.state, SessionState.content_db, true)
	assert_eq(light.animation, &"hammer_attack")
	assert_eq(charged.animation, &"hammer_charged_attack")
	assert_eq(charged.damage, 24.0)
	assert_eq(charged.reach_px, 68.0)
	assert_eq(charged.stamina_cost, 22.0)
	assert_eq(charged.impact_timing_sec, 0.42)
	assert_true(charged.damage > light.damage)
	assert_true(charged.reach_px > light.reach_px)
	assert_true(charged.stamina_cost > light.stamina_cost)
	assert_true(charged.impact_timing_sec > light.impact_timing_sec)
	player.free()


func test_hammer_quick_release_uses_light_attack_profile() -> void:
	_ensure_content_loaded()
	var player := _create_player()
	_equip_item(&"right_hand", ITEM_HAMMER)
	player.stamina = 100.0
	assert_true(player.commit_attack_from_charge_hold(0.05))

	assert_eq(player.action_state_machine.state, PlayerActionState.State.ATTACK)
	assert_eq(player.view_animation(), &"hammer_attack")
	assert_eq(player.stamina, 88.0)
	player.free()


func test_hammer_hold_past_threshold_uses_charged_attack_profile() -> void:
	_ensure_content_loaded()
	var player := _create_player()
	_equip_item(&"right_hand", ITEM_HAMMER)
	player.stamina = 100.0
	assert_true(player.commit_attack_from_charge_hold(0.4))

	assert_eq(player.action_state_machine.state, PlayerActionState.State.ATTACK)
	assert_eq(player.view_animation(), &"hammer_charged_attack")
	assert_eq(player.stamina, 78.0)
	player.free()


func test_hammer_charged_attack_hits_with_authored_reach_and_damage() -> void:
	_ensure_content_loaded()
	var player := _create_player()
	_equip_item(&"right_hand", ITEM_HAMMER)
	player.global_position = Vector2.ZERO
	player._facing_direction = Vector2.RIGHT
	player.stamina = 100.0
	var in_reach := _create_dummy(Vector2(60.0, 0.0))
	var beyond_reach := _create_dummy(Vector2(72.0, 0.0))
	assert_true(player.commit_attack_from_charge_hold(0.4))
	_advance(player.action_state_machine, player.action_state_machine.attack_impact_sec)

	assert_eq(in_reach.health, 0.0, "Charged hammer should damage targets inside its longer reach")
	assert_eq(beyond_reach.health, 20.0, "Charged hammer must still respect its reach cap")

	in_reach.free()
	beyond_reach.free()
	player.free()


func test_insufficient_stamina_blocks_attack_start() -> void:
	_ensure_content_loaded()
	var player := _create_player()
	_equip_item(&"right_hand", ITEM_HAMMER)
	player.stamina = 5.0
	assert_false(player.commit_attack_from_charge_hold(0.05))

	assert_eq(player.action_state_machine.state, PlayerActionState.State.MOVE)
	assert_eq(player.stamina, 5.0)
	player.free()


func _start_attack(player: Player) -> void:
	if player.action_state_machine.state != PlayerActionState.State.MOVE:
		_advance(
			player.action_state_machine,
			player.action_state_machine.attack_duration_sec
			+ player.action_state_machine.recovery_duration_sec
			+ 0.1
		)
	var profile := AttackProfileResolver.resolve_for_state(SessionState.state, SessionState.content_db)
	player.prepare_attack_profile(profile)
	player.stamina = maxf(profile.stamina_cost, player.stamina)
	assert_true(player.action_state_machine.try_start_action(PlayerActionKind.Kind.ATTACK))
	player.stamina = maxf(0.0, player.stamina - profile.stamina_cost)
	_advance(player.action_state_machine, player.action_state_machine.attack_impact_sec)


func _clear_hit_invulnerability(actor: CombatTestDummy) -> void:
	# Sequential profile checks are separate swings; expire post-hit i-frames first.
	actor.combat_vitals.tick(actor.combat_vitals.hit_invulnerability_sec + 0.05)
	actor.combat_vitals.reset_swing_tracking()


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
	SessionState.state.bag.set_content_db(SessionState.content_db)


func _advance(machine: PlayerActionStateMachine, duration_sec: float) -> void:
	var remaining := duration_sec + TEST_DELTA
	while remaining > 0.0:
		var step := minf(TEST_DELTA, remaining)
		machine.tick(step)
		remaining -= step


func _create_unarmed_player() -> Player:
	var player := _create_player()
	if not SessionState.state.equipped_item(&"right_hand").is_empty():
		assert_true(SessionState.state.unequip_to_bag(&"right_hand"))
	return player


func _create_dummy(position: Vector2) -> CombatTestDummy:
	var dummy = COMBAT_TEST_DUMMY.new()
	dummy.global_position = position
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(dummy)
	return dummy


func _create_player() -> Player:
	_ensure_content_loaded()
	if SessionState.state == null:
		SessionState.state = GameState.new()
		SessionState.state.bag.set_content_db(SessionState.content_db)
	var player := PLAYER_SCENE.instantiate() as Player
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(player)
	return player
