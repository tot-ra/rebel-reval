extends "res://tests/godot/test_case.gd"

## R-1161 combat animation system (docs/SYSTEMS/COMBAT_ANIMATION.md): weapon
## move sets, combo chain, roll, cast gestures, blends and real bone motion.

const PLAYER_SCENE := preload("res://player.tscn")
const KALEV_SCENE := preload("res://assets/characters/kalev/kalev.tscn")
const TEST_DELTA := 0.02


func test_every_weapon_class_has_distinct_three_step_chain_and_heavy() -> void:
	var kalev := _create_kalev()
	for weapon_class: StringName in CombatMoveCatalog.WEAPON_CLASSES:
		assert_eq(CombatMoveCatalog.combo_length(weapon_class), 3, "%s chain length" % weapon_class)
		var ids: Array[StringName] = []
		var moves: Array[CombatMove] = []
		for step in 3:
			moves.append(CombatMoveCatalog.light_move(weapon_class, step))
		moves.append(CombatMoveCatalog.heavy_move(weapon_class))
		for move in moves:
			assert_false(move.id in ids, "%s repeats move id %s" % [weapon_class, move.id])
			ids.append(move.id)
			assert_true(kalev.has_animation(move.id), "Rig lacks clip for %s" % move.id)
			assert_true(
				move.impact_sec > 0.0 and move.impact_sec < move.duration_sec, "%s impact" % move.id
			)
			assert_true(
				move.cancel_sec > move.impact_sec and move.cancel_sec <= move.duration_sec,
				"%s combo cancel must sit between impact and the end" % move.id
			)
		# The chain must read as three different swings, not one clip three times.
		var clips := {}
		for step in 3:
			clips[kalev.source_animation_name(moves[step].id)] = true
		assert_true(clips.size() >= 2, "%s chain needs distinct source clips" % weapon_class)
		assert_eq(
			CombatMoveCatalog.light_move(weapon_class, 3).id,
			moves[0].id,
			"A fourth press restarts the chain"
		)
	kalev.queue_free()


func test_move_warp_lands_contact_frame_exactly_on_impact() -> void:
	var kalev := _create_kalev()
	for weapon_class: StringName in CombatMoveCatalog.WEAPON_CLASSES:
		var moves: Array[CombatMove] = [CombatMoveCatalog.heavy_move(weapon_class)]
		for step in 3:
			moves.append(CombatMoveCatalog.light_move(weapon_class, step))
		for move in moves:
			var source := kalev.source_animation_name(move.id)
			var length := kalev.animation_player().get_animation(source).length
			assert_true(move.source_contact_sec <= length, "%s contact beyond clip" % move.id)
			assert_almost_eq(
				move.source_time(move.impact_sec, length), move.source_contact_sec, 0.0001
			)
			assert_almost_eq(move.source_time(move.duration_sec, length), length, 0.0001)
			var previous := -1.0
			var t := 0.0
			while t <= move.duration_sec:
				var sample := move.source_time(t, length)
				assert_true(sample >= previous, "%s clip clock must never run backward" % move.id)
				previous = sample
				t += 0.01
	kalev.queue_free()


func test_light_chain_advances_on_cancel_window_wraps_and_resets_after_grace() -> void:
	var machine := _machine_for(CombatMoveCatalog.light_move(CombatMoveCatalog.CLASS_SWORD, 0))
	assert_true(machine.try_start_attack(false))
	assert_eq(machine.combo_step, 0)
	for expected_step in [1, 2, 0]:
		# Buffer the follow-up before the cancel window: it must wait for it.
		assert_false(machine.try_start_attack(false))
		assert_eq(machine.state, PlayerActionState.State.ATTACK)
		_tick_until(machine, func() -> bool: return machine.combo_step == expected_step, 2.0)
		assert_eq(machine.combo_step, expected_step)
		assert_true(
			machine.state_elapsed_sec < TEST_DELTA * 1.5,
			"The chained swing starts on the cancel frame, not after recovery"
		)
	# Let the chain lapse: after recovery plus grace the next swing is step 0.
	_tick(machine, machine.attack_duration_sec + machine.recovery_duration_sec + 0.05)
	assert_eq(machine.state, PlayerActionState.State.MOVE)
	assert_eq(machine.next_combo_step(), 1, "Within the grace the chain continues")
	_tick(machine, CombatMoveCatalog.COMBO_GRACE_SEC + 0.05)
	assert_eq(machine.next_combo_step(), 0, "After the grace the chain restarts")


