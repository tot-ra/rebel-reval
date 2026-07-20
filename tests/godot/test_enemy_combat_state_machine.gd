extends "res://tests/godot/test_case.gd"

## P1-025: shared watchman/sergeant enemy state machine.
## Both archetypes must complete patrol → detect → telegraph → attack →
## react → disengage through one controller class.

const TEST_DELTA := 0.05


func test_watchman_and_sergeant_share_one_controller_class() -> void:
	var watch_machine := _make_machine(EnemyArchetype.watchman())
	var sarge_machine := _make_machine(EnemyArchetype.sergeant())
	assert_true(watch_machine is EnemyCombatStateMachine)
	assert_true(sarge_machine is EnemyCombatStateMachine)
	assert_eq(watch_machine.get_script(), sarge_machine.get_script())
	assert_ne(watch_machine.archetype.id, sarge_machine.archetype.id)
	assert_eq(watch_machine.archetype.id, EnemyArchetype.ID_WATCHMAN)
	assert_eq(sarge_machine.archetype.id, EnemyArchetype.ID_SERGEANT)


func test_watchman_completes_detect_to_disengage_loop() -> void:
	_assert_full_combat_loop(EnemyArchetype.watchman())


func test_sergeant_completes_detect_to_disengage_loop() -> void:
	_assert_full_combat_loop(EnemyArchetype.sergeant())


func test_react_interrupts_telegraph_then_resumes_combat() -> void:
	var machine := _make_machine(EnemyArchetype.watchman())
	machine.set_perception(true, 40.0)
	_advance_until(machine, EnemyCombatState.State.TELEGRAPH, 2.0)
	assert_eq(machine.state, EnemyCombatState.State.TELEGRAPH)

	machine.apply_hit()
	assert_eq(machine.state, EnemyCombatState.State.REACT, "Hit must enter REACT")
	_advance_until(machine, EnemyCombatState.State.TELEGRAPH, 2.0)
	assert_eq(
		machine.state,
		EnemyCombatState.State.TELEGRAPH,
		"React should resume telegraph when target remains engaged"
	)


func test_patrol_hit_enters_detect_without_stuck_state() -> void:
	var machine := _make_machine(EnemyArchetype.sergeant())
	assert_eq(machine.state, EnemyCombatState.State.PATROL)
	machine.apply_hit()
	assert_eq(machine.state, EnemyCombatState.State.DETECT)
	machine.set_perception(true, 50.0)
	_advance_until(machine, EnemyCombatState.State.ATTACK, 3.0)
	assert_eq(machine.state, EnemyCombatState.State.ATTACK)
	_advance(machine, machine.archetype.attack_duration_sec + 0.05)
	assert_true(
		machine.state == EnemyCombatState.State.TELEGRAPH
		or machine.state == EnemyCombatState.State.DISENGAGE
		or machine.state == EnemyCombatState.State.ATTACK,
		"Post-attack must stay in a known combat or disengage state"
	)


func test_attack_emits_one_impact_per_swing_for_both_archetypes() -> void:
	for profile in [EnemyArchetype.watchman(), EnemyArchetype.sergeant()]:
		var machine := _make_machine(profile)
		var impacts := [0]
		machine.attack_impact.connect(func() -> void: impacts[0] += 1)
		machine.set_perception(true, minf(40.0, profile.engage_radius * 0.5))
		_advance_until(machine, EnemyCombatState.State.ATTACK, 3.0)
		_advance(machine, profile.attack_duration_sec + TEST_DELTA)
		assert_eq(impacts[0], 1, "%s must emit one impact per attack" % String(profile.id))


func test_archetype_attack_profiles_differ_without_forked_controllers() -> void:
	var watch := EnemyArchetype.watchman().make_attack_profile()
	var sarge := EnemyArchetype.sergeant().make_attack_profile()
	assert_true(sarge.damage > watch.damage, "Sergeant should hit harder than watchman")
	assert_true(
		EnemyArchetype.sergeant().telegraph_duration_sec
		< EnemyArchetype.watchman().telegraph_duration_sec,
		"Sergeant telegraph should be shorter/harder to read"
	)
	assert_ne(watch.animation, sarge.animation)


