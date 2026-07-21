class_name DialogueUiInput
extends RefCounted

## Keyboard, gamepad, and backlog routing for DialogueUI.


static func handle_unhandled_input(ui: DialogueUI, event: InputEvent) -> bool:
	if not ui._visible_active:
		return false

	if handle_backlog_input(ui, event):
		return true

	if handle_skip_input(ui, event):
		return true

	if ui._choice_mode and handle_choice_input(ui, event):
		return true

	return false


static func handle_skip_input(ui: DialogueUI, event: InputEvent) -> bool:
	if event.is_echo() or ui._choice_mode or ui._backlog_open:
		return false
	if event.is_action_pressed(&"ui_cancel"):
		if not ui._reveal_complete:
			ui._complete_line_reveal()
			return true
		ui.skip_requested.emit()
		return true
	return false


static func handle_backlog_input(ui: DialogueUI, event: InputEvent) -> bool:
	if event.is_echo():
		return false

	if event.is_action_pressed(&"ui_cancel"):
		if ui._backlog_open:
			ui._toggle_backlog()
			return true
		return false

	if event.is_action_pressed(&"ui_page_up"):
		ui._toggle_backlog()
		return true

	return false


static func handle_choice_input(ui: DialogueUI, event: InputEvent) -> bool:
	if event.is_action_pressed(&"ui_up"):
		ui._move_choice_focus(-1)
		return true
	if event.is_action_pressed(&"ui_down"):
		ui._move_choice_focus(1)
		return true
	if is_continue_event(event):
		return ui._confirm_focused_choice()
	return false


static func handle_continue_click(ui: DialogueUI, event: InputEvent) -> bool:
	if not ui._visible_active or ui._choice_mode or ui._backlog_open:
		return false
	if not is_mouse_continue_event(event):
		return false
	ui.request_continue()
	return true


static func is_continue_event(event: InputEvent) -> bool:
	if not event.is_pressed() or event.is_echo():
		return false
	if is_mouse_continue_event(event):
		return true
	for action: StringName in [&"interact", &"ui_accept"]:
		if event.is_action(action):
			return event.is_action_pressed(action)
	return false


static func is_mouse_continue_event(event: InputEvent) -> bool:
	if not event is InputEventMouseButton:
		return false
	var mouse_event := event as InputEventMouseButton
	return mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT


static func is_key_pressed(event: InputEvent, keycode: Key) -> bool:
	return event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == keycode
