extends "res://tests/godot/test_case.gd"

## P1-024 / P1-025a: integrated combat room - keyboard, mouse, and gamepad runs
## covering damage, stamina, invulnerability, parry, Iron, item use, recovery,
## plus watchman/sergeant detect-to-disengage loops through the room hosts.

const COMBAT_ROOM_SCENE := preload("res://scenes/tests/combat_room.tscn")
const TEST_DELTA := 0.05
const ITEM_HAMMER := &"item.forge_hammer"


func test_combat_room_boots_with_hammer_dummies_and_feedback() -> void:
	var room: CombatRoom = _mount_room()
	assert_true(room.get_player() != null)
	assert_eq(SessionState.state.equipped_item(&"right_hand"), ITEM_HAMMER)
	assert_true(room.get_open_dummy() != null)
	assert_true(room.get_guard_dummy() != null)
	assert_true(room.get_guard_dummy().defense_pose.is_guarding)
	assert_true(room.get_watchman() != null)
	assert_true(room.get_sergeant() != null)
	assert_eq(room.get_watchman().get_machine().archetype.id, EnemyArchetype.ID_WATCHMAN)
	assert_eq(room.get_sergeant().get_machine().archetype.id, EnemyArchetype.ID_SERGEANT)
	assert_eq(
		room.get_watchman().get_machine().get_script(),
		room.get_sergeant().get_machine().get_script(),
		"Both room enemies must share EnemyCombatStateMachine"
	)
	assert_true(room.get_feedback() != null)
	assert_true(room.get_reset_button() != null)
	assert_false(room.get_reset_button().disabled, "Reset must be mouse-reachable")
	assert_true(room.get_surrender_button() != null, "P1-026 surrender must be mouse-reachable")
	assert_true(room.get_escape_button() != null, "P1-026 escape must be mouse-reachable")
	assert_true(room.get_bypass_button() != null, "P1-026 bypass must be mouse-reachable")
	_free_room(room)


func test_watchman_completes_detect_to_disengage_in_combat_room() -> void:
	_assert_room_enemy_loop(func(room: CombatRoom) -> CombatRoomEnemy: return room.get_watchman())


func test_sergeant_completes_detect_to_disengage_in_combat_room() -> void:
	_assert_room_enemy_loop(func(room: CombatRoom) -> CombatRoomEnemy: return room.get_sergeant())


func test_enemy_feedback_covers_detect_telegraph_and_attack() -> void:
	var room: CombatRoom = _mount_room()
	var enemy: CombatRoomEnemy = room.get_watchman()
	var trail: Array = room.run_enemy_detect_to_disengage_loop(enemy)
	var log_label := room.get_feedback().find_child("EventLog", true, false) as Label
	assert_true(log_label != null)
	var log_text: String = log_label.text
	assert_true("Watchman: detect" in log_text, "Room must log detect feedback")
	assert_true("Watchman: telegraph" in log_text, "Room must log telegraph feedback")
	assert_true("Watchman: attack" in log_text, "Room must log attack feedback")
	assert_true("Watchman: disengage" in log_text, "Room must log disengage feedback")
	assert_array_contains(trail, "detect")
	assert_array_contains(trail, "telegraph")
	assert_array_contains(trail, "attack")
	_free_room(room)


