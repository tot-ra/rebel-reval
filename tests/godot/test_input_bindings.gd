extends "res://tests/godot/test_case.gd"

const BindingSettings := preload("res://scripts/settings/input_binding_settings.gd")
const StoreScript := preload("res://scripts/settings/user_settings_store.gd")
const ControlsOverlayScript := preload("res://scripts/ui/controls_overlay.gd")
const MainMenuScene := preload("res://scenes/menu/main_menu.tscn")

const EXPECTED_SLICE_ACTIONS: Array[StringName] = [
	&"ui_up",
	&"ui_down",
	&"ui_left",
	&"ui_right",
	&"ui_shift",
	&"interact",
	&"ui_accept",
	&"ui_cancel",
	&"ui_page_up",
	&"player_attack",
	&"player_guard",
	&"player_dodge",
	&"toggle_inventory",
	&"toggle_journal",
	&"toggle_camera_view",
	&"toggle_minimap",
	&"toggle_world_map",
	&"toggle_controls",
]


class FakeSettings:
	extends Node

	var input_bindings = BindingSettings.default_settings()
	var rebind_calls := 0

	func rebind_action(
		action: StringName,
		device: StringName,
		event: InputEvent,
		_persist: bool = true
	) -> bool:
		rebind_calls += 1
		return input_bindings.replace_device_binding(action, device, event)

	func restore_default_input_bindings(_persist: bool = true) -> bool:
		input_bindings = BindingSettings.default_settings()
		return true


var _activation_calls := 0


func before_each() -> void:
	_activation_calls = 0
	_cleanup_temp_dir()
	BindingSettings.default_settings().apply_to_input_map()


func after_each() -> void:
	BindingSettings.default_settings().apply_to_input_map()
	_cleanup_temp_dir()


func test_every_slice_action_has_keyboard_mouse_and_gamepad_defaults() -> void:
	var bindings = BindingSettings.default_settings()
	var catalog_actions: Array[StringName] = []
	for definition: Dictionary in BindingSettings.action_definitions():
		var action: StringName = definition["id"]
		catalog_actions.append(action)
		assert_false(bindings.events_for(action, BindingSettings.DEVICE_KEYBOARD_MOUSE).is_empty(), "%s needs keyboard/mouse" % action)
		assert_false(bindings.events_for(action, BindingSettings.DEVICE_GAMEPAD).is_empty(), "%s needs gamepad" % action)
	assert_eq(catalog_actions, EXPECTED_SLICE_ACTIONS, "binding catalog must cover every shipped slice action exactly once")

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


func test_controls_overlay_exposes_two_column_focus_navigation() -> void:
	var overlay = ControlsOverlayScript.new()
	overlay.configure(UserSettings)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(overlay)
	overlay.open()
	var first_keyboard := overlay.find_child("UiUpKeyboardMouse", true, false) as Button
	var first_gamepad := overlay.find_child("UiUpGamepad", true, false) as Button
	var second_keyboard := overlay.find_child("UiDownKeyboardMouse", true, false) as Button
	assert_true(first_keyboard != null)
	assert_true(first_gamepad != null)
	assert_true(second_keyboard != null)
	assert_eq(first_keyboard.focus_mode, Control.FOCUS_ALL)
	assert_eq(tree.root.gui_get_focus_owner(), first_keyboard, "opening controls must seed keyboard/gamepad focus")
	assert_eq(first_keyboard.get_node(first_keyboard.focus_neighbor_right), first_gamepad)
	assert_eq(first_keyboard.get_node(first_keyboard.focus_neighbor_bottom), second_keyboard)
	overlay.free()


func test_controls_overlay_captures_mouse_binding_before_gui_consumes_click() -> void:
	var owner := FakeSettings.new()
	var overlay = ControlsOverlayScript.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(owner)
	tree.root.add_child(overlay)
	overlay.configure(owner)
	overlay.open()
	var binding_button := overlay.find_child("PlayerGuardKeyboardMouse", true, false) as Button
	overlay.begin_capture(&"player_guard", BindingSettings.DEVICE_KEYBOARD_MOUSE, binding_button)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_MIDDLE
	mouse.pressed = true
	tree.root.push_input(mouse, true)
	assert_eq(owner.rebind_calls, 1)
	assert_eq(owner.input_bindings.binding_text(&"player_guard", BindingSettings.DEVICE_KEYBOARD_MOUSE), "Mouse Middle")
	assert_eq(binding_button.text, "Mouse Middle")
	overlay.free()
	owner.free()


