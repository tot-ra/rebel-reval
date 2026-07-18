extends "res://tests/godot/test_case.gd"

const INTERACTABLE_SCENE := preload("res://scenes/interaction/interactable.tscn")
const TEST_SCENE := preload("res://scenes/interaction/interaction_test.tscn")

const ID_TALK := &"interact.test_talk"
const ID_PICKUP := &"interact.test_pickup"
const ID_USE := &"interact.test_use"


func test_interactable_exposes_stable_id_prompt_and_kind() -> void:
	var root := _make_root()
	var interactable := _spawn_interactable(root, ID_TALK, InteractionKinds.TALK, "Talk")
	assert_eq(interactable.get_interactable_id(), ID_TALK)
	assert_eq(interactable.get_prompt(), "Talk")
	assert_eq(interactable.get_interaction_kind(), InteractionKinds.TALK)
	var body := interactable.get_node("Body") as CanvasItem
	assert_false(body.visible, "gameplay interactables must not show the 2D placeholder body")
	_cleanup_node(root)


func test_focus_highlight_toggles_with_focus_state() -> void:
	var root := _make_root()
	var interactable := _spawn_interactable(root, ID_USE, InteractionKinds.USE, "Inspect")
	var highlight := interactable.get_node("FocusHighlight") as CanvasItem

	assert_false(highlight.visible)
	interactable.set_focused(true)
	assert_true(interactable.is_focused())
	assert_true(highlight.visible)
	interactable.set_focused(false)
	assert_false(interactable.is_focused())
	assert_false(highlight.visible)
	_cleanup_node(root)


func test_callback_runs_when_actor_is_in_range() -> void:
	var root := _make_root()
	var interactable := _spawn_interactable(root, ID_PICKUP, InteractionKinds.PICKUP, "Pick up")
	var actor := _spawn_actor(root, Vector2(100, 100))
	interactable.global_position = Vector2(140, 100)

	var state := {"activated": false}
	interactable.set_interact_callback(func(_body: Node) -> void:
		state["activated"] = true
	)

	interactable.register_actor_in_range(actor)
	assert_true(interactable.is_actor_in_range(actor), "actor should be in range")
	assert_true(interactable.interact(actor), "interact should succeed")
	assert_true(state["activated"], "callback should run")
	_cleanup_node(root)


func test_controller_focuses_closest_interactable() -> void:
	var root := _make_root()
	var actor := _spawn_actor(root, Vector2(200, 200))
	var near := _spawn_interactable(root, ID_TALK, InteractionKinds.TALK, "Talk", Vector2(260, 200))
	var far := _spawn_interactable(root, ID_USE, InteractionKinds.USE, "Use", Vector2(420, 200))

	var controller := InteractionController.new()
	controller.actor = actor
	root.add_child(controller)

	near.register_actor_in_range(actor)
	far.register_actor_in_range(actor)
	controller._update_focus()

	assert_eq(controller.get_focused_interactable(), near)
	assert_true(near.is_focused())
	assert_false(far.is_focused())
	_cleanup_node(root)


func test_keyboard_interact_action_activates_three_kinds() -> void:
	var activated := _activate_kinds_with_keyboard()
	assert_array_contains(activated, InteractionKinds.TALK)
	assert_array_contains(activated, InteractionKinds.PICKUP)
	assert_array_contains(activated, InteractionKinds.USE)


func test_gamepad_accept_activates_three_kinds() -> void:
	var activated := _activate_kinds_with_gamepad()
	assert_array_contains(activated, InteractionKinds.TALK)
	assert_array_contains(activated, InteractionKinds.PICKUP)
	assert_array_contains(activated, InteractionKinds.USE)


func test_interact_action_ignored_while_demo_dialogue_is_active() -> void:
	var root := _make_root()
	var actor := _spawn_actor(root, Vector2(100, 100))
	var interactable := _spawn_interactable(root, ID_TALK, InteractionKinds.TALK, "Talk", Vector2(100, 100))
	var activated := false
	interactable.set_interact_callback(func(_body: Node) -> void:
		activated = true
	)
	interactable.register_actor_in_range(actor)

	var controller := InteractionController.new()
	controller.actor = actor
	root.add_child(controller)
	controller._update_focus()

	var marker := Node.new()
	marker.add_to_group(&"demo_dialogue_active")
	root.add_child(marker)

	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	controller._unhandled_input(event)
	assert_false(activated, "Focused interactable must not fire while dialogue is active")
	_cleanup_node(root)