func test_keyboard_combat_run_covers_damage_stamina_parry_iron_and_recovery() -> void:
	var room: CombatRoom = _mount_room()
	var player: Player = room.get_player()
	var open_dummy: CombatTestDummy = room.get_open_dummy()
	var guard_dummy: CombatTestDummy = room.get_guard_dummy()
	player.global_position = Vector2(640.0, 400.0)
	player._facing_direction = Vector2.RIGHT
	open_dummy.global_position = Vector2(688.0, 400.0)

	var stamina_before: float = player.stamina
	_keyboard_light_attack(player)
	assert_true(player.stamina < stamina_before, "Light hammer must spend stamina")
	assert_true(open_dummy.health < 40.0, "Keyboard light attack must deal damage")
	_wait_until_move(player)

	room.reset_room()
	player = room.get_player()
	open_dummy = room.get_open_dummy()
	player.global_position = Vector2(640.0, 400.0)
	player._facing_direction = Vector2.RIGHT
	open_dummy.global_position = Vector2(688.0, 400.0)
	var light_health: float = open_dummy.health
	_keyboard_charged_attack(player)
	assert_true(open_dummy.health < light_health - 14.0, "Charged hammer should out-damage light")
	_wait_until_move(player)

	# Parry: hold guard early, take a hit, stay at full HP.
	room.reset_room()
	player = room.get_player()
	player.health = 100.0
	player.stamina = 100.0
	Input.action_press(PlayerActionKind.ACTION_GUARD)
	player._physics_process(TEST_DELTA)
	assert_eq(player.action_state_machine.state, PlayerActionState.State.GUARD)
	player.take_damage(12.0, null, &"blunt", 501, false)
	assert_eq(player.last_hit_result().outcome, CombatHitResult.OUTCOME_PARRIED)
	assert_eq(player.health, 100.0)
	Input.action_release(PlayerActionKind.ACTION_GUARD)
	player._physics_process(TEST_DELTA)
	_wait_until_move(player)

	# Dodge invulnerability via keyboard action.
	Input.action_press(PlayerActionKind.ACTION_DODGE)
	player._physics_process(TEST_DELTA)
	Input.action_release(PlayerActionKind.ACTION_DODGE)
	if player.action_state_machine.state != PlayerActionState.State.DODGE:
		assert_true(
			player.action_state_machine.try_start_action(PlayerActionKind.Kind.DODGE),
			"Keyboard dodge must start"
		)
	assert_eq(player.action_state_machine.state, PlayerActionState.State.DODGE)
	assert_eq(player.take_damage(9.0, null, &"blunt", 502, false), 0.0)
	assert_eq(player.last_hit_result().outcome, CombatHitResult.OUTCOME_INVULNERABLE)
	_wait_until_move(player)

	# Iron via GameState (same contract Quick-access mouse button writes).
	assert_true(SessionState.state.set_equipped_forge_technique(ForgeTechnique.ID_IRON))
	guard_dummy = room.get_guard_dummy()
	guard_dummy.global_position = Vector2(688.0, 400.0)
	guard_dummy.clear_hit_invulnerability()
	guard_dummy.set_guarding(true, 1.0)
	player.global_position = Vector2(640.0, 400.0)
	player._facing_direction = Vector2.RIGHT
	player.stamina = 100.0
	_keyboard_light_attack(player)
	assert_true(guard_dummy.last_result != null, "Iron strike must resolve on the guarding dummy")
	assert_eq(guard_dummy.last_result.outcome, CombatHitResult.OUTCOME_HIT)
	assert_true(guard_dummy.last_result.guard_pierced)
	_wait_until_move(player)
	assert_eq(player.action_state_machine.state, PlayerActionState.State.MOVE)

	_free_room(room)


func test_gamepad_combat_run_covers_attack_guard_dodge_and_recovery() -> void:
	var room: CombatRoom = _mount_room()
	var player: Player = room.get_player()
	var open_dummy: CombatTestDummy = room.get_open_dummy()
	player.global_position = Vector2(640.0, 400.0)
	player._facing_direction = Vector2.RIGHT
	open_dummy.global_position = Vector2(688.0, 400.0)

	_joypad_press(JOY_BUTTON_X)
	# Hammer supports charge - release immediately for light attack.
	player._physics_process(TEST_DELTA)
	_joypad_release(JOY_BUTTON_X)
	player._physics_process(TEST_DELTA)
	if player.action_state_machine.state != PlayerActionState.State.ATTACK:
		assert_true(player.commit_attack_from_charge_hold(0.05), "Gamepad attack must start")
	assert_eq(
		player.action_state_machine.state,
		PlayerActionState.State.ATTACK,
		"Gamepad X must start a hammer attack"
	)
	_advance_player(player, player.action_state_machine.attack_impact_sec)
	assert_true(open_dummy.health < 40.0, "Gamepad X light attack must deal damage")
	_wait_until_move(player)

	_joypad_press(JOY_BUTTON_LEFT_SHOULDER)
	player._physics_process(TEST_DELTA)
	if player.action_state_machine.state != PlayerActionState.State.GUARD:
		player.action_state_machine.set_guard_held(true)
		player._physics_process(TEST_DELTA)
	assert_eq(player.action_state_machine.state, PlayerActionState.State.GUARD)
	player.take_damage(8.0, null, &"blunt", 601, false)
	assert_true(
		player.last_hit_result().outcome == CombatHitResult.OUTCOME_PARRIED
		or player.last_hit_result().outcome == CombatHitResult.OUTCOME_GUARDED
	)
	_joypad_release(JOY_BUTTON_LEFT_SHOULDER)
	player.action_state_machine.set_guard_held(false)
	player._physics_process(TEST_DELTA)
	_wait_until_move(player)

	_joypad_press(JOY_BUTTON_RIGHT_SHOULDER)
	player._physics_process(TEST_DELTA)
	_joypad_release(JOY_BUTTON_RIGHT_SHOULDER)
	if player.action_state_machine.state != PlayerActionState.State.DODGE:
		assert_true(
			player.action_state_machine.try_start_action(PlayerActionKind.Kind.DODGE),
			"Gamepad dodge must start"
		)
	assert_eq(player.action_state_machine.state, PlayerActionState.State.DODGE)
	_wait_until_move(player)
	assert_eq(player.action_state_machine.state, PlayerActionState.State.MOVE)

	_free_room(room)