func test_rebound_gamepad_navigation_and_confirm_complete_focus_flow() -> void:
	var bindings = BindingSettings.default_settings()
	var move_down := _joy_button(JOY_BUTTON_RIGHT_SHOULDER)
	var confirm := _joy_button(JOY_BUTTON_X)
	assert_true(bindings.replace_device_binding(&"ui_down", BindingSettings.DEVICE_GAMEPAD, move_down))
	assert_true(bindings.replace_device_binding(&"ui_accept", BindingSettings.DEVICE_GAMEPAD, confirm))
	bindings.apply_to_input_map()

	var buttons := VBoxContainer.new()
	var first := Button.new()
	var second := Button.new()
	buttons.add_child(first)
	buttons.add_child(second)
	(Engine.get_main_loop() as SceneTree).root.add_child(buttons)
	first.focus_neighbor_bottom = first.get_path_to(second)
	second.focus_neighbor_top = second.get_path_to(first)
	second.pressed.connect(_on_activation)
	first.grab_focus()

	_push_input(move_down)
	assert_true(second.has_focus(), "rebound gamepad direction must move GUI focus")
	_push_input(confirm)
	assert_eq(_activation_calls, 1, "rebound gamepad confirm must activate the focused control")
	buttons.free()


func test_rebound_keyboard_mouse_navigation_and_confirm_complete_focus_flow() -> void:
	var bindings = BindingSettings.default_settings()
	var move_down := InputEventKey.new()
	move_down.physical_keycode = KEY_R
	var confirm := InputEventMouseButton.new()
	confirm.button_index = MOUSE_BUTTON_MIDDLE
	assert_true(bindings.replace_device_binding(&"ui_down", BindingSettings.DEVICE_KEYBOARD_MOUSE, move_down))
	assert_true(bindings.replace_device_binding(&"ui_accept", BindingSettings.DEVICE_KEYBOARD_MOUSE, confirm))
	bindings.apply_to_input_map()

	var buttons := VBoxContainer.new()
	var first := Button.new()
	var second := Button.new()
	buttons.add_child(first)
	buttons.add_child(second)
	(Engine.get_main_loop() as SceneTree).root.add_child(buttons)
	first.focus_neighbor_bottom = first.get_path_to(second)
	second.focus_neighbor_top = second.get_path_to(first)
	second.pressed.connect(_on_activation)
	first.grab_focus()

	_push_input(move_down)
	assert_true(second.has_focus(), "rebound keyboard direction must move GUI focus")
	_push_input(confirm)
	assert_eq(_activation_calls, 1, "rebound mouse confirm must activate the focused control")
	buttons.free()


func test_replacement_events_map_to_every_catalog_action_on_both_devices() -> void:
	var bindings = BindingSettings.default_settings()
	for definition: Dictionary in BindingSettings.action_definitions():
		var action: StringName = definition["id"]
		var key := InputEventKey.new()
		key.physical_keycode = KEY_R
		assert_true(bindings.replace_device_binding(action, BindingSettings.DEVICE_KEYBOARD_MOUSE, key))
		var button := _joy_button(JOY_BUTTON_START)
		assert_true(bindings.replace_device_binding(action, BindingSettings.DEVICE_GAMEPAD, button))
		bindings.apply_to_input_map()
		assert_true(key.is_action(action), "%s must recognize its replacement key" % action)
		assert_true(button.is_action(action), "%s must recognize its replacement gamepad button" % action)


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



func _joy_button(button_index: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	return event


func _push_input(event: InputEvent) -> void:
	event.pressed = true
	(Engine.get_main_loop() as SceneTree).root.push_input(event, true)
	event.pressed = false
	(Engine.get_main_loop() as SceneTree).root.push_input(event, true)


func _on_activation() -> void:
	_activation_calls += 1

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
