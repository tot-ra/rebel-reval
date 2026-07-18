class_name DialogueUI
extends CanvasLayer

const TextScaleScript := preload("res://scripts/dialogue/dialogue_text_scale.gd")
const PortraitResolverScript := preload("res://scripts/dialogue/dialogue_portrait_resolver.gd")

signal choice_selected(choice_id: String)
signal skip_requested()

const FONT_PATH := "res://assets/fonts/NotoSans-Regular.ttf"
const PORTRAIT_SIZE := 96

var _font: Font
var _text_scale := "normal"
var _visible_active := false
var _choice_mode := false
var _backlog_open := false
var _choices: Array = []
var _choice_buttons: Array[Button] = []
var _focused_choice_index := 0
var _backlog_entries: Array[Dictionary] = []

var _root: Control
var _panel: PanelContainer
var _backlog_panel: PanelContainer
var _backlog_list: VBoxContainer
var _portrait_rect: TextureRect
var _portrait_fallback: Label
var _speaker_label: Label
var _text_label: Label
var _choices_box: VBoxContainer
var _continue_hint: Label
var _disabled_reason_label: Label
var _skip_button: Button
var _backlog_button: Button


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = load(FONT_PATH) as Font
	_build_ui()
	hide_overlay()


func set_text_scale(scale_name: String) -> void:
	if not TextScaleScript.is_supported(scale_name):
		return
	_text_scale = scale_name
	_apply_text_scale()


func get_text_scale() -> String:
	return _text_scale


func is_showing() -> bool:
	return _visible_active


func is_choice_mode() -> bool:
	return _choice_mode


func get_focused_choice_index() -> int:
	return _focused_choice_index


func get_disabled_reason() -> String:
	return _disabled_reason_label.text


func get_backlog_entry_count() -> int:
	return _backlog_entries.size()


func get_speaker_label_text() -> String:
	return _speaker_label.text


func present_line(speaker_id: StringName, speaker_name: String, text: String, _node_id: String) -> void:
	_append_backlog_entry(speaker_name, text)
	_set_portrait(speaker_id, speaker_name)
	_speaker_label.text = speaker_name
	_text_label.text = text
	_clear_choices()
	_choice_mode = false
	_show_overlay()
	_update_continue_hint()
	_update_disabled_reason()


func present_choices(choices: Array) -> void:
	_choices = choices.duplicate(true)
	_choice_mode = true
	_focused_choice_index = _first_enabled_choice_index()
	_rebuild_choice_buttons()
	_update_continue_hint()
	_update_disabled_reason()
	_focus_current_choice()


func close() -> void:
	hide_overlay()


func hide_overlay() -> void:
	_visible_active = false
	_choice_mode = false
	_backlog_open = false
	_choices.clear()
	_clear_choices()
	_root.visible = false
	_backlog_panel.visible = false
	_speaker_label.text = ""
	_text_label.text = ""
	_disabled_reason_label.text = ""


func select_choice_for_test(choice_id: String) -> void:
	_on_choice_pressed(choice_id)


func focus_choice_for_test(index: int) -> void:
	if index < 0 or index >= _choice_buttons.size():
		return
	_focused_choice_index = index
	_focus_current_choice()
	_update_disabled_reason()


func toggle_backlog_for_test() -> void:
	_toggle_backlog()


func _show_overlay() -> void:
	_visible_active = true
	_root.visible = true


func _append_backlog_entry(speaker_name: String, text: String) -> void:
	if speaker_name.is_empty() and text.is_empty():
		return
	_backlog_entries.append({
		"speaker_name": speaker_name,
		"text": text,
	})
	_rebuild_backlog()


func _set_portrait(speaker_id: StringName, speaker_name: String) -> void:
	var texture := PortraitResolverScript.resolve_texture(speaker_id)
	if texture != null:
		_portrait_rect.texture = texture
		_portrait_rect.visible = true
		_portrait_fallback.visible = false
		return

	_portrait_rect.texture = null
	_portrait_rect.visible = false
	_portrait_fallback.visible = true
	_portrait_fallback.text = _initials_for(speaker_name)


func _initials_for(speaker_name: String) -> String:
	var parts := speaker_name.strip_edges().split(" ", false)
	if parts.is_empty():
		return "?"
	if parts.size() == 1:
		return parts[0].left(1).to_upper()
	return (parts[0].left(1) + parts[1].left(1)).to_upper()


func _clear_choices() -> void:
	for button in _choice_buttons:
		if is_instance_valid(button):
			button.queue_free()
	_choice_buttons.clear()


