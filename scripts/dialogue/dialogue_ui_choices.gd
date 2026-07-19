class_name DialogueUiChoices
extends RefCounted

## Choice list rendering and keyboard focus for DialogueUI.

const TextScaleScript := preload("res://scripts/dialogue/dialogue_text_scale.gd")

static func clear(ui: DialogueUI) -> void:
	for button in ui._choice_buttons:
		if is_instance_valid(button):
			button.queue_free()
	ui._choice_buttons.clear()


static func rebuild_buttons(ui: DialogueUI) -> void:
	clear(ui)
	for choice_value in ui._choices:
		if typeof(choice_value) != TYPE_DICTIONARY:
			continue
		var choice: Dictionary = choice_value
		var button := Button.new()
		var choice_text := String(choice.get("text", ""))
		button.text = choice_text
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.focus_mode = Control.FOCUS_ALL
		button.disabled = not bool(choice.get("enabled", true))
		button.add_theme_font_override("font", ui._font)
		button.add_theme_font_size_override("font_size", TextScaleScript.choice_size(ui._text_scale))
		var choice_id := String(choice.get("id", ""))
		button.pressed.connect(ui._on_choice_pressed.bind(choice_id))
		button.focus_entered.connect(ui._on_choice_focus.bind(ui._choice_buttons.size()))
		ui._choices_box.add_child(button)
		ui._choice_buttons.append(button)


static func localize(choices: Array, localize_text: Callable) -> Array:
	var localized: Array = []
	for choice_value in choices:
		if typeof(choice_value) != TYPE_DICTIONARY:
			continue
		var choice: Dictionary = (choice_value as Dictionary).duplicate(true)
		choice["text"] = localize_text.call(String(choice.get("text", "")))
		var disabled_reason := String(choice.get("disabled_reason", ""))
		if not disabled_reason.is_empty():
			choice["disabled_reason"] = localize_text.call(disabled_reason)
		localized.append(choice)
	return localized


static func first_enabled_index(ui: DialogueUI) -> int:
	for index in range(ui._choices.size()):
		var choice: Dictionary = ui._choices[index]
		if bool(choice.get("enabled", false)):
			return index
	return 0


static func focus_current(ui: DialogueUI) -> void:
	if ui._focused_choice_index < 0 or ui._focused_choice_index >= ui._choice_buttons.size():
		return
	var button := ui._choice_buttons[ui._focused_choice_index]
	if button.disabled:
		return
	button.grab_focus()


static func move_focus(ui: DialogueUI, delta: int) -> void:
	if not ui._choice_mode or ui._choice_buttons.is_empty():
		return
	var count := ui._choice_buttons.size()
	ui._focused_choice_index = posmod(ui._focused_choice_index + delta, count)
	focus_current(ui)
	if ui._focused_choice_index < ui._choice_buttons.size() and ui._choice_buttons[ui._focused_choice_index].disabled:
		move_focus(ui, delta)


static func confirm_focused(ui: DialogueUI) -> bool:
	if not ui._choice_mode or ui._focused_choice_index < 0 or ui._focused_choice_index >= ui._choices.size():
		return false
	var choice: Dictionary = ui._choices[ui._focused_choice_index]
	if not bool(choice.get("enabled", true)):
		ui._update_disabled_reason()
		return true
	ui.choice_selected.emit(String(choice.get("id", "")))
	return true
