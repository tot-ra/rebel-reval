extends "res://tests/godot/test_case.gd"

const PLAYER_SCENE := preload("res://player.tscn")
const KALEV_SCENE := preload("res://assets/characters/kalev/kalev.tscn")
const COMBAT_TEST_DUMMY := preload("res://tests/godot/fixtures/combat_test_dummy.gd")
const ITEM_HAMMER := &"item.forge_hammer"
const TEST_DELTA := 0.02


func test_hammer_actions_use_distinct_canonical_non_looping_clips() -> void:
	var kalev := _create_kalev()

	assert_true(kalev.play_animation(&"hammer_attack", 0.0))
	assert_eq(kalev.current_canonical_animation(), &"hammer_attack")
	assert_eq(kalev.animation_player().current_animation, &"1H_Melee_Attack_Chop")
	assert_eq(
		kalev.animation_player().get_animation(&"1H_Melee_Attack_Chop").loop_mode,
		Animation.LOOP_NONE,
		"Light hammer attack must be a one-shot chop"
	)

	assert_true(kalev.play_animation(&"hammer_charged_attack", 0.0))
	assert_eq(kalev.current_canonical_animation(), &"hammer_charged_attack")
	assert_eq(kalev.animation_player().current_animation, &"2H_Melee_Attack_Chop")
	assert_eq(
		kalev.animation_player().get_animation(&"2H_Melee_Attack_Chop").loop_mode,
		Animation.LOOP_NONE,
		"Charged hammer attack must be a one-shot two-handed chop"
	)
	kalev.queue_free()


func test_hammer_profiles_match_authored_contact_frames_and_heavy_time_curve() -> void:
	_ensure_content_loaded()
	var player := _create_player()
	_equip_hammer()
	var light := AttackProfileResolver.resolve_for_state(SessionState.state, SessionState.content_db, false)
	var charged := AttackProfileResolver.resolve_for_state(SessionState.state, SessionState.content_db, true)

	assert_true(is_equal_approx(
		light.impact_timing_sec,
		SharedCharacterRig.hammer_impact_sec(&"hammer_attack")
	))
	assert_true(is_equal_approx(
		light.attack_duration_sec,
		SharedCharacterRig.hammer_action_duration_sec(&"hammer_attack")
	))
	assert_true(is_equal_approx(
		charged.impact_timing_sec,
		SharedCharacterRig.hammer_impact_sec(&"hammer_charged_attack")
	))
	assert_true(is_equal_approx(
		charged.attack_duration_sec,
		SharedCharacterRig.hammer_action_duration_sec(&"hammer_charged_attack")
	))
	# Damage is intentionally unchanged; weight comes from posing and timing.
	assert_eq(light.damage, 14.0)
	assert_eq(charged.damage, 24.0)

	var light_contact := SharedCharacterRig.hammer_source_time(&"hammer_attack", 0.34, 1.042)
	assert_true(is_equal_approx(light_contact, 0.68))
	assert_true(
		is_equal_approx(
			SharedCharacterRig.hammer_source_time(&"hammer_attack", 0.38, 1.042),
			light_contact
		),
		"Light contact pose must hold briefly before recoil"
	)
	assert_true(
		SharedCharacterRig.hammer_source_time(&"hammer_attack", 0.50, 1.042) > light_contact,
		"Light attack must continue into follow-through after hit-stop"
	)
	assert_true(
		SharedCharacterRig.hammer_source_time(&"hammer_attack", 0.30, 1.042)
		- SharedCharacterRig.hammer_source_time(&"hammer_attack", 0.17, 1.042)
		> SharedCharacterRig.hammer_source_time(&"hammer_attack", 0.17, 1.042),
		"Downswing must cover more clip time than the longer anticipation interval"
	)

	var charged_contact := SharedCharacterRig.hammer_source_time(&"hammer_charged_attack", 0.50, 1.625)
	assert_true(is_equal_approx(charged_contact, 0.88))
	assert_true(is_equal_approx(
		SharedCharacterRig.hammer_source_time(&"hammer_charged_attack", 0.58, 1.625),
		charged_contact
	))
	assert_true(charged.attack_duration_sec > light.attack_duration_sec)
	player.free()