func test_heavy_strike_resets_the_light_chain() -> void:
	var machine := _machine_for(CombatMoveCatalog.light_move(CombatMoveCatalog.CLASS_HAMMER, 0))
	assert_true(machine.try_start_attack(false))
	_tick(machine, machine.attack_duration_sec + machine.recovery_duration_sec + 0.02)
	assert_eq(machine.next_combo_step(), 1)
	assert_true(machine.try_start_attack(true))
	assert_true(machine.attack_is_heavy)
	assert_eq(machine.combo_step, 0)
	assert_eq(machine.next_combo_step(), 0, "A light press after a heavy starts the chain over")


func test_evade_cancels_a_swing_only_after_its_impact() -> void:
	var move := CombatMoveCatalog.light_move(CombatMoveCatalog.CLASS_SPEAR, 0)
	var machine := _machine_for(move)
	machine.evade_cancel_sec = move.impact_sec + CombatMoveCatalog.EVADE_CANCEL_AFTER_IMPACT_SEC
	assert_true(machine.try_start_attack(false))
	_tick(machine, move.impact_sec * 0.5)
	machine.try_start_action(PlayerActionKind.Kind.ROLL)
	_tick(machine, move.impact_sec * 0.4)
	assert_eq(machine.state, PlayerActionState.State.ATTACK, "Wind-up is committed")
	_tick_until(machine, func() -> bool: return machine.state == PlayerActionState.State.ROLL, 1.0)
	assert_eq(machine.state, PlayerActionState.State.ROLL)


func test_roll_is_invulnerable_only_while_tucked() -> void:
	var machine := PlayerActionStateMachine.new()
	assert_true(machine.try_start_action(PlayerActionKind.Kind.ROLL))
	assert_false(machine.is_invulnerable(), "Push-off frame is not protected")
	_tick(machine, machine.roll_iframe_start_sec + TEST_DELTA)
	assert_true(machine.is_invulnerable())
	_tick(machine, machine.roll_iframe_end_sec - machine.state_elapsed_sec + TEST_DELTA)
	assert_false(machine.is_invulnerable(), "The get-up is punishable")
	assert_eq(machine.state, PlayerActionState.State.ROLL)
	_tick(machine, machine.roll_duration_sec)
	assert_eq(machine.state, PlayerActionState.State.MOVE, "A roll returns straight to movement")


func test_roll_plan_turns_into_left_right_forward_and_rolls_back_without_turning() -> void:
	var facing := Vector2.DOWN
	var left: Dictionary = Player.roll_plan(Vector2.LEFT, facing)
	assert_eq(left["animation"], CombatMoveCatalog.ROLL_FORWARD)
	assert_true((left["direction"] as Vector2).is_equal_approx(Vector2.LEFT))
	assert_true(
		(left["facing"] as Vector2).is_equal_approx(Vector2.LEFT), "Kalev turns into a side roll"
	)
	var right: Dictionary = Player.roll_plan(Vector2.RIGHT, facing)
	assert_true((right["direction"] as Vector2).is_equal_approx(Vector2.RIGHT))
	var back: Dictionary = Player.roll_plan(Vector2.UP, facing)
	assert_eq(back["animation"], CombatMoveCatalog.ROLL_BACKWARD)
	assert_true((back["direction"] as Vector2).is_equal_approx(Vector2.UP))
	assert_true(
		(back["facing"] as Vector2).is_equal_approx(facing), "A back roll keeps eyes on the threat"
	)
	var idle: Dictionary = Player.roll_plan(Vector2.ZERO, facing)
	assert_eq(idle["animation"], CombatMoveCatalog.ROLL_BACKWARD, "No input rolls back")


