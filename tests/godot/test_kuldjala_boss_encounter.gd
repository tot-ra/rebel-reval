extends "res://tests/godot/test_case.gd"

const KuldjalaBossEncounter := preload("res://scripts/combat/kuldjala_boss_encounter.gd")
const TEST_DELTA := 0.05


func test_kuldjala_content_and_composition_are_distinct() -> void:
	var db := ContentDB.new()
	assert_true(db.load_from_directories(SessionState.DEMO_CONTENT_DIRS))
	var definition := KuldjalaBossEncounter.definition_from_content(db)
	assert_eq(definition.encounter_id, KuldjalaBossEncounter.ENCOUNTER_ID)
	assert_true(definition.supports(EncounterOutcome.KIND_KILL))
	assert_true(definition.supports(EncounterOutcome.KIND_BYPASS))
	assert_false(definition.supports(EncounterOutcome.KIND_SURRENDER))
	var composition := KuldjalaBossEncounter.enemy_composition()
	assert_eq(composition.size(), 2)
	assert_eq(composition[0]["archetype_id"], EnemyArchetype.ID_WATCHMAN)
	assert_eq(composition[1]["archetype_id"], EnemyArchetype.ID_CROSSBOWMAN)
	assert_eq(composition[1]["anchor_id"], &"kuldjala_wall_walk")


func test_kill_and_ledger_bypass_produce_distinct_outcomes() -> void:
	var db := _content_db()
	var lethal := GameState.new()
	lethal.set_quest_state(KuldjalaBossEncounter.QUEST_ID, &"active")
	var lethal_boss := _machine(EnemyArchetype.watchman())
	var lethal_guard := _machine(EnemyArchetype.crossbowman())
	assert_true(KuldjalaBossEncounter.resolve(
		lethal, db, EncounterOutcome.KIND_KILL, [lethal_boss, lethal_guard]
	))
	assert_eq(lethal.get_quest_state(KuldjalaBossEncounter.QUEST_ID), &"night_fought")
	assert_true(lethal.get_flag(KuldjalaBossEncounter.DEFEATED_FLAG))
	assert_false(lethal.get_flag(KuldjalaBossEncounter.ALTERNATE_FLAG))
	assert_true(lethal_boss.is_dead())
	assert_true(lethal_guard.is_dead())

	var alternate := GameState.new()
	alternate.set_quest_state(KuldjalaBossEncounter.QUEST_ID, &"active")
	var alternate_boss := _machine(EnemyArchetype.watchman())
	var alternate_guard := _machine(EnemyArchetype.crossbowman())
	_advance_to_telegraph(alternate_boss)
	_advance_to_telegraph(alternate_guard)
	assert_true(KuldjalaBossEncounter.resolve(
		alternate, db, EncounterOutcome.KIND_BYPASS, [alternate_boss, alternate_guard]
	))
	assert_eq(alternate.get_quest_state(KuldjalaBossEncounter.QUEST_ID), &"night_bypassed")
	assert_true(alternate.get_flag(KuldjalaBossEncounter.ALTERNATE_FLAG))
	assert_false(alternate.get_flag(KuldjalaBossEncounter.DEFEATED_FLAG))
	for machine in [alternate_boss, alternate_guard]:
		assert_false(machine.is_dead())
		assert_eq(machine.state, EnemyCombatState.State.DISENGAGE)


func test_unsupported_outcome_fails_closed() -> void:
	var state := GameState.new()
	state.set_quest_state(KuldjalaBossEncounter.QUEST_ID, &"active")
	var boss := _machine(EnemyArchetype.watchman())
	var original_state := boss.state
	assert_false(KuldjalaBossEncounter.resolve(state, _content_db(), &"bribe", [boss]))
	assert_eq(state.get_quest_state(KuldjalaBossEncounter.QUEST_ID), &"active")
	assert_false(state.get_flag(KuldjalaBossEncounter.RESOLVED_FLAG))
	assert_eq(boss.state, original_state)


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
