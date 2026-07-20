extends "res://tests/godot/test_case.gd"

const INTERACTABLE_SCENE := preload("res://scenes/interaction/interactable.tscn")
const PLAYER_SCENE := preload("res://player.tscn")
const CLICK_INPUT_SCRIPT := preload("res://scripts/map/map_click_input_controller.gd")


func before_each() -> void:
	_failures.clear()
	_purge_leaked_map_scenes()


func test_find_at_logic_position_returns_closest_enabled_interactable() -> void:
	var root := _make_root()
	var near := _spawn_interactable(root, Vector2(200, 200), 80.0)
	var far := _spawn_interactable(root, Vector2(400, 200), 80.0)
	var found := Interactable.find_at_logic_position(Vector2(210, 205), root.get_tree())
	assert_eq(found, near)
	assert_ne(found, far)
	_cleanup_node(root)


func test_find_at_logic_position_selects_talk_interactable_near_actor_click() -> void:
	var root := _make_root()
	var actor := CharacterBody2D.new()
	actor.add_to_group(&"map_view_actor")
	root.add_child(actor)
	actor.global_position = Vector2(300, 300)

	var talk: Interactable = INTERACTABLE_SCENE.instantiate()
	talk.interaction_radius = 48.0
	talk.interaction_kind = InteractionKinds.TALK
	actor.add_child(talk)

	# Click offset from the sensor center but still on the actor footprint.
	var found := Interactable.find_at_logic_position(Vector2(350, 300), root.get_tree())
	assert_eq(found, talk)
	_cleanup_node(root)


func test_logic_click_sets_navigation_target_on_open_ground() -> void:
	var harness := _make_click_harness()
	assert_true(harness.click_input.try_handle_logic_click(Vector2(640, 360)))
	assert_eq(harness.player.navigation_agent.target_position, Vector2(640, 360))
	_cleanup_harness(harness)


func test_logic_click_on_out_of_range_interactable_targets_navigation() -> void:
	var harness := _make_click_harness()
	var activated := false
	var interactable := _spawn_interactable(harness.root, Vector2(700, 420), 96.0)
	interactable.set_interact_callback(func(_actor: Node) -> void:
		activated = true
	)
	assert_true(harness.click_input.try_handle_logic_click(interactable.global_position))
	assert_false(activated, "out-of-range clicks must walk first")
	assert_eq(harness.player.navigation_agent.target_position, interactable.global_position)
	_cleanup_harness(harness)


func test_logic_click_ignored_while_movement_blocked() -> void:
	var harness := _make_click_harness()
	var marker := Node.new()
	marker.add_to_group(&"demo_dialogue_active")
	harness.root.add_child(marker)
	assert_false(harness.click_input.try_handle_logic_click(Vector2(640, 360)))
	_cleanup_harness(harness)


func test_input_routes_left_click_before_passive_hud_can_consume_it() -> void:
	var harness := _make_click_harness()
	var target := Vector2(640, 360)
	_tree().root.push_input(_left_click(target), true)
	assert_eq(harness.player.navigation_agent.target_position, target)
	_cleanup_harness(harness)


func test_input_prioritizes_world_item_pickup_before_navigation() -> void:
	var harness := _make_click_harness()
	var world_items := _StubWorldItems.new()
	harness.root.add_child(world_items)
	harness.click_input.set_world_items(world_items)
	var initial_target := Vector2(320, 240)
	harness.player.navigation_agent.target_position = initial_target
	harness.click_input._input(_left_click(Vector2(640, 360)))
	assert_eq(world_items.handled_clicks, 1)
	assert_eq(harness.player.navigation_agent.target_position, initial_target)
	_cleanup_harness(harness)


func test_input_click_on_in_range_npc_interacts_without_navigation() -> void:
	var harness := _make_click_harness()
	var activated := [false]
	var interactable := _spawn_interactable(harness.root, Vector2(340, 240), 80.0)
	interactable.register_actor_in_range(harness.player)
	interactable.set_interact_callback(func(_actor: Node) -> void:
		activated[0] = true
	)
	var initial_target := Vector2(320, 240)
	harness.player.navigation_agent.target_position = initial_target
	_tree().root.push_input(_left_click(interactable.global_position), true)
	assert_true(activated[0])
	assert_eq(harness.player.navigation_agent.target_position, initial_target)
	_cleanup_harness(harness)


func test_input_leaves_left_click_for_interactive_ui_control() -> void:
	var harness := _make_click_harness()
	var initial_target := Vector2(320, 240)
	harness.player.navigation_agent.target_position = initial_target
	var button := Button.new()
	assert_true(harness.click_input._control_claims_click(button))
	assert_eq(harness.player.navigation_agent.target_position, initial_target)
	button.free()
	_cleanup_harness(harness)


func test_passive_hud_control_does_not_claim_gameplay_click() -> void:
	var label := Label.new()
	assert_false(MapClickInputController._control_claims_click(label))
	label.free()


func _left_click(position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = position
	return event


func _make_click_harness() -> Dictionary:
	var root := _make_root()
	var player: Player = PLAYER_SCENE.instantiate()
	player.global_position = Vector2(320, 240)
	root.add_child(player)
	var runtime := _StubViewRuntime.new()
	runtime.name = "StubViewRuntime"
	root.add_child(runtime)
	var click_input: MapClickInputController = CLICK_INPUT_SCRIPT.new()
	click_input.name = "MapClickInput"
	root.add_child(click_input)
	click_input.setup(player, runtime)
	return {
		"root": root,
		"player": player,
		"runtime": runtime,
		"click_input": click_input,
	}


class _StubViewRuntime:
	extends MapViewRuntime

	func logic_position_at_screen(screen_position: Vector2) -> Vector2:
		return screen_position

	func is_camera_drag_active() -> bool:
		return false


class _StubWorldItems:
	extends WorldItemController

	var handled_clicks := 0

	func try_handle_click(_event: InputEvent) -> bool:
		handled_clicks += 1
		return true


func _cleanup_harness(harness: Dictionary) -> void:
	_cleanup_node(harness["root"])


func _spawn_interactable(root: Node2D, position: Vector2, radius: float) -> Interactable:
	var interactable: Interactable = INTERACTABLE_SCENE.instantiate()
	interactable.interaction_radius = radius
	interactable.interaction_kind = InteractionKinds.TALK
	root.add_child(interactable)
	interactable.global_position = position
	return interactable


func _make_root() -> Node2D:
	var root := Node2D.new()
	_tree().root.add_child(root)
	return root


func _cleanup_node(node: Node) -> void:
	if is_instance_valid(node):
		node.free()


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _purge_leaked_map_scenes() -> void:
	var tree := _tree()
	if tree == null:
		return
	for child in tree.root.get_children():
		if child is Node2D and child.get_node_or_null("Actors/Player") != null:
			# Strip MultiMesh materials before free to avoid DEF-006 headless ERROR spam.
			MapView3D._strip_geometry_materials(child)
			child.free()