func test_guarded_roll_strafes_sideways_keeping_facing() -> void:
	var facing := Vector2.DOWN
	# Facing the viewer, the character's left is screen right.
	var left: Dictionary = Player.roll_plan(Vector2.RIGHT, facing, true)
	assert_eq(left["animation"], CombatMoveCatalog.ROLL_LEFT)
	assert_true((left["facing"] as Vector2).is_equal_approx(facing), "A strafe roll keeps facing")
	assert_true((left["direction"] as Vector2).is_equal_approx(Vector2.RIGHT))
	var right: Dictionary = Player.roll_plan(Vector2.LEFT, facing, true)
	assert_eq(right["animation"], CombatMoveCatalog.ROLL_RIGHT)
	var forward: Dictionary = Player.roll_plan(Vector2.DOWN, facing, true)
	assert_eq(forward["animation"], CombatMoveCatalog.ROLL_FORWARD, "Forward stays a forward roll")
	var unguarded: Dictionary = Player.roll_plan(Vector2.RIGHT, facing, false)
	assert_eq(unguarded["animation"], CombatMoveCatalog.ROLL_FORWARD, "Without guard the body turns")


func test_player_roll_travels_toward_input_and_spends_stamina() -> void:
	var player := _create_player()
	player.global_position = Vector2.ZERO
	player.set_view_facing(Vector2.DOWN)
	player.stamina = 100.0
	assert_true(player.try_start_roll(Vector2.LEFT))
	assert_eq(player.action_state_machine.state, PlayerActionState.State.ROLL)
	assert_eq(player.view_animation(), CombatMoveCatalog.ROLL_FORWARD)
	assert_eq(player.stamina, 100.0 - Player.ROLL_STAMINA_COST)
	_advance_player(player, Player.ROLL_TRAVEL_SEC + TEST_DELTA)
	assert_almost_eq(player.global_position.x, -Player.ROLL_DISTANCE_PX, 2.0)
	assert_almost_eq(player.global_position.y, 0.0, 0.5)
	player.stamina = Player.ROLL_STAMINA_COST - 1.0
	_advance_player(player, 1.0)
	assert_false(player.try_start_roll(Vector2.LEFT), "An exhausted Kalev cannot roll")
	player.free()


func test_cast_gesture_follows_delivery_and_is_refused_mid_swing() -> void:
	var player := _create_player()
	player.stamina = 100.0
	assert_true(player.can_begin_cast())
	assert_true(player.begin_cast_gesture("projectile"))
	assert_eq(player.action_state_machine.state, PlayerActionState.State.CAST)
	assert_eq(player.view_animation(), CombatMoveCatalog.CAST_PROJECTILE)
	_advance_player(player, 1.0)
	assert_true(player.begin_cast_gesture("area_pulse"))
	assert_eq(player.view_animation(), CombatMoveCatalog.CAST_AREA)
	_advance_player(player, 1.2)
	assert_true(player.request_primary_attack())
	assert_false(player.can_begin_cast(), "No spell sign in the middle of a swing")
	assert_eq(CombatMoveCatalog.cast_move_for_delivery("self_buff"), CombatMoveCatalog.CAST_SELF)
	player.free()


func test_transition_blends_are_short_into_actions_and_long_back_to_locomotion() -> void:
	var blend := SharedCharacterRig.transition_blend_sec
	assert_eq(blend.call(&"run", &"sword_attack"), SharedCharacterRig.BLEND_INTO_ATTACK_SEC)
	assert_eq(blend.call(&"sword_attack", &"sword_attack_2"), SharedCharacterRig.BLEND_COMBO_SEC)
	assert_eq(blend.call(&"run", &"roll_forward"), SharedCharacterRig.BLEND_INTO_EVADE_SEC)
	assert_eq(blend.call(&"idle", &"cast_projectile"), SharedCharacterRig.BLEND_INTO_CAST_SEC)
	assert_eq(
		blend.call(&"hammer_attack", &"idle"), SharedCharacterRig.BLEND_ACTION_TO_LOCOMOTION_SEC
	)
	assert_eq(blend.call(&"walk", &"run"), SharedCharacterRig.BLEND_LOCOMOTION_SEC)
	assert_true(
		(
			SharedCharacterRig.BLEND_ACTION_TO_LOCOMOTION_SEC
			> SharedCharacterRig.BLEND_INTO_ATTACK_SEC
		),
		"Input reads instantly, a finished swing settles"
	)


