extends "res://tests/godot/test_case.gd"

## P5-008: Order knight and crossbowman reuse the shared enemy state machine;
## mission allies apply scripted support without party-control UI.

const TEST_DELTA := 0.05


func test_knight_and_crossbowman_share_enemy_combat_state_machine() -> void:
	var knight_machine := _make_machine(EnemyArchetype.knight_order())
	var crossbow_machine := _make_machine(EnemyArchetype.crossbowman())
	assert_true(knight_machine is EnemyCombatStateMachine)
	assert_true(crossbow_machine is EnemyCombatStateMachine)
	assert_eq(knight_machine.get_script(), crossbow_machine.get_script())
	assert_eq(knight_machine.archetype.id, EnemyArchetype.ID_KNIGHT_ORDER)
	assert_eq(crossbow_machine.archetype.id, EnemyArchetype.ID_CROSSBOWMAN)


func test_from_id_resolves_all_four_archetypes() -> void:
	assert_eq(EnemyArchetype.from_id(EnemyArchetype.ID_WATCHMAN).id, EnemyArchetype.ID_WATCHMAN)
	assert_eq(EnemyArchetype.from_id(EnemyArchetype.ID_SERGEANT).id, EnemyArchetype.ID_SERGEANT)
	assert_eq(EnemyArchetype.from_id(EnemyArchetype.ID_KNIGHT_ORDER).id, EnemyArchetype.ID_KNIGHT_ORDER)
	assert_eq(EnemyArchetype.from_id(EnemyArchetype.ID_CROSSBOWMAN).id, EnemyArchetype.ID_CROSSBOWMAN)
	assert_eq(EnemyArchetype.from_id(&"enemy.unknown").id, EnemyArchetype.ID_WATCHMAN)


func test_knight_and_crossbowman_complete_detect_to_disengage_loop() -> void:
	_assert_full_combat_loop(EnemyArchetype.knight_order())
	_assert_full_combat_loop(EnemyArchetype.crossbowman())


func test_new_archetype_attack_profiles_differ_from_slice_defaults() -> void:
	var knight := EnemyArchetype.knight_order().make_attack_profile()
	var crossbow := EnemyArchetype.crossbowman().make_attack_profile()
	var watch := EnemyArchetype.watchman().make_attack_profile()
	assert_true(knight.damage > watch.damage)
	assert_ne(knight.animation, crossbow.animation)
	assert_eq(crossbow.damage_type, &"pierce")


func test_mission_ally_heals_player_in_range_without_input() -> void:
	var ally := MissionAllyController.new()
	ally.configure(MissionAllyScript.healer())
	var player := CombatTestDummy.new()
	player.configure_resources(8.0, 20.0, 20.0, 40.0)
	var ally_position := Vector2.ZERO
	var player_position := Vector2(40.0, 0.0)
	player.global_position = player_position
	var healed_total := 0.0
	ally.support_applied.connect(func(_id: StringName, amount: float) -> void: healed_total += amount)
	var elapsed := 0.0
	while elapsed < 4.0:
		healed_total += ally.tick(TEST_DELTA, ally_position, player)
		elapsed += TEST_DELTA
	assert_true(player.health > 8.0, "Allied healer must restore health automatically")
	assert_true(healed_total >= MissionAllyScript.healer().heal_amount)


func test_mission_ally_does_not_heal_out_of_range() -> void:
	var ally := MissionAllyController.new()
	ally.configure(MissionAllyScript.healer())
	var player := CombatTestDummy.new()
	player.configure_resources(8.0, 20.0, 20.0, 40.0)
	player.global_position = Vector2(500.0, 0.0)
	var healed := 0.0
	for _i in range(80):
		healed += ally.tick(TEST_DELTA, Vector2.ZERO, player)
	assert_eq(healed, 0.0)
	assert_eq(player.health, 8.0)


func test_mission_ally_profiles_are_scripted_not_player_controlled() -> void:
	var healer := MissionAllyScript.healer()
	var vanguard := MissionAllyScript.vanguard()
	assert_ne(healer.id, vanguard.id)
	assert_true(vanguard.heal_amount > healer.heal_amount)
	assert_eq(MissionAllyScript.from_id(healer.id).id, healer.id)


func _assert_full_combat_loop(profile: EnemyArchetype) -> void:
	var machine := _make_machine(profile)
	var impacts := [0]
	machine.attack_impact.connect(func() -> void: impacts[0] += 1)
	var approach := minf(profile.detect_radius * 0.8, profile.engage_radius + 8.0)
	if approach <= profile.engage_radius:
		approach = profile.engage_radius + 4.0
	machine.set_perception(true, approach)
	_advance_until(machine, EnemyCombatState.State.DETECT, 1.0)
	machine.set_perception(true, profile.engage_radius * 0.4)
	_advance_until(machine, EnemyCombatState.State.ATTACK, 3.0)
	_advance(machine, profile.attack_duration_sec + TEST_DELTA)
	assert_eq(impacts[0], 1, "%s must emit one attack impact" % String(profile.id))


func _make_machine(profile: EnemyArchetype) -> EnemyCombatStateMachine:
	var machine := EnemyCombatStateMachine.new()
	machine.configure(profile)
	return machine


func _advance(machine: EnemyCombatStateMachine, seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.0:
		var step := minf(TEST_DELTA, remaining)
		machine.tick(step)
		remaining -= step


func _advance_until(
	machine: EnemyCombatStateMachine,
	desired: EnemyCombatState.State,
	budget_sec: float
) -> void:
	var elapsed := 0.0
	while machine.state != desired and elapsed < budget_sec:
		machine.tick(TEST_DELTA)
		elapsed += TEST_DELTA
	assert_eq(machine.state, desired)
