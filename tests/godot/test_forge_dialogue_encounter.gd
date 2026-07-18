extends "res://tests/godot/test_case.gd"

const FORGE_SCENE := preload("res://scenes/reval_east/forge/forge.tscn")
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


func test_forge_cat_stops_and_faces_player_during_dialogue() -> void:
	var cat := ForgeCat.new()
	var player := CharacterBody2D.new()
	cat.global_position = Vector2(200, 200)
	player.global_position = Vector2(260, 200)
	cat._set_state(ForgeCat.RoutineState.WALKING, 0.0)
	cat.velocity = Vector2(ForgeCat.WALK_SPEED, 0.0)

	cat.set_conversation_partner(player)
	cat._physics_process(0.1)

	assert_true(cat.velocity.is_zero_approx(), "Cat must stop moving during conversation")
	assert_true(cat.view_facing().dot(Vector2.RIGHT) > 0.9, "Cat must face the player")
	assert_eq(cat.view_animation(), &"idle")

	cat.set_conversation_partner(null)
	cat.free()
	player.free()


func test_dialogue_runner_pauses_host_npc_during_forge_talk() -> void:
	var root := _make_root()
	var box := DemoDialogueBox.new()
	root.add_child(box)
	await box.ready

	var db := ContentDB.new()
	assert_true(db.load_from_directories(SessionState.DEMO_CONTENT_DIRS))

	var cat := ForgeCat.new()
	cat.name = "Cat"
	root.add_child(cat)
	cat.global_position = Vector2(200, 200)

	var actor := CharacterBody2D.new()
	actor.global_position = Vector2(260, 200)
	root.add_child(actor)

	var controller := InteractionController.new()
	controller.actor = actor
	root.add_child(controller)

	var runner := DemoDialogueRunner.new()
	root.add_child(runner)
	runner.configure(db, GameState.new(), box, controller)

	cat._set_state(ForgeCat.RoutineState.WALKING, 0.0)
	cat.velocity = Vector2(ForgeCat.WALK_SPEED, 0.0)

	assert_true(runner.start(CAT_DIALOGUE_ID, cat))
	cat._physics_process(0.1)
	assert_true(cat.velocity.is_zero_approx(), "Dialogue runner must pause the conversation host")

	while runner.is_active():
		runner.advance_for_test()
	assert_false(runner.is_active())
	_cleanup_node(root)


func test_forge_scene_starts_henning_dialogue_from_keyboard() -> void:
	_prepare_forge_dialogue_state()
	var tree := Engine.get_main_loop() as SceneTree
	var forge: Node2D = FORGE_SCENE.instantiate()
	tree.root.add_child(forge)

	var encounter := forge.get_node("ForgeDialogueEncounter") as ForgeDialogueEncounter
	var player := forge.get_node("Actors/Player") as Player
	var henning := forge.get_node("Actors/Henning") as SmithyHenning
	var controller := forge.get_node("InteractionController") as InteractionController
	var henning_talk := encounter.get_henning_interactable()

	assert_true(henning_talk != null, "forge must expose Henning's talk interactable")
	assert_true(controller != null, "forge must wire InteractionController before dialogue")

	player.global_position = henning.global_position
	await tree.physics_frame
	await tree.physics_frame

	controller._update_focus()
	assert_eq(
		controller.get_focused_interactable(),
		henning_talk,
		"player standing on Henning must focus his talk prompt"
	)
	assert_true(controller.try_interact(), "E interact must start Henning's dialogue")
	assert_true(encounter.get_dialogue_runner().is_active())
	forge.queue_free()


func test_forge_scene_starts_cat_dialogue_from_click() -> void:
	_prepare_forge_dialogue_state()
	var tree := Engine.get_main_loop() as SceneTree
	var forge: Node2D = FORGE_SCENE.instantiate()
	tree.root.add_child(forge)

	var encounter := forge.get_node("ForgeDialogueEncounter") as ForgeDialogueEncounter
	var player := forge.get_node("Actors/Player") as Player
	var cat := forge.get_node("Actors/Cat") as ForgeCat
	var runtime := forge.get_node("MapViewRuntime") as MapViewRuntime
	var click_input := runtime.get_node("MapClickInput") as MapClickInputController

	assert_true(encounter.get_cat_interactable() != null)
	player.global_position = cat.global_position
	await tree.physics_frame
	await tree.physics_frame

	assert_true(click_input.try_handle_logic_click(cat.global_position))
	assert_true(encounter.get_dialogue_runner().is_active())
	forge.queue_free()


func test_keyboard_advance_works_while_cat_interactable_is_focused() -> void:
	var root := _make_root()
	var box := DemoDialogueBox.new()
	root.add_child(box)
	await box.ready

	var db := ContentDB.new()
	assert_true(db.load_from_directories(SessionState.DEMO_CONTENT_DIRS))

	var actor := CharacterBody2D.new()
	root.add_child(actor)

	var cat_talk := _spawn_interactable(root)
	cat_talk.global_position = Vector2(100, 100)
	actor.global_position = Vector2(100, 100)
	cat_talk.register_actor_in_range(actor)

	var controller := InteractionController.new()
	controller.actor = actor
	root.add_child(controller)
	controller._update_focus()
	assert_eq(controller.get_focused_interactable(), cat_talk)

	var runner := DemoDialogueRunner.new()
	root.add_child(runner)
	runner.configure(db, GameState.new(), box, controller)
	assert_true(runner.start(CAT_DIALOGUE_ID))

	var keyboard := InputEventAction.new()
	keyboard.action = "interact"
	keyboard.pressed = true
	assert_true(runner.try_advance(keyboard))
	assert_true(runner.is_active())
	_cleanup_node(root)


func _spawn_interactable(parent: Node) -> Interactable:
	var interactable: Interactable = preload("res://scenes/interaction/interactable.tscn").instantiate()
	interactable.interaction_kind = InteractionKinds.TALK
	parent.add_child(interactable)
	return interactable


func _prepare_forge_dialogue_state() -> void:
	SessionState.state = GameState.new()
	SessionState.content_db.load_from_directories(SessionState.DEMO_CONTENT_DIRS)
	SessionState.state.bag.set_content_db(SessionState.content_db)


func _make_root() -> Node:
	var root := Node.new()
	_tree().root.add_child(root)
	return root


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _cleanup_node(node: Node) -> void:
	if is_instance_valid(node):
		node.free()
