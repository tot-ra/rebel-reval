extends "res://tests/godot/test_case.gd"

const HENNING_DIALOGUE_ID := &"dialogue.demo.forge_henning"
const CAT_DIALOGUE_ID := &"dialogue.demo.forge_cat"
const FLAG_HENNING_SPOKEN := &"flag.demo_forge_henning_spoken"
const FLAG_CAT_SPOKEN := &"flag.demo_forge_cat_spoken"


func test_forge_dialogue_content_loads_from_session_dirs() -> void:
	var db := ContentDB.new()
	assert_true(db.load_from_directories(SessionState.DEMO_CONTENT_DIRS))

	var henning_dialogue := db.get_dialogue(HENNING_DIALOGUE_ID)
	assert_false(henning_dialogue.is_empty())
	assert_eq(String(henning_dialogue.get("start_node_id", "")), "henning_opens")

	var cat_dialogue := db.get_dialogue(CAT_DIALOGUE_ID)
	assert_false(cat_dialogue.is_empty())
	assert_eq(String(cat_dialogue.get("start_node_id", "")), "kalev_greets")

	var cat_character := db.get_character(&"char.forge_cat")
	assert_false(cat_character.is_empty())
	assert_eq(String(cat_character.get("name", "")), "Forge Cat")


func test_forge_dialogue_runner_advances_henning_lines() -> void:
	var root := _make_root()
	var box := DemoDialogueBox.new()
	root.add_child(box)
	await box.ready

	var db := ContentDB.new()
	assert_true(db.load_from_directories(SessionState.DEMO_CONTENT_DIRS))
	var runner := DemoDialogueRunner.new()
	root.add_child(runner)
	runner.configure(db, GameState.new(), box)

	assert_true(runner.start(HENNING_DIALOGUE_ID))
	assert_true(runner.is_active())
	assert_eq(box.get_speaker_name(), "Henning")

	runner.advance_for_test()
	runner.advance_for_test()
	runner.advance_for_test()
	assert_false(runner.is_active())
	_cleanup_node(root)


func test_forge_dialogue_sets_flags_on_completion() -> void:
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

	assert_true(runner.start(HENNING_DIALOGUE_ID))
	while runner.is_active():
		runner.advance_for_test()
	assert_true(state.get_flag(FLAG_HENNING_SPOKEN))

	assert_true(runner.start(CAT_DIALOGUE_ID))
	while runner.is_active():
		runner.advance_for_test()
	assert_true(state.get_flag(FLAG_CAT_SPOKEN))
	_cleanup_node(root)


func test_forge_encounter_spawns_talk_interactables_on_npc_hosts() -> void:
	var root := _make_root()
	var actors := Node2D.new()
	actors.name = "Actors"
	root.add_child(actors)

	var henning := SmithyHenning.new()
	henning.name = "Henning"
	actors.add_child(henning)
	var cat := ForgeCat.new()
	cat.name = "Cat"
	actors.add_child(cat)

	var controller := InteractionController.new()
	root.add_child(controller)
	var encounter := ForgeDialogueEncounter.new()
	root.add_child(encounter)
	encounter.wire(root, null, henning, cat, null, null, controller)

	var henning_talk := encounter.get_henning_interactable()
	var cat_talk := encounter.get_cat_interactable()
	assert_true(henning_talk.get_parent() == henning)
	assert_true(cat_talk.get_parent() == cat)
	assert_eq(henning_talk.get_interaction_kind(), InteractionKinds.TALK)
	assert_eq(cat_talk.get_interaction_kind(), InteractionKinds.TALK)
	_cleanup_node(root)


func test_interactable_world_indicator_toggles_focus_ring() -> void:
	var root := _make_root()
	var interactable := _spawn_interactable(root)
	var indicator := InteractableWorldIndicator.new()
	root.add_child(indicator)
	indicator.attach(interactable, MapTypes.DEFAULT_CELL_SIZE)

	var ring := indicator.get_node("FocusRing") as MeshInstance3D
	assert_false(ring.visible)
	interactable.set_focused(true)
	assert_true(ring.visible)
	interactable.set_focused(false)
	assert_false(ring.visible)
	_cleanup_node(root)


func _spawn_interactable(parent: Node) -> Interactable:
	var interactable: Interactable = preload("res://scenes/interaction/interactable.tscn").instantiate()
	interactable.interaction_kind = InteractionKinds.TALK
	parent.add_child(interactable)
	return interactable


func _make_root() -> Node:
	var root := Node.new()
	_tree().root.add_child(root)
	return root


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _cleanup_node(node: Node) -> void:
	if is_instance_valid(node):
		node.free()
