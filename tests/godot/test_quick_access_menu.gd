extends "res://tests/godot/test_case.gd"

var _save_calls := 0


func before_each() -> void:
	_save_calls = 0


func test_menu_exposes_named_player_actions() -> void:
	var menu := QuickAccessMenu.new()
	menu.configure(null, null, Callable(self, "_fake_save"))
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(menu)

	var inventory := menu.find_child("InventoryButton", true, false) as Button
	var journal := menu.find_child("JournalButton", true, false) as Button
	var camera := menu.find_child("CameraButton", true, false) as Button
	var save := menu.find_child("SaveButton", true, false) as Button
	var help := menu.find_child("HelpLabel", true, false) as Label
	var panel := menu.find_child("QuickAccessPanel", true, false) as PanelContainer

	assert_true(inventory != null, "quick access must visibly expose inventory")
	assert_true(journal != null, "quick access must visibly expose journal")
	assert_true(camera != null, "quick access must visibly expose camera toggle")
	assert_true(save != null, "quick access must visibly expose manual save")
	assert_eq(inventory.text, "Inventory [I]")
	assert_eq(journal.text, "Journal [J]")
	assert_eq(camera.text, "Camera [C]")
	assert_eq(save.text, "Save game")
	assert_true(help != null, "quick access must show keyboard shortcut help")
	assert_eq(help.text, QuickAccessMenu.HELP_TEXT)
	assert_true(panel != null)
	assert_eq(panel.anchor_top, 1.0, "unified quick access must stay at the bottom")
	menu.queue_free()


func test_save_button_calls_existing_save_behavior_and_reports_success() -> void:
	var menu := QuickAccessMenu.new()
	menu.configure(null, null, Callable(self, "_fake_save"))
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(menu)

	var save := menu.find_child("SaveButton", true, false) as Button
	save.pressed.emit()
	var status := menu.find_child("StatusLabel", true, false) as Label

	assert_eq(_save_calls, 1)
	assert_eq(status.text, QuickAccessMenu.STATUS_SAVED)
	menu.queue_free()


func test_documented_shortcuts_stay_available() -> void:
	assert_true(_action_has_physical_key(&"toggle_inventory", KEY_I), "inventory shortcut must remain I")
	assert_true(_action_has_physical_key(&"toggle_journal", KEY_J), "journal shortcut must remain J")
	assert_true(_action_has_physical_key(&"toggle_camera_view", KEY_C), "camera shortcut must remain C")


func test_inventory_and_journal_buttons_reuse_exclusive_overlays() -> void:
	var host := Node.new()
	var inventory := InventoryController.new()
	inventory.name = "InventoryController"
	host.add_child(inventory)
	var journal := JournalController.new()
	journal.name = "JournalController"
	host.add_child(journal)
	var menu := QuickAccessMenu.new()
	menu.name = "QuickAccessMenu"
	host.add_child(menu)

	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(host)

	(menu.find_child("InventoryButton", true, false) as Button).pressed.emit()
	assert_true(inventory.is_open())
	assert_false(journal.is_open())

	(menu.find_child("JournalButton", true, false) as Button).pressed.emit()
	assert_false(inventory.is_open(), "journal must close inventory before opening")
	assert_true(journal.is_open())
	host.queue_free()

func _action_has_physical_key(action: StringName, keycode: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == keycode:
			return true
	return false


func _fake_save() -> bool:
	_save_calls += 1
	return true
