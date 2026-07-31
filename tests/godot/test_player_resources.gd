extends RefCounted

const PLAYER_SCENE := preload("res://player.tscn")
const TEST_DELTA := 1.0

var _failures: Array[String] = []

func test_movement_input_drains_stamina_only() -> void:
	var player := _create_player()
	player.health = 60.0
	player.stamina = 80.0
	Input.action_press("ui_right")

	player._physics_process(TEST_DELTA)

	Input.action_release("ui_right")
	_assert_eq(player.health, 60.0, "Movement must not change health")
	_assert_eq(player.stamina, 70.0, "Movement must drain stamina at the configured rate")
	_assert_eq(player.health_ring.get_health_ratio(), 0.6, "Movement must leave the health ring unchanged")
	_assert_eq(player.stamina_bar.value, 70.0, "The stamina bar must show movement drain")
	_assert_eq(player.velocity, Vector2(player.run_speed, 0.0), "Resource separation must preserve run movement")
	player.free()

func test_walk_input_preserves_speed_and_drains_stamina() -> void:
	var player := _create_player()
	Input.action_press("ui_right")
	Input.action_press("ui_shift")

	player._physics_process(TEST_DELTA)

	Input.action_release("ui_shift")
	Input.action_release("ui_right")
	_assert_eq(player.health, 100.0, "Walking must not change health")
	_assert_eq(player.stamina, 90.0, "Walking must drain stamina")
	_assert_eq(player.velocity, Vector2(player.walk_speed, 0.0), "Resource separation must preserve walk movement")
	player.free()

func test_idle_changes_neither_health_nor_stamina() -> void:
	var player := _create_player()
	player.health = 60.0
	player.stamina = 70.0

	player._physics_process(TEST_DELTA)

	_assert_eq(player.health, 60.0, "Idle must not heal health")
	_assert_eq(player.stamina, 70.0, "Idle must not restore the wrong resource")
	_assert_eq(player.health_ring.get_health_ratio(), 0.6, "Idle must not change the health ring")
	_assert_eq(player.stamina_bar.value, 70.0, "Idle must not change the stamina bar")
	_assert_eq(player.velocity, Vector2.ZERO, "Idle movement must remain unchanged")
	player.free()

func test_movement_stamina_is_clamped_at_zero() -> void:
	var player := _create_player()
	player.health = 60.0
	player.stamina = 5.0

	player._update_movement_resources(TEST_DELTA, true)

	_assert_eq(player.health, 60.0, "Exhaustion must not spill over into health")
	_assert_eq(player.stamina, 0.0, "Movement stamina must not become negative")
	player.free()

func test_screen_relative_basis_maps_arrows_to_camera_diagonals() -> void:
	var player := _create_player()
	player.set_screen_movement_basis(Vector2(1.0, -1.0), Vector2(1.0, 1.0))

	_assert_vector_approx(
		player.movement_direction_for_screen_input(Vector2.UP),
		Vector2(-1.0, -1.0).normalized(),
		"Up must move toward the top of the isometric screen"
	)
	_assert_vector_approx(
		player.movement_direction_for_screen_input(Vector2.DOWN),
		Vector2(1.0, 1.0).normalized(),
		"Down must move toward the bottom of the isometric screen"
	)
	_assert_vector_approx(
		player.movement_direction_for_screen_input(Vector2.RIGHT),
		Vector2(1.0, -1.0).normalized(),
		"Right must move toward the right of the isometric screen"
	)
	player.free()

func test_dodge_spends_explicit_stamina_and_rejects_exhausted_start() -> void:
	var player := _create_player()
	player.stamina = Player.DODGE_STAMINA_COST
	assert_true(player.try_start_dodge(Vector2.RIGHT), "Exact dodge cost must be sufficient")
	_assert_eq(player.stamina, 0.0, "Dodge must spend its explicit stamina cost once")
	player.free()

	player = _create_player()
	player.stamina = Player.DODGE_STAMINA_COST - 0.1
	_assert_eq(player.try_start_dodge(Vector2.RIGHT), false, "Dodge must not start below its stamina cost")
	_assert_eq(player.action_state_machine.state, PlayerActionState.State.MOVE, "Rejected dodge must stay in MOVE")
	_assert_eq(player.stamina, Player.DODGE_STAMINA_COST - 0.1, "Rejected dodge must not spend stamina")
	player.free()


func test_buffered_dodge_rechecks_stamina_when_recovery_ends() -> void:
	var player := _create_player()
	player.stamina = Player.DODGE_STAMINA_COST
	player.action_state_machine.try_start_action(PlayerActionKind.Kind.ATTACK)
	_assert_eq(player.try_start_dodge(Vector2.LEFT), false, "Busy player should buffer rather than start dodge")
	player.stamina = Player.DODGE_STAMINA_COST - 1.0
	var machine := player.action_state_machine
	while machine.state != PlayerActionState.State.MOVE:
		machine.tick(TEST_DELTA)
	_assert_eq(machine.state, PlayerActionState.State.MOVE, "Failed buffered stamina gate must recover to MOVE")
	_assert_eq(player.stamina, Player.DODGE_STAMINA_COST - 1.0, "Failed buffered dodge must not spend stamina")
	player.free()


func _create_player() -> Player:
	if SessionState.state == null:
		SessionState.state = GameState.new()
	SessionState.state.bag = InventoryBag.new()
	var player := PLAYER_SCENE.instantiate() as Player
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(player)
	return player

func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s - expected <%s> but got <%s>" % [message, str(expected), str(actual)])

func _assert_vector_approx(actual: Vector2, expected: Vector2, message: String) -> void:
	if not actual.is_equal_approx(expected):
		_failures.append("%s - expected <%s> but got <%s>" % [message, str(expected), str(actual)])

func _get_failures() -> Array[String]:
	return _failures.duplicate()
