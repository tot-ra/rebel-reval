extends "res://tests/godot/test_case.gd"

const WORLD_ITEM_SCENE := preload("res://scenes/world/world_item.tscn")
const FORGE_SCENE := preload("res://scenes/reval_east/forge/forge.tscn")

const LOC_SMITHY := &"loc.kalev_smithy"
const OBJ_SPEAR := &"world.spearhead_anvil"
const ITEM_SPEARHEAD := &"item.seized_spearhead"
const ITEM_HAMMER := &"item.forge_hammer"


func test_place_and_take_world_item_round_trip() -> void:
	var state := _state_with_content()
	assert_true(state.place_world_item(LOC_SMITHY, OBJ_SPEAR, ITEM_SPEARHEAD, Vector2(600, 200)))
	assert_true(state.is_world_item_placed(LOC_SMITHY, OBJ_SPEAR))
	assert_eq(state.get_world_items(LOC_SMITHY).size(), 1)
	var taken := state.take_world_item(LOC_SMITHY, OBJ_SPEAR)
	assert_eq(taken.get("item_id"), ITEM_SPEARHEAD)
	assert_false(state.is_world_item_placed(LOC_SMITHY, OBJ_SPEAR))


func test_check_add_reports_capacity_without_mutating_bag() -> void:
	var state := _state_with_content()
	var bag := state.bag
	var placement_count := bag.placements.size()
	bag.reserved_weight_kg = InventoryBag.MAX_WEIGHT_KG
	assert_eq(bag.check_add(ITEM_HAMMER), InventoryBag.AddResult.OVER_WEIGHT)
	assert_eq(bag.check_add(ITEM_SPEARHEAD), InventoryBag.AddResult.OVER_WEIGHT)
	assert_eq(bag.placements.size(), placement_count)


func test_world_item_contains_logic_point() -> void:
	var root := _make_root()
	var item: WorldItem = WORLD_ITEM_SCENE.instantiate()
	item.configure(OBJ_SPEAR, ITEM_SPEARHEAD, LOC_SMITHY, Vector2(400, 300))
	root.add_child(item)
	assert_true(item.contains_logic_point(Vector2(410, 305)))
	assert_false(item.contains_logic_point(Vector2(500, 500)))
	_cleanup_node(root)


func test_world_item_shows_idle_outline_and_brightens_on_hover() -> void:
	var root := _make_root()
	var item: WorldItem = WORLD_ITEM_SCENE.instantiate()
	item.configure(OBJ_SPEAR, ITEM_SPEARHEAD, LOC_SMITHY, Vector2(400, 300))
	root.add_child(item)
	var outline := item.get_node("FocusOutline") as Line2D
	assert_true(outline.visible, "pickable items should always show an outline")
	assert_eq(outline.width, 1.0)
	item.set_hovered(true)
	assert_true(outline.visible)
	assert_eq(outline.width, 2.0)
	_cleanup_node(root)


func test_3d_presentation_keeps_outline_hidden_on_hover() -> void:
	var root := _make_root()
	var item: WorldItem = WORLD_ITEM_SCENE.instantiate()
	item.configure(OBJ_SPEAR, ITEM_SPEARHEAD, LOC_SMITHY, Vector2(400, 300))
	root.add_child(item)
	item.set_3d_presentation(true)
	var outline := item.get_node("FocusOutline") as CanvasItem
	assert_false(outline.visible, "3D view should hide the flat pickup outline")
	item.set_hovered(true)
	assert_false(outline.visible, "hover must not reshow the flat harness outline in 3D")
	_cleanup_node(root)