func test_mark_dead_locks_state_machine() -> void:
	var machine := _make_machine(EnemyArchetype.watchman())
	machine.set_perception(true, 30.0)
	_advance_until(machine, EnemyCombatState.State.TELEGRAPH, 2.0)
	var deaths := [0]
	machine.died.connect(func() -> void: deaths[0] += 1)
	machine.mark_dead()
	assert_eq(machine.state, EnemyCombatState.State.DEAD)
	assert_eq(deaths[0], 1)
	machine.apply_hit()
	machine.set_perception(true, 10.0)
	_advance(machine, 1.0)
	assert_eq(machine.state, EnemyCombatState.State.DEAD)
	assert_eq(deaths[0], 1)


func _assert_full_combat_loop(profile: EnemyArchetype) -> void:
	var machine := _make_machine(profile)
	var trail: Array[String] = []
	machine.state_changed.connect(
		func(_previous: EnemyCombatState.State, current: EnemyCombatState.State) -> void:
			trail.append(EnemyCombatState.display_name(current))
	)
	var detected := [0]
	var telegraphed := [0]
	var impacts := [0]
	var disengaged := [0]
	machine.detected.connect(func() -> void: detected[0] += 1)
	machine.telegraphed.connect(func() -> void: telegraphed[0] += 1)
	machine.attack_impact.connect(func() -> void: impacts[0] += 1)
	machine.disengaged.connect(func() -> void: disengaged[0] += 1)

	assert_eq(machine.state, EnemyCombatState.State.PATROL)
	# Enter detect inside detect radius but outside engage so the first attack
	# finishes into disengage rather than looping telegraph forever.
	var approach := minf(profile.detect_radius * 0.8, profile.engage_radius + 8.0)
	if approach <= profile.engage_radius:
		approach = profile.engage_radius + 4.0
	machine.set_perception(true, approach)
	_advance_until(machine, EnemyCombatState.State.DETECT, 1.0)
	assert_eq(machine.state, EnemyCombatState.State.DETECT)

	# Close in during detect so telegraph/attack can fire, then open distance
	# after the swing so disengage wins.
	machine.set_perception(true, profile.engage_radius * 0.4)
	_advance_until(machine, EnemyCombatState.State.TELEGRAPH, 2.0)
	assert_eq(machine.state, EnemyCombatState.State.TELEGRAPH)
	_advance_until(machine, EnemyCombatState.State.ATTACK, 2.0)
	assert_eq(machine.state, EnemyCombatState.State.ATTACK)

	machine.apply_hit()
	assert_eq(machine.state, EnemyCombatState.State.REACT)
	_advance_until(machine, EnemyCombatState.State.TELEGRAPH, 2.0)
	assert_eq(machine.state, EnemyCombatState.State.TELEGRAPH)

	_advance_until(machine, EnemyCombatState.State.ATTACK, 2.0)
	assert_eq(machine.state, EnemyCombatState.State.ATTACK)
	# After impact, leave engage range so the machine disengages.
	_advance(machine, profile.attack_impact_sec + TEST_DELTA)
	machine.set_perception(true, profile.lose_sight_radius + 20.0)
	_advance_until(machine, EnemyCombatState.State.DISENGAGE, 2.0)
	assert_eq(machine.state, EnemyCombatState.State.DISENGAGE)
	_advance_until(machine, EnemyCombatState.State.PATROL, 2.0)
	assert_eq(machine.state, EnemyCombatState.State.PATROL)

	assert_true(detected[0] >= 1, "%s must emit detect" % String(profile.id))
	assert_true(telegraphed[0] >= 1, "%s must emit telegraph" % String(profile.id))
	assert_true(impacts[0] >= 1, "%s must emit attack impact" % String(profile.id))
	assert_true(disengaged[0] >= 1, "%s must emit disengage" % String(profile.id))
	for required in ["detect", "telegraph", "attack", "react", "disengage", "patrol"]:
		assert_array_contains(trail, required, "%s trail missing %s" % [String(profile.id), required])


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
	assert_eq(
		machine.state,
		desired,
		"Timed out waiting for %s (last=%s, elapsed=%.2f)" % [
			EnemyCombatState.display_name(desired),
			EnemyCombatState.display_name(machine.state),
			elapsed,
		]
	)
