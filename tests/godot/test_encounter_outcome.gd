extends "res://tests/godot/test_case.gd"

## P1-026: authored surrender, escape, or bypass encounter outcomes.
## One encounter must resolve without killing and update the same GameState
## quest keys that a lethal combat close uses.

const COMBAT_ROOM_SCENE := preload("res://scenes/tests/combat_room.tscn")
const TEST_DELTA := 0.05


func test_definition_maps_all_outcome_kinds_to_quest_states() -> void:
	var definition := EncounterOutcomeDefinition.watch_checkpoint()
	assert_eq(definition.encounter_id, &"encounter.watch_checkpoint")
	assert_eq(definition.quest_id, &"quest.bitter_brew")
	for kind in EncounterOutcome.ALL_KINDS:
		assert_true(definition.supports(kind), "Definition must support %s" % String(kind))
		assert_false(definition.quest_state_for(kind).is_empty())


func test_non_lethal_outcomes_resolve_without_killing_and_update_quest_state() -> void:
	var state := GameState.new()
	var definition := EncounterOutcomeDefinition.watch_checkpoint()
	var resolver := EncounterOutcomeResolver.new()
	var watch := EnemyCombatStateMachine.new()
	watch.configure(EnemyArchetype.watchman())
	watch.set_perception(true, 40.0)
	_advance_until(watch, EnemyCombatState.State.TELEGRAPH, 2.0)
	assert_eq(watch.state, EnemyCombatState.State.TELEGRAPH)
	var health_proxy_alive := true

	assert_true(
		resolver.resolve(state, definition, EncounterOutcome.KIND_ESCAPE, [watch]),
		"Escape must resolve"
	)
	assert_eq(state.get_quest_state(definition.quest_id), &"night_escaped")
	assert_true(state.get_flag(definition.resolved_flag))
	assert_eq(watch.state, EnemyCombatState.State.DISENGAGE)
	assert_false(watch.is_dead(), "Escape must not kill")
	assert_true(health_proxy_alive)

	watch.reset()
	watch.set_perception(true, 40.0)
	_advance_until(watch, EnemyCombatState.State.ATTACK, 3.0)
	assert_true(resolver.resolve(state, definition, EncounterOutcome.KIND_SURRENDER, [watch]))
	assert_eq(state.get_quest_state(definition.quest_id), &"night_surrendered")
	assert_false(watch.is_dead())

	watch.reset()
	watch.set_perception(true, 30.0)
	_advance_until(watch, EnemyCombatState.State.DETECT, 1.0)
	assert_true(resolver.resolve(state, definition, EncounterOutcome.KIND_BYPASS, [watch]))
	assert_eq(state.get_quest_state(definition.quest_id), &"night_bypassed")
	assert_eq(watch.state, EnemyCombatState.State.DISENGAGE)
	assert_false(watch.is_dead())


func test_lethal_and_non_lethal_share_the_same_quest_contract() -> void:
	var state := GameState.new()
	var definition := EncounterOutcomeDefinition.watch_checkpoint()
	var resolver := EncounterOutcomeResolver.new()
	var machine := EnemyCombatStateMachine.new()
	machine.configure(EnemyArchetype.sergeant())
	machine.set_perception(true, 20.0)
	_advance_until(machine, EnemyCombatState.State.TELEGRAPH, 2.0)

	assert_true(resolver.resolve(state, definition, EncounterOutcome.KIND_BYPASS, [machine]))
	var non_lethal_quest := state.get_quest_state(definition.quest_id)
	assert_eq(non_lethal_quest, &"night_bypassed")
	assert_eq(resolver.last_quest_id, definition.quest_id)

	machine.reset()
	machine.set_perception(true, 20.0)
	_advance_until(machine, EnemyCombatState.State.ATTACK, 3.0)
	assert_true(resolver.resolve(state, definition, EncounterOutcome.KIND_KILL, [machine]))
	assert_eq(state.get_quest_state(definition.quest_id), &"night_fought")
	assert_eq(resolver.last_quest_id, definition.quest_id)
	assert_true(machine.is_dead(), "Kill path may mark dead")
	assert_eq(resolver.last_quest_id, definition.quest_id)
	assert_ne(non_lethal_quest, &"night_fought")