func test_forge_hides_flat_pickup_markers_in_3d_view() -> void:
	_prepare_smithy_pickup_state()
	var tree := Engine.get_main_loop() as SceneTree
	var forge: Node2D = FORGE_SCENE.instantiate()
	tree.root.add_child(forge)

	var world_item := _find_world_item(forge)
	var interactable := _find_pickup_interactable(forge)
	assert_true(world_item != null, "forge should spawn the anvil spearhead")
	assert_true(interactable != null, "forge should expose a pickup interactable")

	var outline := world_item.get_node("FocusOutline") as CanvasItem
	var highlight := interactable.get_node("FocusHighlight") as CanvasItem
	assert_false(outline.visible, "3D view should hide the flat pickup outline")
	assert_false(highlight.visible, "3D view should hide the flat focus rectangle")

	var player := forge.get_node("Actors/Player") as Player
	player.global_position = interactable.global_position
	interactable.register_actor_in_range(player)
	var controller := forge.get_node("InteractionController") as InteractionController
	controller._update_focus()
	assert_true(interactable.is_focused())
	assert_false(highlight.visible, "focused pickup must keep the flat rectangle hidden in 3D")

	forge.free()


func test_pickup_moves_item_into_bag_and_state() -> void:
	var state := _state_with_content()
	state.place_world_item(LOC_SMITHY, OBJ_SPEAR, ITEM_SPEARHEAD, Vector2(300, 300))

	assert_eq(state.bag.check_add(ITEM_SPEARHEAD), InventoryBag.AddResult.OK)
	assert_true(state.bag.try_add(ITEM_SPEARHEAD) == InventoryBag.AddResult.OK)
	state.add_item(ITEM_SPEARHEAD)
	state.take_world_item(LOC_SMITHY, OBJ_SPEAR)

	assert_false(state.is_world_item_placed(LOC_SMITHY, OBJ_SPEAR))
	assert_true(state.has_item(ITEM_SPEARHEAD))
	assert_eq(state.bag.find_placement(ITEM_SPEARHEAD).item_id, ITEM_SPEARHEAD)


func test_overweight_pickup_stays_in_world() -> void:
	var state := _state_with_content()
	state.place_world_item(LOC_SMITHY, OBJ_SPEAR, ITEM_SPEARHEAD, Vector2(100, 100))
	state.bag.reserved_weight_kg = InventoryBag.MAX_WEIGHT_KG - 0.1
	assert_eq(state.bag.check_add(ITEM_SPEARHEAD), InventoryBag.AddResult.OVER_WEIGHT)
	assert_true(state.is_world_item_placed(LOC_SMITHY, OBJ_SPEAR))


func test_drop_removes_from_bag_and_records_world_item() -> void:
	var state := _state_with_content()
	assert_true(state.bag.try_add(ITEM_SPEARHEAD) == InventoryBag.AddResult.OK)
	var placement := state.bag.find_placement(ITEM_SPEARHEAD)
	assert_true(state.bag.remove(placement))
	assert_true(state.place_world_item(LOC_SMITHY, &"world.dropped.item.seized_spearhead.0", ITEM_SPEARHEAD, Vector2(220, 180)))
	assert_true(state.is_world_item_placed(LOC_SMITHY, &"world.dropped.item.seized_spearhead.0"))
	assert_true(state.bag.find_placement(ITEM_SPEARHEAD) == null)


func test_world_defaults_seeded_prevents_replacement_after_pickup() -> void:
	var state := _state_with_content()
	state.mark_world_defaults_seeded(LOC_SMITHY)
	state.place_world_item(LOC_SMITHY, OBJ_SPEAR, ITEM_SPEARHEAD, Vector2(300, 300))
	state.take_world_item(LOC_SMITHY, OBJ_SPEAR)
	state.add_item(ITEM_SPEARHEAD)

	assert_true(state.are_world_defaults_seeded(LOC_SMITHY))
	assert_true(state.get_world_items(LOC_SMITHY).is_empty())
	assert_false(state.is_world_item_placed(LOC_SMITHY, OBJ_SPEAR))