## Regression for the R-1161 root cause: a paused AnimationPlayer ignored the
## seek, so the swing stayed frozen at its blend-in pose. Check real bones.
func test_clock_driven_swing_actually_moves_the_weapon_hand() -> void:
	var kalev := _create_kalev()
	var skeleton := kalev.skeleton()
	var hand := skeleton.find_bone("hand.r")
	assert_true(hand >= 0)
	for move_id: StringName in [&"hammer_attack", &"sword_attack_2", &"spear_attack"]:
		var move := CombatMoveCatalog.presentation_move(move_id)
		assert_true(kalev.play_animation(move_id, 0.0))
		kalev.sync_action_presentation(move_id, 0.0, move.duration_sec)
		var start := skeleton.get_bone_global_pose(hand).origin
		kalev.sync_action_presentation(move_id, move.impact_sec, move.duration_sec)
		var contact := skeleton.get_bone_global_pose(hand).origin
		assert_true(
			start.distance_to(contact) > 0.15,
			(
				"%s hand must travel between wind-up and contact (moved %.3f m)"
				% [move_id, start.distance_to(contact)]
			)
		)
	kalev.queue_free()


func test_side_rolls_tumble_toward_their_own_side_and_end_standing() -> void:
	var kalev := _create_kalev()
	var skeleton := kalev.skeleton()
	var hips := skeleton.find_bone("hips")
	var length := CombatRollClip.LENGTH_SEC
	for id: StringName in [CombatMoveCatalog.ROLL_LEFT, CombatMoveCatalog.ROLL_RIGHT]:
		assert_true(kalev.play_animation(id, 0.0), "%s must exist" % id)
		kalev.sync_action_presentation(id, 0.0, length)
		var start := skeleton.get_bone_global_pose(hips)
		var min_up_dot := 1.0
		var head_side := 0.0
		for i in 21:
			kalev.sync_action_presentation(id, length * i / 20.0, length)
			var up := skeleton.get_bone_global_pose(hips).basis.y.normalized()
			min_up_dot = minf(min_up_dot, up.dot(start.basis.y.normalized()))
			head_side += up.x
		assert_true(min_up_dot < -0.5, "%s must go over shoulders (%.2f)" % [id, min_up_dot])
		# Rolling left carries the head toward the character's left (+X in model space).
		assert_true(
			(head_side > 0.0) == (id == CombatMoveCatalog.ROLL_LEFT),
			"%s tumbles toward its own side (%.2f)" % [id, head_side]
		)
		var end := skeleton.get_bone_global_pose(hips)
		assert_true(end.basis.y.normalized().dot(start.basis.y.normalized()) > 0.95, "%s ends upright" % id)
	kalev.queue_free()


func test_procedural_roll_tumbles_the_body_and_ends_standing() -> void:
	var kalev := _create_kalev()
	var skeleton := kalev.skeleton()
	var hips := skeleton.find_bone("hips")
	assert_true(
		kalev.has_animation(CombatMoveCatalog.ROLL_FORWARD), "Roll clip is generated on demand"
	)
	assert_true(kalev.play_animation(CombatMoveCatalog.ROLL_FORWARD, 0.0))
	var length := CombatRollClip.LENGTH_SEC
	kalev.sync_action_presentation(CombatMoveCatalog.ROLL_FORWARD, 0.0, length)
	var start := skeleton.get_bone_global_pose(hips)
	var min_up_dot := 1.0
	for i in 21:
		kalev.sync_action_presentation(CombatMoveCatalog.ROLL_FORWARD, length * i / 20.0, length)
		var pose := skeleton.get_bone_global_pose(hips)
		min_up_dot = minf(min_up_dot, pose.basis.y.normalized().dot(start.basis.y.normalized()))
	assert_true(
		min_up_dot < -0.5, "The body must go head over heels (min up dot %.2f)" % min_up_dot
	)
	var end := skeleton.get_bone_global_pose(hips)
	assert_true(
		end.origin.distance_to(start.origin) < 0.05, "The roll ends standing where Idle starts"
	)
	kalev.queue_free()


