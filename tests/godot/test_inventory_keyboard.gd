extends "res://tests/godot/test_case.gd"

const ITEM_SPEARHEAD := &"item.seized_spearhead"


func test_keyboard_moves_selection_and_places_item() -> void:
	var overlay := InventoryOverlay.new()
	var bag := InventoryBag.new()
	var db := ContentDB.new()
	db.load_from_directories(["res://content/examples/valid"])
	bag.set_content_db(db)
	bag.try_add(ITEM_SPEARHEAD)

	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(overlay)
	overlay.configure(bag, db)
	overlay.open()

	_send_key(overlay, KEY_ENTER)
	_send_key(overlay, KEY_D)
	_send_key(overlay, KEY_D)
	_send_key(overlay, KEY_ENTER)

	assert_eq(
		bag.get_placement_at_cell(2, 0).item_id,
		ITEM_SPEARHEAD,
		"keyboard navigation must select and move an item"
	)
	overlay.queue_free()


func test_wasd_moves_focus_for_placement() -> void:
	var overlay := InventoryOverlay.new()
	var bag := InventoryBag.new()
	var db := ContentDB.new()
	db.load_from_directories(["res://content/examples/valid"])
	bag.set_content_db(db)
	bag.try_add(ITEM_SPEARHEAD)

	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(overlay)
	overlay.configure(bag, db)
	overlay.open()

	_send_key(overlay, KEY_ENTER)
	_send_key(overlay, KEY_D)
	_send_key(overlay, KEY_D)
	_send_key(overlay, KEY_S)
	_send_key(overlay, KEY_ENTER)

	assert_eq(
		bag.get_placement_at_cell(2, 1).item_id,
		ITEM_SPEARHEAD,
		"WASD must move the keyboard selection like arrow keys"
	)
	overlay.queue_free()


func _send_key(overlay: InventoryOverlay, keycode: Key) -> void:
	var key_event := InputEventKey.new()
	key_event.keycode = keycode
	key_event.pressed = true
	overlay._unhandled_input(key_event)