func test_forge_keyboard_pickup_moves_spearhead_into_bag() -> void:
	_prepare_smithy_pickup_state()
	var tree := Engine.get_main_loop() as SceneTree
	var forge: Node2D = FORGE_SCENE.instantiate()
	tree.root.add_child(forge)

	var player := forge.get_node("Actors/Player") as Player
	var controller := forge.get_node("InteractionController") as InteractionController
	var interactable := _find_pickup_interactable(forge)
	assert_true(controller != null, "forge needs InteractionController for keyboard pickup")
	assert_true(interactable != null, "forge needs a pickup interactable on the anvil item")

	player.global_position = interactable.global_position
	interactable.register_actor_in_range(player)
	controller._update_focus()

	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	if controller.get_focused_interactable() != null:
		controller._unhandled_input(event)
	else:
		# Headless harness does not always advance Area2D overlap in the same frame.
		assert_true(interactable.interact(player), "pickup interact should succeed without physics overlap")

	assert_true(SessionState.state.has_item(ITEM_SPEARHEAD))
	assert_false(SessionState.state.is_world_item_placed(LOC_SMITHY, OBJ_SPEAR))
	assert_true(SessionState.state.bag.find_placement(ITEM_SPEARHEAD) != null)
	forge.free()


func test_forge_gamepad_pickup_moves_spearhead_into_bag() -> void:
	_prepare_smithy_pickup_state()
	var tree := Engine.get_main_loop() as SceneTree
	var forge: Node2D = FORGE_SCENE.instantiate()
	tree.root.add_child(forge)

	var player := forge.get_node("Actors/Player") as Player
	var controller := forge.get_node("InteractionController") as InteractionController
	var interactable := _find_pickup_interactable(forge)
	assert_true(interactable != null)

	player.global_position = interactable.global_position
	interactable.register_actor_in_range(player)
	controller._update_focus()

	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = JOY_BUTTON_A
	event.pressed = true
	if controller.get_focused_interactable() != null:
		controller._unhandled_input(event)
	else:
		assert_true(interactable.interact(player), "pickup interact should succeed without physics overlap")

	assert_true(SessionState.state.has_item(ITEM_SPEARHEAD))
	assert_false(SessionState.state.is_world_item_placed(LOC_SMITHY, OBJ_SPEAR))
	forge.free()


func test_forge_reload_does_not_respawn_picked_spearhead() -> void:
	_prepare_smithy_pickup_state()
	var tree := Engine.get_main_loop() as SceneTree

	var forge: Node2D = FORGE_SCENE.instantiate()
	tree.root.add_child(forge)
	_pickup_spearhead_via_interact(forge)
	forge.free()

	forge = FORGE_SCENE.instantiate()
	tree.root.add_child(forge)
	assert_true(SessionState.state.has_item(ITEM_SPEARHEAD))
	assert_eq(_find_pickup_interactable(forge), null, "picked spearhead must stay gone after smithy re-entry")
	forge.free()


func test_debug_post_pickup_preset_removes_anvil_spearhead_without_reload() -> void:
	_prepare_smithy_pickup_state()
	var tree := Engine.get_main_loop() as SceneTree
	var forge: Node2D = FORGE_SCENE.instantiate()
	tree.root.add_child(forge)

	assert_true(_find_pickup_interactable(forge) != null, "fresh forge should expose the anvil spearhead")
	assert_true(SessionState.apply_debug_preset("debug.reset.demo_post_pickup"))
	assert_true(SessionState.state.has_item(ITEM_SPEARHEAD))
	assert_false(SessionState.state.is_world_item_placed(LOC_SMITHY, OBJ_SPEAR))
	assert_eq(_find_pickup_interactable(forge), null, "debug jump must remove the anvil spearhead without reload")
	forge.free()