func test_v1_bindings_retire_space_attack_but_keep_custom_keys() -> void:
	var v1 := InputBindingSettings.default_settings().to_dict()
	v1.erase("version")
	var actions: Dictionary = v1["actions"]
	actions["player_attack"][String(InputBindingSettings.DEVICE_KEYBOARD_MOUSE)] = [
		{"type": "key", "physical_keycode": KEY_SPACE}
	]
	var migrated := InputBindingSettings.from_dict(v1)
	for event in migrated.events_for(&"player_attack", InputBindingSettings.DEVICE_KEYBOARD_MOUSE):
		assert_false(
			event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_SPACE,
			"Space is the roll since bindings v2"
		)
	var roll := migrated.events_for(&"player_roll", InputBindingSettings.DEVICE_KEYBOARD_MOUSE)
	assert_eq((roll[0] as InputEventKey).physical_keycode, KEY_SPACE)


func test_spear_item_resolves_spear_move_set_with_guard_piercing_heavy() -> void:
	_ensure_content_loaded()
	_equip(&"item.watch_spear")
	var light := AttackProfileResolver.resolve_move(
		SessionState.state, SessionState.content_db, false, 0
	)
	var heavy := AttackProfileResolver.resolve_move(
		SessionState.state, SessionState.content_db, true, 0
	)
	assert_eq(light.weapon_class, CombatMoveCatalog.CLASS_SPEAR)
	assert_eq(light.animation, &"spear_attack")
	assert_eq(light.damage_type, &"pierce")
	assert_eq(heavy.animation, &"spear_heavy_attack")
	assert_true(heavy.pierces_guard)
	assert_true(heavy.reach_px > light.reach_px, "The heavy lunge reaches further")
	assert_true(heavy.damage > light.damage)


func _machine_for(move: CombatMove) -> PlayerActionStateMachine:
	var machine := PlayerActionStateMachine.new()
	machine.attack_impact_sec = move.impact_sec
	machine.attack_duration_sec = move.duration_sec
	machine.attack_cancel_sec = move.cancel_sec
	machine.combo_length = 3
	return machine


func _tick(machine: PlayerActionStateMachine, seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.0:
		var step := minf(TEST_DELTA, remaining)
		machine.tick(step)
		remaining -= step


func _tick_until(machine: PlayerActionStateMachine, done: Callable, budget_sec: float) -> void:
	var elapsed := 0.0
	while not bool(done.call()) and elapsed < budget_sec:
		machine.tick(TEST_DELTA)
		elapsed += TEST_DELTA


func _advance_player(player: Player, seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.0:
		var step := minf(TEST_DELTA, remaining)
		player._physics_process(step)
		remaining -= step


func _create_kalev() -> SharedCharacterRig:
	var kalev := KALEV_SCENE.instantiate() as SharedCharacterRig
	(Engine.get_main_loop() as SceneTree).root.add_child(kalev)
	return kalev


func _create_player() -> Player:
	_ensure_content_loaded()
	var player := PLAYER_SCENE.instantiate() as Player
	(Engine.get_main_loop() as SceneTree).root.add_child(player)
	if not SessionState.state.equipped_item(&"right_hand").is_empty():
		assert_true(SessionState.state.unequip_to_bag(&"right_hand"))
	return player


func _equip(item_id: StringName) -> void:
	if SessionState.state.equipped_item(&"right_hand") == item_id:
		return
	if not SessionState.state.equipped_item(&"right_hand").is_empty():
		assert_true(SessionState.state.unequip_to_bag(&"right_hand"))
	if SessionState.state.bag.find_placement(item_id) == null:
		assert_eq(SessionState.state.bag.try_add(item_id), InventoryBag.AddResult.OK)
	assert_true(SessionState.state.equip_from_bag(&"right_hand", item_id))


func _ensure_content_loaded() -> void:
	if not SessionState.content_db.is_loaded():
		assert_true(SessionState.content_db.load_from_directories(SessionState.DEMO_CONTENT_DIRS))
	SessionState.state.bag.set_content_db(SessionState.content_db)
