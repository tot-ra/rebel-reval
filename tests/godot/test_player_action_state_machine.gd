extends "res://tests/godot/test_case.gd"

const PLAYER_SCENE := preload("res://player.tscn")
const COMBAT_TEST_DUMMY := preload("res://tests/godot/fixtures/combat_test_dummy.gd")
const TEST_DELTA := 0.05


func test_attack_guard_dodge_and_hit_return_to_move() -> void:
	var machine := _make_machine()
	assert_eq(machine.state, PlayerActionState.State.MOVE, "Machine starts in MOVE")

	assert_true(machine.try_start_action(PlayerActionKind.Kind.ATTACK), "Attack should start from MOVE")
	_advance(machine, machine.attack_duration_sec)
	assert_eq(machine.state, PlayerActionState.State.RECOVERY, "Attack should enter recovery")
	_advance(machine, machine.recovery_duration_sec)
	assert_eq(machine.state, PlayerActionState.State.MOVE, "Recovery should return to MOVE")

	machine.set_guard_held(true)
	assert_eq(machine.state, PlayerActionState.State.GUARD, "Guard should start when held")
	machine.set_guard_held(false)
	assert_eq(machine.state, PlayerActionState.State.MOVE, "Releasing guard should return to MOVE")

	assert_true(machine.try_start_action(PlayerActionKind.Kind.DODGE), "Dodge should start from MOVE")
	_advance(machine, machine.dodge_duration_sec + machine.recovery_duration_sec)
	assert_eq(machine.state, PlayerActionState.State.MOVE, "Dodge chain should return to MOVE")

	machine.apply_hit()
	assert_eq(machine.state, PlayerActionState.State.HIT, "Hit should interrupt MOVE")
	_advance(machine, machine.hit_duration_sec + machine.recovery_duration_sec)
	assert_eq(machine.state, PlayerActionState.State.MOVE, "Hit chain should return to MOVE")


func test_buffered_attack_chains_after_dodge_recovery() -> void:
	var machine := _make_machine()
	assert_true(machine.try_start_action(PlayerActionKind.Kind.DODGE))
	machine.try_start_action(PlayerActionKind.Kind.ATTACK)
	_advance(machine, machine.dodge_duration_sec)
	assert_eq(machine.state, PlayerActionState.State.RECOVERY, "Dodge should enter recovery with buffered attack")
	_advance(machine, machine.recovery_duration_sec)
	assert_eq(machine.state, PlayerActionState.State.ATTACK, "Buffered attack should chain after recovery")
	_advance(machine, machine.attack_duration_sec + machine.recovery_duration_sec)
	assert_eq(machine.state, PlayerActionState.State.MOVE, "Buffered chain should finish in MOVE")


func test_hit_is_ignored_during_dodge_invulnerability() -> void:
	var machine := _make_machine()
	assert_true(machine.try_start_action(PlayerActionKind.Kind.DODGE))
	machine.apply_hit()
	assert_eq(machine.state, PlayerActionState.State.DODGE, "Hit must not interrupt dodge")
	_advance(machine, machine.dodge_duration_sec + machine.recovery_duration_sec)
	assert_eq(machine.state, PlayerActionState.State.MOVE, "Dodge should still resolve normally")


func test_random_input_sequence_never_stays_locked() -> void:
	var machine := _make_machine()
	var max_locked_sec := (
		machine.attack_duration_sec
		+ machine.dodge_duration_sec
		+ machine.hit_duration_sec
		+ machine.guard_max_duration_sec
		+ machine.recovery_duration_sec * 3.0
		+ 0.5
	)
	var actions := [
		PlayerActionKind.Kind.ATTACK,
		PlayerActionKind.Kind.DODGE,
		PlayerActionKind.Kind.GUARD,
		PlayerActionKind.Kind.ATTACK,
	]
	var guard_held := false

	for step in range(80):
		var kind: PlayerActionKind.Kind = actions[step % actions.size()]
		if kind == PlayerActionKind.Kind.GUARD:
			guard_held = not guard_held
			machine.set_guard_held(guard_held)
		else:
			machine.try_start_action(kind)
		if step % 11 == 0:
			machine.set_guard_held(false)
			machine.apply_hit()
		_advance(machine, TEST_DELTA)
		if not PlayerActionState.allows_movement(machine.state):
			var locked_for := 0.0
			while not PlayerActionState.allows_movement(machine.state) and locked_for < max_locked_sec:
				_advance(machine, TEST_DELTA)
				locked_for += TEST_DELTA
			assert_true(
				PlayerActionState.allows_movement(machine.state),
				"State machine stuck in %s after %.2fs" % [
					PlayerActionState.display_name(machine.state),
					locked_for,
				]
			)


func test_attack_emits_one_impact_per_action() -> void:
	var machine := _make_machine()
	var impacts := [0]
	machine.attack_impact.connect(func() -> void: impacts[0] += 1)

	assert_true(machine.try_start_action(PlayerActionKind.Kind.ATTACK))
	_advance(machine, machine.attack_impact_sec)
	assert_eq(impacts[0], 1, "Attack should emit its impact at the authored moment")
	_advance(machine, machine.attack_duration_sec + machine.recovery_duration_sec)
	assert_eq(impacts[0], 1, "One attack must never emit duplicate impacts")

	assert_true(machine.try_start_action(PlayerActionKind.Kind.ATTACK))
	_advance(machine, machine.attack_impact_sec)
	assert_eq(impacts[0], 2, "A later attack should emit a fresh impact")