func test_interaction_test_scene_exposes_three_kinds() -> void:
	var scene: Node2D = TEST_SCENE.instantiate()
	_tree().root.add_child(scene)

	var talk := scene.get_node("interact_test_talk") as Interactable
	var pickup := scene.get_node("interact_test_pickup") as Interactable
	var use := scene.get_node("interact_test_use") as Interactable

	assert_eq(talk.get_interaction_kind(), InteractionKinds.TALK)
	assert_eq(pickup.get_interaction_kind(), InteractionKinds.PICKUP)
	assert_eq(use.get_interaction_kind(), InteractionKinds.USE)
	assert_false(String(talk.get_prompt()).is_empty())
	assert_false(String(pickup.get_prompt()).is_empty())
	assert_false(String(use.get_prompt()).is_empty())

	scene.free()


func _activate_kinds_with_keyboard() -> Array[StringName]:
	return _activate_kinds(func(controller: InteractionController) -> void:
		var event := InputEventAction.new()
		event.action = "interact"
		event.pressed = true
		controller._unhandled_input(event)
	)


func _activate_kinds_with_gamepad() -> Array[StringName]:
	return _activate_kinds(func(controller: InteractionController) -> void:
		var event := InputEventJoypadButton.new()
		event.device = 0
		event.button_index = JOY_BUTTON_A
		event.pressed = true
		controller._unhandled_input(event)
	)


func _activate_kinds(send_input: Callable) -> Array[StringName]:
	var root := _make_root()
	var actor := _spawn_actor(root, Vector2(300, 300))
	var controller := InteractionController.new()
	controller.actor = actor
	root.add_child(controller)

	var kinds := [
		{"id": ID_TALK, "kind": InteractionKinds.TALK, "prompt": "Talk", "position": Vector2(300, 220)},
		{"id": ID_PICKUP, "kind": InteractionKinds.PICKUP, "prompt": "Pick up", "position": Vector2(220, 300)},
		{"id": ID_USE, "kind": InteractionKinds.USE, "prompt": "Use", "position": Vector2(380, 300)},
	]

	var activated: Array[StringName] = []
	for entry in kinds:
		var interactable := _spawn_interactable(
			root,
			entry["id"],
			entry["kind"],
			entry["prompt"],
			entry["position"]
		)
		interactable.set_interact_callback(func(_body: Node) -> void:
			if not activated.has(entry["kind"]):
				activated.append(entry["kind"])
		)

		actor.global_position = interactable.global_position
		interactable.register_actor_in_range(actor)
		controller._update_focus()
		assert_eq(controller.get_focused_interactable(), interactable)
		send_input.call(controller)
		assert_true(activated.has(entry["kind"]), "Expected activation for %s" % String(entry["kind"]))

	_cleanup_node(root)
	return activated


func _make_root() -> Node2D:
	var root := Node2D.new()
	_tree().root.add_child(root)
	return root


func _spawn_interactable(
	parent: Node,
	interactable_id: StringName,
	kind: StringName,
	prompt: String,
	position: Vector2 = Vector2.ZERO
) -> Interactable:
	var interactable: Interactable = INTERACTABLE_SCENE.instantiate()
	interactable.interactable_id = interactable_id
	interactable.interaction_kind = kind
	interactable.prompt = prompt
	interactable.position = position
	parent.add_child(interactable)
	return interactable


func _spawn_actor(parent: Node, position: Vector2) -> CharacterBody2D:
	var actor := CharacterBody2D.new()
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 12.0
	capsule.height = 24.0
	shape.shape = capsule
	actor.add_child(shape)
	actor.position = position
	parent.add_child(actor)
	return actor


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _cleanup_node(node: Node) -> void:
	if is_instance_valid(node):
		node.free()
