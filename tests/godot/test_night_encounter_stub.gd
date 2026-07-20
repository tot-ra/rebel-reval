extends "res://tests/godot/test_case.gd"

## P1-025b / P1-027a: night-encounter stub reuses CombatRoomEnemy /
## EnemyCombatStateMachine outside the combat smoke room, boots both archetypes
## through one detect-to-disengage loop, wires EncounterCheckpoint Retry on
## player death, and stays unreachable from release demo navigation.

const STUB_SCENE := preload("res://scenes/tests/night_encounter_stub.tscn")
const STUB_PATH := "res://scenes/tests/night_encounter_stub.tscn"
const MANIFEST_PATH := "res://content/transitions/active_destinations.json"
const DIALOGUE_ID := &"dialogue.mart_demo"
const DIALOGUE_NODE := "greeting"
const QUEST_ID := &"quest.bitter_brew"
const PRIOR_QUEST_STATE := &"investigation_ready"


func test_night_stub_boots_watchman_and_sergeant_on_shared_machine() -> void:
	var stub: NightEncounterStub = _mount_stub()
	assert_true(stub.get_player() != null)
	assert_true(stub.get_watchman() != null)
	assert_true(stub.get_sergeant() != null)
	assert_eq(stub.get_watchman().get_machine().archetype.id, EnemyArchetype.ID_WATCHMAN)
	assert_eq(stub.get_sergeant().get_machine().archetype.id, EnemyArchetype.ID_SERGEANT)
	assert_eq(
		stub.get_watchman().get_machine().get_script(),
		stub.get_sergeant().get_machine().get_script(),
		"Night stub must reuse EnemyCombatStateMachine without a forked controller"
	)
	assert_eq(
		stub.get_watchman().get_script(),
		stub.get_sergeant().get_script(),
		"Night stub hosts must be CombatRoomEnemy instances"
	)
	assert_true(stub.get_feedback() != null)
	_free_stub(stub)


func test_watchman_completes_detect_to_disengage_in_night_stub() -> void:
	_assert_stub_enemy_loop(
		func(stub: NightEncounterStub) -> CombatRoomEnemy: return stub.get_watchman()
	)


func test_sergeant_completes_detect_to_disengage_in_night_stub() -> void:
	_assert_stub_enemy_loop(
		func(stub: NightEncounterStub) -> CombatRoomEnemy: return stub.get_sergeant()
	)


func test_night_stub_feedback_covers_detect_telegraph_and_attack() -> void:
	var stub: NightEncounterStub = _mount_stub()
	var enemy: CombatRoomEnemy = stub.get_watchman()
	var trail: Array = stub.run_enemy_detect_to_disengage_loop(enemy)
	var log_label := stub.get_feedback().find_child("EventLog", true, false) as Label
	assert_true(log_label != null)
	var log_text: String = log_label.text
	assert_true("Watchman: detect" in log_text, "Stub must log detect feedback")
	assert_true("Watchman: telegraph" in log_text, "Stub must log telegraph feedback")
	assert_true("Watchman: attack" in log_text, "Stub must log attack feedback")
	assert_true("Watchman: disengage" in log_text, "Stub must log disengage feedback")
	assert_array_contains(trail, "detect")
	assert_array_contains(trail, "telegraph")
	assert_array_contains(trail, "attack")
	_free_stub(stub)


func test_night_stub_death_retry_preserves_dialogue_and_quest() -> void:
	var stub: NightEncounterStub = _mount_stub()
	SessionState.state.set_quest_state(QUEST_ID, PRIOR_QUEST_STATE)
	SessionState.state.set_flag(&"flag.watch_checkpoint_resolved", false)
	SessionState.state.mark_dialogue_node_seen(DIALOGUE_ID, DIALOGUE_NODE)
	assert_true(stub.arm_encounter_checkpoint())

	var player: Player = stub.get_player()
	assert_true(player != null)
	var retry_button: Button = stub.get_retry_button()
	assert_true(retry_button != null)
	assert_false(retry_button.visible, "Retry stays hidden until failure")

	# Simulate lethal hit without writing an encounter outcome.
	player.health = 1.0
	player.combat_vitals.configure(1.0, player.max_health, player.stamina, player.max_stamina)
	player.take_damage(50.0, null, &"", 4242, false)
	assert_true(player.is_combat_dead())
	assert_true(stub.get_encounter_checkpoint().failure_pending)
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
	assert_false(stub.get_watchman().get_machine().is_dead())
	assert_false(stub.get_sergeant().get_machine().is_dead())

	var log_label := stub.get_feedback().find_child("EventLog", true, false) as Label
	assert_true(log_label != null)
	assert_true("Retry from checkpoint" in log_label.text)
	_free_stub(stub)


func test_night_stub_unreachable_from_release_demo_navigation() -> void:
	DoorNavigator.load_manifest(true)
	assert_false(
		DoorNavigator.has_active_scene(&"night_encounter_stub"),
		"Night stub must not be an active DoorNavigator destination"
	)
	assert_false(
		DoorNavigator.has_active_scene(&"night_encounter"),
		"Night stub alias must not be an active DoorNavigator destination"
	)
	for scene_id in DoorNavigator.get_active_scene_ids():
		assert_ne(
			DoorNavigator.get_scene_path(scene_id),
			STUB_PATH,
			"Active destination %s must not point at the night stub" % String(scene_id)
		)

	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	assert_true(file != null, "Transition manifest must open for reachability check")
	var parsed = JSON.parse_string(file.get_as_text())
	assert_eq(typeof(parsed), TYPE_DICTIONARY)
	var release_paths: Array = []
	for scene_record in parsed.get("scenes", []):
		if typeof(scene_record) != TYPE_DICTIONARY:
			continue
		var path := String(scene_record.get("path", ""))
		assert_ne(path, STUB_PATH, "Manifest must not register the night stub scene path")
		if bool(scene_record.get("release", false)):
			release_paths.append(path)
	assert_false(STUB_PATH in release_paths, "Night stub must stay out of release destinations")
	assert_true(NightEncounterStub.SCENE_PATH == STUB_PATH)


func _assert_stub_enemy_loop(pick_enemy: Callable) -> void:
	var stub: NightEncounterStub = _mount_stub()
	var enemy: CombatRoomEnemy = pick_enemy.call(stub) as CombatRoomEnemy
	assert_true(enemy != null)
	var trail := stub.run_enemy_detect_to_disengage_loop(enemy)
	assert_eq(enemy.get_machine().state, EnemyCombatState.State.PATROL)
	for required in ["detect", "telegraph", "attack", "react", "disengage", "patrol"]:
		assert_array_contains(
			trail,
			required,
			"%s night-stub trail missing %s" % [enemy.display_name, required]
		)
	assert_false(
		EnemyCombatState.is_combat_engaged(enemy.get_machine().state),
		"%s must leave combat engagement" % enemy.display_name
	)
	_free_stub(stub)


func _mount_stub() -> NightEncounterStub:
	_ensure_content_loaded()
	var stub: NightEncounterStub = STUB_SCENE.instantiate() as NightEncounterStub
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(stub)
	# WHY: harness does not await coroutines; build synchronously for headless.
	stub.ensure_built()
	return stub


func _free_stub(stub: NightEncounterStub) -> void:
	stub.free()


func _ensure_content_loaded() -> void:
	if not SessionState.content_db.is_loaded():
		assert_true(SessionState.content_db.load_from_directories(SessionState.DEMO_CONTENT_DIRS))
	if SessionState.state == null:
		SessionState.state = GameState.new()
	SessionState.state.bag.set_content_db(SessionState.content_db)
