extends "res://tests/godot/test_case.gd"

const DIALOGUE_ID := &"dialogue.demo.mart_street"
const FLAG_DEMO_MART_SPOKEN := &"flag.demo_mart_spoken"


func test_demo_dialogue_content_loads_from_session_dirs() -> void:
	var db := ContentDB.new()
	assert_true(db.load_from_directories(SessionState.DEMO_CONTENT_DIRS))
	var dialogue := db.get_dialogue(DIALOGUE_ID)
	assert_false(dialogue.is_empty())
	assert_eq(String(dialogue.get("start_node_id", "")), "mart_opens")
	assert_true(dialogue.get("nodes", []).size() >= 4)


func test_demo_dialogue_runner_advances_linear_nodes() -> void:
	var root := _make_root()
	var box := DemoDialogueBox.new()
	root.add_child(box)
	await box.ready

	var db := ContentDB.new()
	assert_true(db.load_from_directories(SessionState.DEMO_CONTENT_DIRS))
	var state := GameState.new()
	var runner := DemoDialogueRunner.new()
	root.add_child(runner)
	runner.configure(db, state, box)

	assert_true(runner.start(DIALOGUE_ID))
	assert_true(runner.is_active())
	assert_true(box.is_showing())
	assert_eq(box.get_speaker_name(), "Mart")

	runner.advance_for_test()
	var dialogue := db.get_dialogue(DIALOGUE_ID)
	var nodes: Array = dialogue.get("nodes", [])
	assert_eq(box.get_line_text(), String(nodes[1].get("text", "")))

	runner.advance_for_test()
	runner.advance_for_test()
	runner.advance_for_test()
	assert_false(runner.is_active())
	assert_false(box.is_showing())
	_cleanup_node(root)


func test_demo_dialogue_sets_flag_on_completion() -> void:
	var root := _make_root()
	var box := DemoDialogueBox.new()
	root.add_child(box)
	await box.ready

	var db := ContentDB.new()
	assert_true(db.load_from_directories(SessionState.DEMO_CONTENT_DIRS))
	var state := GameState.new()
	var runner := DemoDialogueRunner.new()
	root.add_child(runner)
	runner.configure(db, state, box)

	assert_true(runner.start(DIALOGUE_ID))
	while runner.is_active():
		runner.advance_for_test()

	assert_true(state.get_flag(FLAG_DEMO_MART_SPOKEN))
	_cleanup_node(root)


func test_keyboard_and_gamepad_advance_demo_dialogue() -> void:
	var root := _make_root()
	var box := DemoDialogueBox.new()
	root.add_child(box)
	await box.ready

	var db := ContentDB.new()
	assert_true(db.load_from_directories(SessionState.DEMO_CONTENT_DIRS))
	var runner := DemoDialogueRunner.new()
	root.add_child(runner)
	runner.configure(db, GameState.new(), box)
	assert_true(runner.start(DIALOGUE_ID))

	var keyboard := InputEventAction.new()
	keyboard.action = "interact"
	keyboard.pressed = true
	assert_true(runner.try_advance(keyboard))

	var gamepad := InputEventJoypadButton.new()
	gamepad.device = 0
	gamepad.button_index = JOY_BUTTON_A
	gamepad.pressed = true
	assert_true(runner.try_advance(gamepad))
	_cleanup_node(root)


func test_mart_encounter_spawns_at_mart_street_anchor() -> void:
	var root := _make_root()
	var actors := Node2D.new()
	actors.name = "Actors"
	root.add_child(actors)

	var definition: MapDefinition = preload(
		"res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd"
	).create()
	var encounter := DemoMartEncounter.new()
	root.add_child(encounter)
	var mart := encounter.spawn_mart(actors, definition)
	var expected := MapVerification.anchor_position(definition, &"mart_street")
	assert_eq(mart.global_position, expected)
	_cleanup_node(root)


func _make_root() -> Node:
	var root := Node.new()
	_tree().root.add_child(root)
	return root


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _cleanup_node(node: Node) -> void:
	if is_instance_valid(node):
		node.free()