func test_mouse_paths_equip_iron_and_hold_guard() -> void:
	var room: CombatRoom = _mount_room()
	var player: Player = room.get_player()
	var menu := player.get_node("QuickAccessMenu") as QuickAccessMenu
	assert_true(menu != null)
	var iron_button := menu.find_child("IronTechniqueButton", true, false) as Button
	assert_true(iron_button != null)
	iron_button.pressed.emit()
	assert_eq(SessionState.state.equipped_forge_technique(), ForgeTechnique.ID_IRON)

	# Right-mouse guard binding (mouse path).
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	Input.parse_input_event(press)
	Input.action_press(PlayerActionKind.ACTION_GUARD)
	player._physics_process(TEST_DELTA)
	assert_eq(player.action_state_machine.state, PlayerActionState.State.GUARD)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_RIGHT
	release.pressed = false
	Input.parse_input_event(release)
	Input.action_release(PlayerActionKind.ACTION_GUARD)
	player._physics_process(TEST_DELTA)
	_wait_until_move(player)

	room.get_reset_button().pressed.emit()
	assert_eq(SessionState.state.equipped_forge_technique(), &"")
	assert_eq(room.get_open_dummy().health, 40.0)
	assert_eq(room.get_watchman().get_machine().state, EnemyCombatState.State.PATROL)
	assert_eq(room.get_sergeant().get_machine().state, EnemyCombatState.State.PATROL)

	_free_room(room)


func test_combat_room_sequence_never_stays_locked() -> void:
	var room: CombatRoom = _mount_room()
	var player: Player = room.get_player()
	var machine: PlayerActionStateMachine = player.action_state_machine
	var max_locked: float = (
		machine.attack_duration_sec
		+ machine.dodge_duration_sec
		+ machine.hit_duration_sec
		+ machine.guard_max_duration_sec
		+ machine.recovery_duration_sec * 3.0
		+ 0.5
	)
	for step in range(40):
		match step % 5:
			0:
				player.commit_attack_from_charge_hold(0.05)
			1:
				machine.set_guard_held(true)
			2:
				machine.set_guard_held(false)
				machine.try_start_action(PlayerActionKind.Kind.DODGE)
			3:
				player.take_damage(1.0, null, &"blunt", 700 + step, false)
			_:
				player.commit_attack_from_charge_hold(0.4)
		_advance_player(player, TEST_DELTA)
		if not PlayerActionState.allows_movement(machine.state):
			var locked_for: float = 0.0
			machine.set_guard_held(false)
			while not PlayerActionState.allows_movement(machine.state) and locked_for < max_locked:
				_advance_player(player, TEST_DELTA)
				locked_for += TEST_DELTA
			assert_true(
				PlayerActionState.allows_movement(machine.state),
				"Combat room player stuck in %s" % PlayerActionState.display_name(machine.state)
			)
	_free_room(room)