func test_combat_room_mouse_buttons_resolve_escape_without_killing() -> void:
	var room: CombatRoom = _mount_room()
	assert_true(room.get_surrender_button() != null)
	assert_true(room.get_escape_button() != null)
	assert_true(room.get_bypass_button() != null)
	assert_false(room.get_escape_button().disabled, "Escape must be mouse-reachable")

	var watchman: CombatRoomEnemy = room.get_watchman()
	var sergeant: CombatRoomEnemy = room.get_sergeant()
	watchman.get_machine().set_perception(true, 40.0)
	sergeant.get_machine().set_perception(true, 40.0)
	room.advance_enemies(0.6)
	var watch_hp := watchman.health
	var sarge_hp := sergeant.health

	room.get_escape_button().pressed.emit()
	assert_eq(SessionState.state.get_quest_state(&"quest.bitter_brew"), &"night_escaped")
	assert_true(SessionState.state.get_flag(&"flag.watch_checkpoint_resolved"))
	assert_false(watchman.get_machine().is_dead())
	assert_false(sergeant.get_machine().is_dead())
	assert_eq(watchman.health, watch_hp, "Escape must not change HP")
	assert_eq(sergeant.health, sarge_hp)
	assert_eq(watchman.get_machine().state, EnemyCombatState.State.DISENGAGE)
	assert_eq(sergeant.get_machine().state, EnemyCombatState.State.DISENGAGE)

	var log_label := room.get_feedback().find_child("EventLog", true, false) as Label
	assert_true(log_label != null)
	assert_true("Encounter escape" in log_label.text, "Room must log the outcome")
	_free_room(room)


func test_unknown_outcome_is_rejected_without_mutating_quest_state() -> void:
	var state := GameState.new()
	state.set_quest_state(&"quest.bitter_brew", &"active")
	var definition := EncounterOutcomeDefinition.watch_checkpoint()
	var resolver := EncounterOutcomeResolver.new()
	var ok := resolver.resolve(state, definition, &"bribe", [])
	assert_false(ok)
	assert_eq(state.get_quest_state(&"quest.bitter_brew"), &"active")
	assert_false(state.get_flag(&"flag.watch_checkpoint_resolved"))


func _mount_room() -> CombatRoom:
	if not SessionState.content_db.is_loaded():
		assert_true(SessionState.content_db.load_from_directories(SessionState.DEMO_CONTENT_DIRS))
	if SessionState.state == null:
		SessionState.state = GameState.new()
	SessionState.state.bag.set_content_db(SessionState.content_db)
	SessionState.state.set_quest_state(&"quest.bitter_brew", &"")
	SessionState.state.set_flag(&"flag.watch_checkpoint_resolved", false)
	var room: CombatRoom = COMBAT_ROOM_SCENE.instantiate() as CombatRoom
	var tree := Engine.get_main_loop() as SceneTree
	assert_true(tree != null, "SceneTree required to mount combat room")
	tree.root.add_child(room)
	room.ensure_built()
	return room


func _free_room(room: CombatRoom) -> void:
	if room != null and is_instance_valid(room):
		room.free()


func _advance_until(
	machine: EnemyCombatStateMachine, desired: EnemyCombatState.State, budget_sec: float
) -> void:
	var elapsed := 0.0
	while machine.state != desired and elapsed < budget_sec:
		machine.tick(TEST_DELTA)
		elapsed += TEST_DELTA
	assert_eq(
		machine.state,
		desired,
		"Timed out waiting for %s (last=%s)"
		% [
			EnemyCombatState.display_name(desired),
			EnemyCombatState.display_name(machine.state),
		]
	)