func _rebuild_choice_buttons() -> void:
	_clear_choices()
	for choice_value in _choices:
		if typeof(choice_value) != TYPE_DICTIONARY:
			continue
		var choice: Dictionary = choice_value
		var button := Button.new()
		button.text = String(choice.get("text", ""))
		button.focus_mode = Control.FOCUS_ALL
		button.disabled = not bool(choice.get("enabled", true))
		button.add_theme_font_override("font", _font)
		button.add_theme_font_size_override("font_size", TextScaleScript.choice_size(_text_scale))
		var choice_id := String(choice.get("id", ""))
		button.pressed.connect(_on_choice_pressed.bind(choice_id))
		button.focus_entered.connect(_on_choice_focus.bind(_choice_buttons.size()))
		_choices_box.add_child(button)
		_choice_buttons.append(button)


func _rebuild_backlog() -> void:
	for child in _backlog_list.get_children():
		child.queue_free()
	for entry in _backlog_entries:
		var line := Label.new()
		var speaker_name := String(entry.get("speaker_name", ""))
		var text := String(entry.get("text", ""))
		line.text = "%s: %s" % [speaker_name, text] if not speaker_name.is_empty() else text
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_theme_font_override("font", _font)
		line.add_theme_font_size_override("font_size", TextScaleScript.backlog_size(_text_scale))
		_backlog_list.add_child(line)


func _first_enabled_choice_index() -> int:
	for index in range(_choices.size()):
		var choice: Dictionary = _choices[index]
		if bool(choice.get("enabled", false)):
			return index
	return 0


func _focus_current_choice() -> void:
	if _focused_choice_index < 0 or _focused_choice_index >= _choice_buttons.size():
		return
	var button := _choice_buttons[_focused_choice_index]
	if button.disabled:
		return
	button.grab_focus()


func _update_continue_hint() -> void:
	if _backlog_open:
		_continue_hint.text = "Esc - close backlog"
	elif _choice_mode:
		_continue_hint.text = "Arrows or gamepad - choose, Enter or A - confirm"
	else:
		_continue_hint.text = "E, Enter, or A - continue | Tab - backlog | Esc - skip"


func _update_disabled_reason() -> void:
	_disabled_reason_label.text = ""
	if not _choice_mode or _focused_choice_index < 0 or _focused_choice_index >= _choices.size():
		return
	var choice: Dictionary = _choices[_focused_choice_index]
	if bool(choice.get("enabled", true)):
		return
	_disabled_reason_label.text = String(choice.get("disabled_reason", ""))


func _toggle_backlog() -> void:
	_backlog_open = not _backlog_open
	_backlog_panel.visible = _backlog_open
	_update_continue_hint()


func _on_choice_pressed(choice_id: String) -> void:
	if choice_id.is_empty():
		return
	for choice_value in _choices:
		if typeof(choice_value) != TYPE_DICTIONARY:
			continue
		var choice: Dictionary = choice_value
		if String(choice.get("id", "")) != choice_id:
			continue
		if not bool(choice.get("enabled", true)):
			_disabled_reason_label.text = String(choice.get("disabled_reason", ""))
			return
		choice_selected.emit(choice_id)
		return


func _on_choice_focus(index: int) -> void:
	_focused_choice_index = index
	_update_disabled_reason()


func _move_choice_focus(delta: int) -> void:
	if not _choice_mode or _choice_buttons.is_empty():
		return
	var count := _choice_buttons.size()
	_focused_choice_index = posmod(_focused_choice_index + delta, count)
	_focus_current_choice()
	if _focused_choice_index < _choice_buttons.size() and _choice_buttons[_focused_choice_index].disabled:
		_move_choice_focus(delta)


func _confirm_focused_choice() -> bool:
	if not _choice_mode or _focused_choice_index < 0 or _focused_choice_index >= _choices.size():
		return false
	var choice: Dictionary = _choices[_focused_choice_index]
	if not bool(choice.get("enabled", true)):
		_update_disabled_reason()
		return true
	choice_selected.emit(String(choice.get("id", "")))
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not _visible_active:
		return

	if _handle_backlog_input(event):
		get_viewport().set_input_as_handled()
		return

	if _handle_skip_input(event):
		get_viewport().set_input_as_handled()
		return

	if _choice_mode and _handle_choice_input(event):
		get_viewport().set_input_as_handled()


func _handle_skip_input(event: InputEvent) -> bool:
	if event.is_echo() or _choice_mode or _backlog_open:
		return false
	if event.is_action_pressed(&"ui_cancel"):
		skip_requested.emit()
		return true
	return false


func _handle_backlog_input(event: InputEvent) -> bool:
	if event.is_echo():
		return false

	if event.is_action_pressed(&"ui_cancel"):
		if _backlog_open:
			_toggle_backlog()
			return true
		return false

	if event.is_action_pressed(&"ui_page_up") or _is_key_pressed(event, KEY_TAB):
		_toggle_backlog()
		return true

	return false


