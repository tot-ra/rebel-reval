extends "res://tests/godot/test_case.gd"

const BindingSettings := preload("res://scripts/settings/input_binding_settings.gd")
const StoreScript := preload("res://scripts/settings/user_settings_store.gd")
const ControlsOverlayScript := preload("res://scripts/ui/controls_overlay.gd")
const MainMenuScene := preload("res://scenes/menu/main_menu.tscn")


func before_each() -> void:
	_cleanup_temp_dir()
	BindingSettings.default_settings().apply_to_input_map()


func after_each() -> void:
	BindingSettings.default_settings().apply_to_input_map()
	_cleanup_temp_dir()


func test_every_slice_action_has_keyboard_mouse_and_gamepad_defaults() -> void:
	var bindings = BindingSettings.default_settings()
	assert_true(BindingSettings.action_definitions().size() >= 18)
	for definition: Dictionary in BindingSettings.action_definitions():
		var action: StringName = definition["id"]
		assert_false(bindings.events_for(action, BindingSettings.DEVICE_KEYBOARD_MOUSE).is_empty(), "%s needs keyboard/mouse" % action)
		assert_false(bindings.events_for(action, BindingSettings.DEVICE_GAMEPAD).is_empty(), "%s needs gamepad" % action)


func test_rebinding_replaces_one_device_and_applies_to_input_map() -> void:
	var bindings = BindingSettings.default_settings()
	var key := InputEventKey.new()
	key.physical_keycode = KEY_R
	assert_true(bindings.replace_device_binding(&"interact", BindingSettings.DEVICE_KEYBOARD_MOUSE, key))
	bindings.apply_to_input_map()
	var keyboard_events := bindings.events_for(&"interact", BindingSettings.DEVICE_KEYBOARD_MOUSE)
	assert_eq(keyboard_events.size(), 1)
	assert_eq((keyboard_events[0] as InputEventKey).physical_keycode, KEY_R)
	assert_true(key.is_action(&"interact"), "InputMap must recognize the replacement immediately")
	assert_false(InputEventKey.new().is_action(&"interact"))


func test_input_bindings_round_trip_without_overwriting_dialogue_settings() -> void:
	var store = StoreScript.new()
	store.settings_directory = _temp_dir()
	var dialogue = store.load_dialogue_settings()
	dialogue.text_speed = "fast"
	assert_true(store.save_dialogue_settings(dialogue))
	var bindings = store.load_input_bindings()
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_START
	assert_true(bindings.replace_device_binding(&"toggle_inventory", BindingSettings.DEVICE_GAMEPAD, button))
	assert_true(store.save_input_bindings(bindings))
	assert_eq(store.load_dialogue_settings().text_speed, "fast")
	var loaded = store.load_input_bindings()
	assert_eq((loaded.events_for(&"toggle_inventory", BindingSettings.DEVICE_GAMEPAD)[0] as InputEventJoypadButton).button_index, JOY_BUTTON_START)


func test_controls_overlay_exposes_focusable_device_buttons() -> void:
	var overlay = ControlsOverlayScript.new()
	overlay.configure(UserSettings)
	(Engine.get_main_loop() as SceneTree).root.add_child(overlay)
	overlay.open()
	var keyboard := overlay.find_child("InteractKeyboardMouse", true, false) as Button
	var gamepad := overlay.find_child("InteractGamepad", true, false) as Button
	assert_true(keyboard != null)
	assert_true(gamepad != null)
	assert_eq(keyboard.focus_mode, Control.FOCUS_ALL)
	assert_true(keyboard.has_focus(), "opening controls must seed keyboard/gamepad focus")
	overlay.free()


func test_main_menu_start_and_exit_are_in_gamepad_focus_ring() -> void:
	var menu := MainMenuScene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(menu)
	var start := menu.get_node("Start label") as Control
	var exit := menu.get_node("Exit label") as Control
	assert_eq(start.focus_mode, Control.FOCUS_ALL)
	assert_eq(exit.focus_mode, Control.FOCUS_ALL)
	assert_eq(start.focus_neighbor_bottom, NodePath("../Exit label"))
	assert_eq(exit.focus_neighbor_top, NodePath("../Start label"))
	menu.free()


func _temp_dir() -> String:
	return "user://test_input_bindings_%d" % Time.get_ticks_msec()


func _cleanup_temp_dir() -> void:
	var root := DirAccess.open("user://")
	if root == null:
		return
	root.list_dir_begin()
	var entry := root.get_next()
	while entry != "":
		if entry.begins_with("test_input_bindings_"):
			_remove_tree("user://%s" % entry)
		entry = root.get_next()
	root.list_dir_end()


func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var child := "%s/%s" % [path.trim_suffix("/"), entry]
			if DirAccess.dir_exists_absolute(child):
				_remove_tree(child)
			else:
				DirAccess.remove_absolute(child)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)