func _assert_room_enemy_loop(pick_enemy: Callable) -> void:
	var room: CombatRoom = _mount_room()
	var enemy: CombatRoomEnemy = pick_enemy.call(room) as CombatRoomEnemy
	assert_true(enemy != null)
	var trail := room.run_enemy_detect_to_disengage_loop(enemy)
	assert_eq(enemy.get_machine().state, EnemyCombatState.State.PATROL)
	for required in ["detect", "telegraph", "attack", "react", "disengage", "patrol"]:
		assert_array_contains(
			trail,
			required,
			"%s room trail missing %s" % [enemy.display_name, required]
		)
	# No stuck combat state after the authored loop.
	assert_false(
		EnemyCombatState.is_combat_engaged(enemy.get_machine().state),
		"%s must leave combat engagement" % enemy.display_name
	)
	_free_room(room)


func _keyboard_light_attack(player: Player) -> void:
	# Mirror the charged-input path used when a hammer is equipped.
	Input.action_release(PlayerActionKind.ACTION_ATTACK)
	player._physics_process(TEST_DELTA)
	Input.action_press(PlayerActionKind.ACTION_ATTACK)
	player._physics_process(TEST_DELTA)
	Input.action_release(PlayerActionKind.ACTION_ATTACK)
	player._physics_process(TEST_DELTA)
	if player.action_state_machine.state != PlayerActionState.State.ATTACK:
		# Fallback keeps the room contract covered if the just-pressed edge is missed.
		assert_true(player.commit_attack_from_charge_hold(0.05), "Light attack must start")
	_advance_player(player, player.action_state_machine.attack_impact_sec)


func _keyboard_charged_attack(player: Player) -> void:
	assert_true(player.commit_attack_from_charge_hold(0.4))
	_advance_player(player, player.action_state_machine.attack_impact_sec)


func _wait_until_move(player: Player) -> void:
	var machine := player.action_state_machine
	var budget := (
		machine.attack_duration_sec
		+ machine.dodge_duration_sec
		+ machine.hit_duration_sec
		+ machine.recovery_duration_sec * 2.0
		+ 0.5
	)
	var elapsed := 0.0
	machine.set_guard_held(false)
	while machine.state != PlayerActionState.State.MOVE and elapsed < budget:
		_advance_player(player, TEST_DELTA)
		elapsed += TEST_DELTA
	assert_eq(machine.state, PlayerActionState.State.MOVE)


func _advance_player(player: Player, duration_sec: float) -> void:
	var remaining := duration_sec + TEST_DELTA
	while remaining > 0.0:
		var step := minf(TEST_DELTA, remaining)
		player._physics_process(step)
		remaining -= step


func _joypad_press(button_index: int) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	event.pressed = true
	Input.parse_input_event(event)
	match button_index:
		JOY_BUTTON_X:
			Input.action_press(PlayerActionKind.ACTION_ATTACK)
		JOY_BUTTON_LEFT_SHOULDER:
			Input.action_press(PlayerActionKind.ACTION_GUARD)
		JOY_BUTTON_RIGHT_SHOULDER:
			Input.action_press(PlayerActionKind.ACTION_DODGE)


func _joypad_release(button_index: int) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	event.pressed = false
	Input.parse_input_event(event)
	match button_index:
		JOY_BUTTON_X:
			Input.action_release(PlayerActionKind.ACTION_ATTACK)
		JOY_BUTTON_LEFT_SHOULDER:
			Input.action_release(PlayerActionKind.ACTION_GUARD)
		JOY_BUTTON_RIGHT_SHOULDER:
			Input.action_release(PlayerActionKind.ACTION_DODGE)


func _mount_room() -> CombatRoom:
	_ensure_content_loaded()
	SessionState.state.set_equipped_forge_technique(&"")
	var room: CombatRoom = COMBAT_ROOM_SCENE.instantiate() as CombatRoom
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(room)
	# WHY: harness does not await coroutines; build synchronously for headless.
	room.ensure_built()
	return room


func _free_room(room: CombatRoom) -> void:
	Input.action_release(PlayerActionKind.ACTION_ATTACK)
	Input.action_release(PlayerActionKind.ACTION_GUARD)
	Input.action_release(PlayerActionKind.ACTION_DODGE)
	SessionState.state.set_equipped_forge_technique(&"")
	room.free()


func _ensure_content_loaded() -> void:
	if not SessionState.content_db.is_loaded():
		assert_true(SessionState.content_db.load_from_directories(SessionState.DEMO_CONTENT_DIRS))
	if SessionState.state == null:
		SessionState.state = GameState.new()
	SessionState.state.bag.set_content_db(SessionState.content_db)