func _handle_choice_input(event: InputEvent) -> bool:
	if event.is_action_pressed(&"ui_up"):
		_move_choice_focus(-1)
		return true
	if event.is_action_pressed(&"ui_down"):
		_move_choice_focus(1)
		return true
	if _is_continue_event(event):
		return _confirm_focused_choice()
	return false


func _is_continue_event(event: InputEvent) -> bool:
	if not event.is_pressed() or event.is_echo():
		return false
	for action: StringName in [&"interact", &"ui_accept"]:
		if event.is_action(action):
			return event.is_action_pressed(action)
	if event is InputEventJoypadButton:
		var button_event := event as InputEventJoypadButton
		return button_event.pressed and button_event.button_index == JOY_BUTTON_A
	return _is_key_pressed(event, KEY_ENTER) or _is_key_pressed(event, KEY_KP_ENTER) or _is_key_pressed(event, KEY_SPACE)


func _is_key_pressed(event: InputEvent, keycode: Key) -> bool:
	return event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == keycode


func _apply_text_scale() -> void:
	_speaker_label.add_theme_font_size_override("font_size", TextScaleScript.speaker_size(_text_scale))
	_text_label.add_theme_font_size_override("font_size", TextScaleScript.body_size(_text_scale))
	_continue_hint.add_theme_font_size_override("font_size", TextScaleScript.hint_size(_text_scale))
	_disabled_reason_label.add_theme_font_size_override("font_size", TextScaleScript.hint_size(_text_scale))
	_portrait_fallback.add_theme_font_size_override("font_size", TextScaleScript.speaker_size(_text_scale))
	for button in _choice_buttons:
		button.add_theme_font_size_override("font_size", TextScaleScript.choice_size(_text_scale))
	_rebuild_backlog()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var stack := VBoxContainer.new()
	stack.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)

	_backlog_panel = PanelContainer.new()
	_backlog_panel.visible = false
	_backlog_panel.custom_minimum_size = Vector2(0, 180)
	stack.add_child(_backlog_panel)

	var backlog_scroll := ScrollContainer.new()
	backlog_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_backlog_panel.add_child(backlog_scroll)

	_backlog_list = VBoxContainer.new()
	_backlog_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	backlog_scroll.add_child(_backlog_list)

	_root = Control.new()
	_root.custom_minimum_size = Vector2(0, 220)
	stack.add_child(_root)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_panel)

	var content := MarginContainer.new()
	content.add_theme_constant_override("margin_left", 16)
	content.add_theme_constant_override("margin_right", 16)
	content.add_theme_constant_override("margin_top", 12)
	content.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(content)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	content.add_child(body)

	var portrait_box := PanelContainer.new()
	portrait_box.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	body.add_child(portrait_box)

	var portrait_stack := Control.new()
	portrait_stack.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	portrait_box.add_child(portrait_stack)

	_portrait_rect = TextureRect.new()
	_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait_rect.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	portrait_stack.add_child(_portrait_rect)

	_portrait_fallback = Label.new()
	_portrait_fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
	_portrait_fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_portrait_fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_portrait_fallback.add_theme_font_override("font", _font)
	portrait_stack.add_child(_portrait_fallback)

	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.add_theme_constant_override("separation", 8)
	body.add_child(text_column)

	_speaker_label = Label.new()
	_speaker_label.add_theme_color_override("font_color", Color(0.92, 0.78, 0.42, 1.0))
	_speaker_label.add_theme_font_override("font", _font)
	text_column.add_child(_speaker_label)

	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_label.custom_minimum_size = Vector2(640, 72)
	_text_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9, 1.0))
	_text_label.add_theme_font_override("font", _font)
	text_column.add_child(_text_label)

	_choices_box = VBoxContainer.new()
	_choices_box.add_theme_constant_override("separation", 4)
	text_column.add_child(_choices_box)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	text_column.add_child(footer)

	_continue_hint = Label.new()
	_continue_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_continue_hint.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82, 1.0))
	_continue_hint.add_theme_font_override("font", _font)
	footer.add_child(_continue_hint)

	_backlog_button = Button.new()
	_backlog_button.text = "Backlog"
	_backlog_button.add_theme_font_override("font", _font)
	_backlog_button.pressed.connect(_toggle_backlog)
	footer.add_child(_backlog_button)

	_skip_button = Button.new()
	_skip_button.text = "Skip"
	_skip_button.add_theme_font_override("font", _font)
	_skip_button.pressed.connect(func() -> void: skip_requested.emit())
	footer.add_child(_skip_button)

	_disabled_reason_label = Label.new()
	_disabled_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_disabled_reason_label.add_theme_color_override("font_color", Color(0.86, 0.55, 0.48, 1.0))
	_disabled_reason_label.add_theme_font_override("font", _font)
	text_column.add_child(_disabled_reason_label)

	_apply_text_scale()