func test_sync_action_presentation_tolerates_cleared_animation_player() -> void:
	# WHY: After a one-shot clip ends, AnimationPlayer.current_animation can be
	# empty while the canonical attack name is still active. Startup/map sync
	# must not crash on animation.length of a null resource.
	var kalev := _create_kalev()
	assert_true(kalev.play_animation(&"hammer_attack", 0.0))
	kalev.animation_player().stop()
	kalev.sync_action_presentation(&"hammer_attack", 0.17)
	assert_eq(kalev.current_canonical_animation(), &"hammer_attack")
	kalev.queue_free()


func test_each_hammer_swing_resolves_once_and_whiff_has_no_feedback() -> void:
	var player := _create_player()
	_equip_hammer()
	player.global_position = Vector2.ZERO
	player.set_view_facing(Vector2.RIGHT)
	player.stamina = 100.0
	var shake_amounts: Array[float] = []
	var resolutions := [0]
	var actors := _bind_feedback(player, shake_amounts)
	player.melee_attack_resolved.connect(
		func(_targets: Array[Node2D], _profile: AttackProfile) -> void: resolutions[0] += 1
	)

	assert_true(player.commit_attack_from_charge_hold(0.05))
	_advance(player.action_state_machine, player.action_state_machine.attack_duration_sec + 0.05)
	assert_eq(resolutions[0], 1, "One hammer swing must emit one resolution pulse")
	assert_eq(shake_amounts, [], "A hammer whiff must not request screen shake")

	_advance(player.action_state_machine, player.action_state_machine.recovery_duration_sec + 0.05)
	var target := _create_dummy(Vector2(32.0, 0.0))
	assert_true(player.commit_attack_from_charge_hold(0.40))
	_advance(player.action_state_machine, player.action_state_machine.attack_duration_sec + 0.05)
	assert_eq(resolutions[0], 2, "A later swing gets one fresh resolution pulse")
	assert_eq(shake_amounts.size(), 1, "Only the successful hammer hit requests feedback")
	assert_true(is_equal_approx(shake_amounts[0], 0.28), "Charged hit uses restrained stronger shake")

	target.free()
	player.free()
	# Keep the controller alive through both signal emissions.
	assert_true(actors != null)


func _bind_feedback(player: Player, shake_amounts: Array[float]) -> MapViewRuntimeActors:
	var actors := MapViewRuntimeActors.new()
	actors.configure(null, null, player, null, null, Callable(), Callable())
	actors.set_screen_shake_callback(
		func(amount: float) -> void: shake_amounts.append(amount)
	)
	return actors


func _advance(machine: PlayerActionStateMachine, duration_sec: float) -> void:
	var remaining := duration_sec
	while remaining > 0.0:
		var step := minf(TEST_DELTA, remaining)
		machine.tick(step)
		remaining -= step


func _create_kalev() -> SharedCharacterRig:
	var kalev := KALEV_SCENE.instantiate() as SharedCharacterRig
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(kalev)
	return kalev


func _create_dummy(position: Vector2) -> CombatTestDummy:
	var dummy := COMBAT_TEST_DUMMY.new() as CombatTestDummy
	dummy.global_position = position
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(dummy)
	return dummy


func _create_player() -> Player:
	_ensure_content_loaded()
	var player := PLAYER_SCENE.instantiate() as Player
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(player)
	return player


func _equip_hammer() -> void:
	if SessionState.state.equipped_item(&"right_hand") == ITEM_HAMMER:
		return
	if not SessionState.state.equipped_item(&"right_hand").is_empty():
		assert_true(SessionState.state.unequip_to_bag(&"right_hand"))
	if SessionState.state.bag.find_placement(ITEM_HAMMER) == null:
		assert_eq(SessionState.state.bag.try_add(ITEM_HAMMER), InventoryBag.AddResult.OK)
	assert_true(SessionState.state.equip_from_bag(&"right_hand", ITEM_HAMMER))


func _ensure_content_loaded() -> void:
	if not SessionState.content_db.is_loaded():
		assert_true(SessionState.content_db.load_from_directories(SessionState.DEMO_CONTENT_DIRS))
	SessionState.state.bag.set_content_db(SessionState.content_db)
