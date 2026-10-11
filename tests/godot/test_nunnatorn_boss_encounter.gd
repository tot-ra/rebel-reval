extends "res://tests/godot/test_case.gd"

## R-625: Nunnatorn's named boss uses the shared outcome resolver.
## The alternate branch is bypass/non-lethal and must leave both actors alive.

const ENCOUNTER_ID := &"encounter.nunnatorn_boss"
const TEST_DELTA := 0.05


func test_content_definition_exposes_named_boss_outcomes() -> void:
	var db := ContentDB.new()
	assert_true(db.load_from_directories(SessionState.DEMO_CONTENT_DIRS))
	var definition := NunnatornBossEncounter.definition_from_content(db)
	assert_eq(definition.encounter_id, ENCOUNTER_ID)
	assert_eq(definition.quest_id, NunnatornBossEncounter.QUEST_ID)
	assert_true(definition.supports(EncounterOutcome.KIND_KILL))
	assert_true(definition.supports(EncounterOutcome.KIND_BYPASS))
	assert_false(definition.supports(EncounterOutcome.KIND_ESCAPE))
	assert_false(definition.supports(EncounterOutcome.KIND_SURRENDER))
	assert_eq(
		definition.quest_state_for(EncounterOutcome.KIND_KILL),
		&"night_fought"
	)
	assert_eq(
		definition.quest_state_for(EncounterOutcome.KIND_BYPASS),
		&"night_bypassed"
	)


func test_deterministic_composition_and_readable_anchors() -> void:
	var composition := NunnatornBossEncounter.enemy_composition()
	assert_eq(composition.size(), 2)
	assert_eq(composition[0]["id"], NunnatornBossEncounter.BOSS_ID)
	assert_eq(composition[0]["display_name"], NunnatornBossEncounter.BOSS_NAME)
	assert_eq(composition[0]["archetype_id"], EnemyArchetype.ID_SERGEANT)
	assert_eq(composition[0]["role"], "named_boss")
	assert_eq(composition[1]["archetype_id"], EnemyArchetype.ID_WATCHMAN)
	assert_eq(composition[1]["role"], "escort")
	for member in composition:
		assert_eq(member["anchor_id"], NunnatornBossEncounter.ENTRY_ANCHOR_ID)
	var anchors := NunnatornBossEncounter.authored_anchors()
	assert_eq(anchors["entry"], &"nunnatorn_boss")
	assert_eq(anchors["alternate"], &"nunnatorn_boss_alternate_resolution")
	assert_eq(anchors["exit"], &"nunnatorn_exit")


func test_alternate_bypass_resolves_and_keeps_boss_and_guard_alive() -> void:
	var db := _content_db()
	var state := GameState.new()
	state.set_quest_state(NunnatornBossEncounter.QUEST_ID, &"active")
	var boss := _machine(EnemyArchetype.sergeant())
	var guard := _machine(EnemyArchetype.watchman())
	_advance_to_telegraph(boss)
	_advance_to_telegraph(guard)

	assert_true(
		NunnatornBossEncounter.resolve(
			state, db, EncounterOutcome.KIND_BYPASS, [boss, guard]
		),
		"Nunnatorn alternate route must resolve"
	)
	assert_eq(state.get_quest_state(NunnatornBossEncounter.QUEST_ID), &"night_bypassed")
	assert_true(state.get_flag(NunnatornBossEncounter.RESOLVED_FLAG))
	assert_true(state.get_flag(NunnatornBossEncounter.ALTERNATE_FLAG))
	assert_false(state.get_flag(NunnatornBossEncounter.DEFEATED_FLAG))
	for machine in [boss, guard]:
		assert_false(machine.is_dead(), "Alternate route must not kill actors")
		assert_eq(machine.state, EnemyCombatState.State.DISENGAGE)


func test_lethal_kill_marks_boss_dead_and_keeps_lethal_branch_distinct() -> void:
	var db := _content_db()
	var state := GameState.new()
	state.set_quest_state(NunnatornBossEncounter.QUEST_ID, &"active")
	var boss := _machine(EnemyArchetype.sergeant())
	var guard := _machine(EnemyArchetype.watchman())

	assert_true(
		NunnatornBossEncounter.resolve(
			state, db, EncounterOutcome.KIND_KILL, [boss, guard]
		),
		"Nunnatorn lethal route must resolve"
	)
	assert_eq(state.get_quest_state(NunnatornBossEncounter.QUEST_ID), &"night_fought")
	assert_true(state.get_flag(NunnatornBossEncounter.RESOLVED_FLAG))
	assert_true(state.get_flag(NunnatornBossEncounter.DEFEATED_FLAG))
	assert_false(state.get_flag(NunnatornBossEncounter.ALTERNATE_FLAG))
	assert_true(boss.is_dead(), "Lethal route must mark the named boss dead")
	assert_true(guard.is_dead(), "Lethal route must close the guard as part of the fight")


func test_unsupported_outcome_fails_closed_without_state_or_enemy_mutation() -> void:
	var db := _content_db()
	var state := GameState.new()
	state.set_quest_state(NunnatornBossEncounter.QUEST_ID, &"active")
	var boss := _machine(EnemyArchetype.sergeant())
	boss.set_perception(true, 20.0)
	_advance_to_telegraph(boss)
	var original_state := boss.state

	assert_false(
		NunnatornBossEncounter.resolve(state, db, &"bribe", [boss]),
		"Unsupported outcomes must fail closed"
	)
	assert_eq(state.get_quest_state(NunnatornBossEncounter.QUEST_ID), &"active")
	assert_false(state.get_flag(NunnatornBossEncounter.RESOLVED_FLAG))
	assert_false(state.get_flag(NunnatornBossEncounter.DEFEATED_FLAG))
	assert_false(state.get_flag(NunnatornBossEncounter.ALTERNATE_FLAG))
	assert_eq(boss.state, original_state)
	assert_false(boss.is_dead())


func _content_db() -> ContentDB:
	var db := ContentDB.new()
	assert_true(db.load_from_directories(SessionState.DEMO_CONTENT_DIRS))
	return db


func _machine(profile: EnemyArchetype) -> EnemyCombatStateMachine:
	var machine := EnemyCombatStateMachine.new()
	machine.configure(profile)
	machine.set_perception(true, 20.0)
	return machine


func _advance_to_telegraph(machine: EnemyCombatStateMachine) -> void:
	var elapsed := 0.0
	while machine.state != EnemyCombatState.State.TELEGRAPH and elapsed < 2.0:
		machine.tick(TEST_DELTA)
		elapsed += TEST_DELTA
	assert_eq(machine.state, EnemyCombatState.State.TELEGRAPH)