func test_unarmed_attack_hits_only_targets_in_front_and_in_reach() -> void:
	var player := _create_unarmed_player()
	player.global_position = Vector2.ZERO
	player._facing_direction = Vector2.RIGHT
	var front = _create_dummy(Vector2(32.0, 0.0))
	var behind = _create_dummy(Vector2(-32.0, 0.0))
	var far = _create_dummy(Vector2(64.0, 0.0))

	assert_true(player.action_state_machine.try_start_action(PlayerActionKind.Kind.ATTACK))
	_advance(player.action_state_machine, player.action_state_machine.attack_impact_sec)

	assert_eq(front.health, 12.0, "Unarmed punch should apply its base damage in front")
	assert_eq(front.hit_count, 1, "A punch should damage a target only once")
	assert_eq(behind.health, 20.0, "Punch must not hit behind the player")
	assert_eq(far.health, 20.0, "Punch must not exceed its reach")
	front.free()
	behind.free()
	far.free()
	player.free()


func test_take_damage_clamps_health_and_enters_hit_state() -> void:
	var player := _create_unarmed_player()
	player.health = 5.0

	assert_eq(player.take_damage(8.0), 5.0, "Damage API should report applied damage")
	assert_eq(player.health, 0.0, "Damage must clamp health at zero")
	assert_eq(player.health_bar.value, 0.0, "Health bar should update immediately")
	assert_eq(player.action_state_machine.state, PlayerActionState.State.HIT, "Damage should trigger hit reaction")
	player.free()


func test_equipped_hammer_uses_content_attack_profile() -> void:
	_ensure_content_loaded()
	var player := _create_player()
	_equip_item(&"right_hand", &"item.forge_hammer")
	player.stamina = 100.0
	var profile := AttackProfileResolver.resolve_for_state(SessionState.state, SessionState.content_db)
	player.prepare_attack_profile(profile)
	assert_true(player.action_state_machine.try_start_action(PlayerActionKind.Kind.ATTACK))

	assert_eq(
		player.action_state_machine.state,
		PlayerActionState.State.ATTACK,
		"Equipped weapons with attack profiles must start attacks from content"
	)
	assert_eq(player.view_animation(), &"hammer_attack")
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
	SessionState.state.bag.set_content_db(SessionState.content_db)


func test_player_scene_respects_action_lock_and_recovers() -> void:
	var player := _create_player()
	player.action_state_machine.try_start_action(PlayerActionKind.Kind.ATTACK)
	player._physics_process(TEST_DELTA)

	assert_false(player.action_state_machine.allows_movement(), "Attack should lock locomotion")
	var machine := player.action_state_machine
	_advance(machine, machine.attack_duration_sec + machine.recovery_duration_sec)
	player._physics_process(TEST_DELTA)
	assert_true(player.action_state_machine.allows_movement(), "Player should recover locomotion after attack")
	assert_eq(player.velocity, Vector2.ZERO, "Locked player should not retain movement velocity")
	player.free()


func test_view_animation_reports_run_walk_and_attack() -> void:
	var player := _create_player()
	assert_eq(player.view_animation(), &"idle")

	player.velocity = Vector2(player.run_speed, 0.0)
	assert_eq(player.view_animation(), &"run")

	Input.action_press("ui_shift")
	player.velocity = Vector2(player.walk_speed, 0.0)
	assert_eq(player.view_animation(), &"walk")
	Input.action_release("ui_shift")

	player.velocity = Vector2.ZERO
	assert_true(player.action_state_machine.try_start_action(PlayerActionKind.Kind.ATTACK))
	assert_eq(player.view_animation(), &"unarmed_attack")
	player.free()


func test_left_mouse_click_does_not_start_attack() -> void:
	var player := _create_unarmed_player()
	player.combat_input_enabled = true
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	Input.action_press(PlayerActionKind.ACTION_ATTACK)
	player._physics_process(TEST_DELTA)
	assert_eq(
		player.action_state_machine.state,
		PlayerActionState.State.MOVE,
		"Left click must stay reserved for click-to-move"
	)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	Input.parse_input_event(release)
	Input.action_release(PlayerActionKind.ACTION_ATTACK)
	player.free()


func test_player_attack_during_ui_block_does_not_start() -> void:
	var player := _create_player()
	player.combat_input_enabled = true
	var inventory := player.get_node("InventoryController") as InventoryController
	inventory.toggle()
	Input.action_press(PlayerActionKind.ACTION_ATTACK)
	player._physics_process(TEST_DELTA)
	Input.action_release(PlayerActionKind.ACTION_ATTACK)
	assert_eq(player.action_state_machine.state, PlayerActionState.State.MOVE, "UI block should prevent combat start")
	inventory.toggle()
	player.free()


func _make_machine() -> PlayerActionStateMachine:
	var machine := PlayerActionStateMachine.new()
	machine.guard_max_duration_sec = 0.5
	machine.reset()
	return machine


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


func _create_dummy(position: Vector2):
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
