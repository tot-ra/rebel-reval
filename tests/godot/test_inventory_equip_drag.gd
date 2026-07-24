extends "res://tests/godot/test_case.gd"

const ITEM_HAMMER := &"item.forge_hammer"
const ITEM_SPEARHEAD := &"item.seized_spearhead"


func test_drop_on_slot_is_not_undone_by_mouse_release() -> void:
	var overlay := InventoryOverlay.new()
	var state := GameState.new()
	var db := ContentDB.new()
	assert_true(db.load_from_directories(SessionState.DEMO_CONTENT_DIRS))
	state.bag.set_content_db(db)
	state.bag.try_add(ITEM_HAMMER)
	state.equip_from_bag(&"right_hand", ITEM_HAMMER)
	state.bag.try_add(ITEM_SPEARHEAD)

	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(overlay)
	overlay.configure(state.bag, db)
	overlay.configure_state(state)
	overlay.open()

	var placement := state.bag.find_placement(ITEM_SPEARHEAD)
	assert_true(placement != null)
	var drop_pos := _slot_center(overlay, &"left_hand")
	# Use the Control drop path so the mouse-up suppress flag is armed.
	overlay._silhouette._drop_data(drop_pos, {
		"kind": InventoryOverlay.DRAG_KIND_BAG,
		"placement": placement,
	})
	assert_eq(state.equipped_item(&"left_hand"), ITEM_SPEARHEAD)

	# Simulate the mouse-up Godot delivers to the drop target after a successful drag.
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = drop_pos
	overlay._silhouette._gui_input(release)

	assert_eq(
		state.equipped_item(&"left_hand"),
		ITEM_SPEARHEAD,
		"mouse-up after drag-equip must not stow the item again"
	)
	assert_eq(state.equipped_item(&"right_hand"), ITEM_HAMMER)
	overlay.queue_free()


func test_selected_spearhead_highlights_left_hand_and_equip_button() -> void:
	var overlay := InventoryOverlay.new()
	var state := GameState.new()
	var db := ContentDB.new()
	assert_true(db.load_from_directories(SessionState.DEMO_CONTENT_DIRS))
	state.bag.set_content_db(db)
	state.bag.try_add(ITEM_SPEARHEAD)

	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(overlay)
	overlay.configure(state.bag, db)
	overlay.configure_state(state)
	overlay.open()

	overlay._on_cell_pressed(0, 0)
	assert_true(overlay._equip_button.visible)
	assert_true(String(overlay._equip_button.text).to_lower().contains("left"))
	assert_true(&"left_hand" in overlay._silhouette._highlight_slots)

	overlay._on_equip_pressed()
	assert_eq(state.equipped_item(&"left_hand"), ITEM_SPEARHEAD)
	assert_true(state.bag.find_placement(ITEM_SPEARHEAD) == null)
	overlay.queue_free()


func test_click_claims_inventory_chrome_even_with_focus_none() -> void:
	var overlay := InventoryOverlay.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(overlay)
	overlay.open()

	var cell := Button.new()
	cell.focus_mode = Control.FOCUS_NONE
	overlay.add_child(cell)
	assert_true(
		MapClickInputController._control_claims_click(cell),
		"open satchel cells must own clicks so drag-and-drop can start"
	)
	overlay.queue_free()


func _slot_center(overlay: InventoryOverlay, slot: StringName) -> Vector2:
	var rect: Rect2 = overlay._silhouette._slot_rects[slot]
	return rect.position + rect.size * 0.5