func test_overweight_interact_pickup_leaves_world_item_unchanged() -> void:
	_prepare_smithy_pickup_state()
	var tree := Engine.get_main_loop() as SceneTree
	var forge: Node2D = FORGE_SCENE.instantiate()
	tree.root.add_child(forge)

	SessionState.state.bag.reserved_weight_kg = InventoryBag.MAX_WEIGHT_KG - 0.1
	assert_eq(SessionState.state.bag.check_add(ITEM_SPEARHEAD), InventoryBag.AddResult.OVER_WEIGHT)
	assert_true(SessionState.state.is_world_item_placed(LOC_SMITHY, OBJ_SPEAR))

	_pickup_spearhead_via_interact(forge)

	assert_false(SessionState.state.has_item(ITEM_SPEARHEAD))
	assert_true(SessionState.state.is_world_item_placed(LOC_SMITHY, OBJ_SPEAR))
	forge.free()


func test_pickup_hover_activates_grab_cursor_state() -> void:
	var root := _make_root()
	var controller := WorldItemController.new()
	root.add_child(controller)

	var item: WorldItem = WORLD_ITEM_SCENE.instantiate()
	item.configure(OBJ_SPEAR, ITEM_SPEARHEAD, LOC_SMITHY, Vector2(400, 300))
	root.add_child(item)

	# Cursor feedback lives on WorldItemOverlay after the controller/overlay split.
	controller._overlay = preload("res://scripts/world/world_item_overlay.gd").new()
	controller.add_child(controller._overlay)
	controller._hovered = item
	controller._overlay.update_cursor(true)
	assert_true(controller.is_pickup_hover_active())

	controller._hovered = null
	controller._overlay.update_cursor(false)
	assert_false(controller.is_pickup_hover_active())
	_cleanup_node(root)


func test_pickup_feedback_resolves_spearhead_comment() -> void:
	var root := _make_root()
	var db := ContentDB.new()
	db.load_from_directories([
		"res://content/demo",
		"res://content/examples/support",
		"res://content/examples/valid",
	])
	var state := GameState.new()
	state.bag.set_content_db(db)
	var item_record := db.get_item(ITEM_SPEARHEAD)

	var resolved := WorldItemPickupFeedback.resolve_feedback(
		ITEM_SPEARHEAD,
		item_record,
		db,
		state,
		LOC_SMITHY,
		null
	)
	var feedback: Dictionary = resolved.get("feedback", {})
	assert_eq(feedback.get("speaker_name"), "Kalev")
	assert_true(String(feedback.get("text", "")).contains("mark"))
	_cleanup_node(root)


func _state_with_content() -> GameState:
	var state := GameState.new()
	var db := ContentDB.new()
	db.load_from_directories([
		"res://content/demo",
		"res://content/examples/support",
		"res://content/examples/valid",
	])
	state.bag.set_content_db(db)
	return state


func _prepare_smithy_pickup_state() -> void:
	SessionState.state = GameState.new()
	SessionState.content_db.load_from_directories(SessionState.DEMO_CONTENT_DIRS)
	SessionState.state.bag.set_content_db(SessionState.content_db)
	SessionState.state.bag.try_add(ITEM_HAMMER)
	SessionState.state.equip_from_bag(&"right_hand", ITEM_HAMMER)


func _find_pickup_interactable(forge: Node) -> Interactable:
	for node in forge.find_children("*", "Area2D", true, false):
		var interactable := node as Interactable
		if interactable != null and interactable.get_interaction_kind() == InteractionKinds.PICKUP:
			return interactable
	return null


func _find_world_item(forge: Node) -> WorldItem:
	for node in forge.find_children("*", "Area2D", true, false):
		var item := node as WorldItem
		if item != null and item.get_world_object_id() == OBJ_SPEAR:
			return item
	return null


func _pickup_spearhead_via_interact(forge: Node2D) -> void:
	var player := forge.get_node("Actors/Player") as Player
	var interactable := _find_pickup_interactable(forge)
	player.global_position = interactable.global_position
	interactable.register_actor_in_range(player)
	assert_true(interactable.interact(player), "pickup interact should succeed")


func _make_root() -> Node2D:
	var root := Node2D.new()
	(_tree().root as Window).add_child(root)
	return root


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _cleanup_node(node: Node) -> void:
	if is_instance_valid(node):
		node.free()
