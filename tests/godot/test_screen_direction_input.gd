extends "res://tests/godot/test_case.gd"


func test_arrow_actions_still_map_to_screen_axes() -> void:
	Input.action_press("ui_right")
	var direction := ScreenDirectionInput.read_axis()
	Input.action_release("ui_right")
	assert_true(is_equal_approx(direction.x, 1.0), "ui_right must read as screen-right")
	assert_true(is_zero_approx(direction.y), "ui_right must not add vertical input")


func test_wasd_keys_are_bound_to_ui_actions() -> void:
	assert_true(_action_has_physical_key("ui_left", KEY_A), "A must move screen-left")
	assert_true(_action_has_physical_key("ui_right", KEY_D), "D must move screen-right")
	assert_true(_action_has_physical_key("ui_up", KEY_W), "W must move screen-up")
	assert_true(_action_has_physical_key("ui_down", KEY_S), "S must move screen-down")


func _action_has_physical_key(action_name: String, keycode: Key) -> bool:
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.physical_keycode == keycode:
			return true
	return false
