extends "res://tests/godot/test_case.gd"

## P1-027: combat reset checkpoint after failure.
## Player retries the encounter without replaying completed dialogue or
## corrupting quest state written before the fight.

const COMBAT_ROOM_SCENE := preload("res://scenes/tests/combat_room.tscn")
const DIALOGUE_ID := &"dialogue.mart_demo"
const DIALOGUE_NODE := "greeting"
const QUEST_ID := &"quest.bitter_brew"
const PRIOR_QUEST_STATE := &"investigation_ready"


func test_checkpoint_restore_keeps_dialogue_and_prior_quest() -> void:
	var state := GameState.new()
	state.set_quest_state(QUEST_ID, PRIOR_QUEST_STATE)
	state.set_flag(&"flag.watch_checkpoint_resolved", false)
	state.mark_dialogue_node_seen(DIALOGUE_ID, DIALOGUE_NODE)
	assert_true(state.has_dialogue_node_seen(DIALOGUE_ID, DIALOGUE_NODE))

	var checkpoint := EncounterCheckpoint.new()
	assert_true(checkpoint.arm(state, &"encounter.watch_checkpoint"))
	assert_true(checkpoint.is_armed)
	assert_eq(checkpoint.armed_quest_state(QUEST_ID), PRIOR_QUEST_STATE)

	# Mid-fight corruption must not stick after restore.
	state.set_quest_state(QUEST_ID, &"night_fought")
	state.set_flag(&"flag.watch_checkpoint_resolved", true)
	state.mark_dialogue_node_seen(DIALOGUE_ID, "should_not_survive_if_after_arm")
	# Clear the pre-fight dialogue key to prove restore brings it back.
	state._dialogue_nodes_seen.clear()
	assert_false(state.has_dialogue_node_seen(DIALOGUE_ID, DIALOGUE_NODE))

	assert_true(checkpoint.mark_failed())
	assert_true(checkpoint.failure_pending)
	assert_true(checkpoint.restore(state))
	assert_false(checkpoint.failure_pending)
	assert_eq(state.get_quest_state(QUEST_ID), PRIOR_QUEST_STATE)
	assert_false(state.get_flag(&"flag.watch_checkpoint_resolved"))
	assert_true(
		state.has_dialogue_node_seen(DIALOGUE_ID, DIALOGUE_NODE),
		"Completed pre-fight dialogue must survive retry"
	)
	assert_false(
		state.has_dialogue_node_seen(DIALOGUE_ID, "should_not_survive_if_after_arm"),
		"Post-arm dialogue must not invent progress on restore"
	)


func test_checkpoint_rejects_restore_when_unarmed() -> void:
	var state := GameState.new()
	state.set_quest_state(QUEST_ID, PRIOR_QUEST_STATE)
	var checkpoint := EncounterCheckpoint.new()
	assert_false(checkpoint.mark_failed())
	assert_false(checkpoint.restore(state))
	assert_eq(state.get_quest_state(QUEST_ID), PRIOR_QUEST_STATE)


func test_combat_room_death_retry_preserves_dialogue_and_quest() -> void:
	var room: CombatRoom = _mount_room()
	SessionState.state.set_quest_state(QUEST_ID, PRIOR_QUEST_STATE)
	SessionState.state.set_flag(&"flag.watch_checkpoint_resolved", false)
	SessionState.state.mark_dialogue_node_seen(DIALOGUE_ID, DIALOGUE_NODE)
	assert_true(room.arm_encounter_checkpoint())

	var player: Player = room.get_player()
	assert_true(player != null)
	var retry_button: Button = room.get_retry_button()
	assert_true(retry_button != null)
	assert_false(retry_button.visible, "Retry stays hidden until failure")

	# Simulate lethal hit without writing an encounter outcome.
	player.health = 1.0
	player.combat_vitals.configure(1.0, player.max_health, player.stamina, player.max_stamina)
	player.take_damage(50.0, null, &"", 4242, false)
	assert_true(player.is_combat_dead())
	assert_true(room.get_encounter_checkpoint().failure_pending)
	assert_true(retry_button.visible, "Retry must be mouse-reachable after death")
	assert_false(retry_button.disabled)

	# Corrupt quest as a false failure path would; retry must undo it.
	SessionState.state.set_quest_state(QUEST_ID, &"night_fought")
	SessionState.state.set_flag(&"flag.watch_checkpoint_resolved", true)
	SessionState.state._dialogue_nodes_seen.clear()

	retry_button.pressed.emit()
	assert_false(player.is_combat_dead(), "Retry must revive the player actor")
	assert_eq(player.health, player.max_health)
	assert_eq(SessionState.state.get_quest_state(QUEST_ID), PRIOR_QUEST_STATE)
	assert_false(SessionState.state.get_flag(&"flag.watch_checkpoint_resolved"))
	assert_true(SessionState.state.has_dialogue_node_seen(DIALOGUE_ID, DIALOGUE_NODE))
	assert_false(retry_button.visible, "Retry hides after a successful restore")
	assert_false(room.get_watchman().get_machine().is_dead())
	assert_false(room.get_sergeant().get_machine().is_dead())

	var log_label := room.get_feedback().find_child("EventLog", true, false) as Label
	assert_true(log_label != null)
	assert_true("Retry from checkpoint" in log_label.text)
	_free_room(room)


func test_successful_outcome_clears_checkpoint() -> void:
	var room: CombatRoom = _mount_room()
	SessionState.state.set_quest_state(QUEST_ID, PRIOR_QUEST_STATE)
	assert_true(room.arm_encounter_checkpoint())
	assert_true(room.get_encounter_checkpoint().is_armed)
	assert_true(room.resolve_encounter_outcome(EncounterOutcome.KIND_ESCAPE))
	assert_false(room.get_encounter_checkpoint().is_armed)
	assert_eq(SessionState.state.get_quest_state(QUEST_ID), &"night_escaped")
	_free_room(room)


func _mount_room() -> CombatRoom:
	if not SessionState.content_db.is_loaded():
		assert_true(SessionState.content_db.load_from_directories(SessionState.DEMO_CONTENT_DIRS))
	if SessionState.state == null:
		SessionState.state = GameState.new()
	SessionState.state.bag.set_content_db(SessionState.content_db)
	SessionState.state.set_quest_state(QUEST_ID, &"")
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
