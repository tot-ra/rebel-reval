class_name DialogueUI
extends CanvasLayer

const TextScaleScript := preload("res://scripts/dialogue/dialogue_text_scale.gd")
const PortraitResolverScript := preload("res://scripts/dialogue/dialogue_portrait_resolver.gd")
const DialogueSettingsScript := preload("res://scripts/settings/dialogue_settings.gd")
const PseudoLocalizationScript := preload("res://scripts/dialogue/dialogue_pseudo_localization.gd")
const TextLayoutScript := preload("res://scripts/dialogue/dialogue_text_layout.gd")
const DialogueUiBuilder := preload("res://scripts/dialogue/dialogue_ui_builder.gd")

signal choice_selected(choice_id: String)
signal skip_requested()

const FONT_PATH := "res://assets/fonts/NotoSans-Regular.ttf"
const PORTRAIT_SIZE := 96

const COLOR_BODY_DEFAULT := Color(0.95, 0.95, 0.9, 1.0)
const COLOR_BODY_HIGH_CONTRAST := Color(1.0, 1.0, 1.0, 1.0)
const COLOR_SPEAKER_DEFAULT := Color(0.92, 0.78, 0.42, 1.0)
const COLOR_SPEAKER_HIGH_CONTRAST := Color(1.0, 0.92, 0.35, 1.0)
const COLOR_HINT_DEFAULT := Color(0.72, 0.76, 0.82, 1.0)
const COLOR_HINT_HIGH_CONTRAST := Color(0.9, 0.93, 0.98, 1.0)
const COLOR_DISABLED_DEFAULT := Color(0.86, 0.55, 0.48, 1.0)
const COLOR_DISABLED_HIGH_CONTRAST := Color(1.0, 0.72, 0.62, 1.0)
const COLOR_PANEL_DEFAULT := Color(0.08, 0.09, 0.11, 0.88)
const COLOR_PANEL_HIGH_CONTRAST := Color(0.0, 0.0, 0.0, 0.96)
const COLOR_SUBTITLE_BACKGROUND := Color(0.0, 0.0, 0.0, 0.72)

var _font: Font
var _settings = DialogueSettingsScript.default_settings()
var _text_scale := "normal"
var _visible_active := false
var _choice_mode := false
var _backlog_open := false
var _choices: Array = []
var _choice_buttons: Array[Button] = []
var _focused_choice_index := 0
var _backlog_entries: Array[Dictionary] = []
var _full_line_text := ""
var _revealed_char_count := 0
var _reveal_complete := true
var _reveal_accumulator := 0.0

var _root: Control
var _panel: PanelContainer
var _backlog_panel: PanelContainer
var _backlog_list: VBoxContainer
var _text_background: ColorRect
var _portrait_rect: TextureRect
var _portrait_fallback: Label
var _speaker_label: Label
var _text_scroll: ScrollContainer
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


func apply_settings(settings) -> void:
	if settings == null:
		return
	_settings = settings.duplicate_settings()
	_settings.normalize()
	set_text_scale(_settings.text_scale)
	_apply_visual_theme()
	if _visible_active and not _choice_mode:
		_restart_line_reveal()


func get_settings():
	return _settings.duplicate_settings()


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


func is_reveal_complete() -> bool:
	return _reveal_complete


func get_visible_line_text() -> String:
	return _text_label.text


func body_text_fits_or_scrolls(viewport_size: Vector2i) -> bool:
	return TextLayoutScript.text_fits_or_needs_scroll(
		_font,
		_full_line_text,
		viewport_size,
		_text_scale,
		_choice_buttons.size(),
		not _disabled_reason_label.text.is_empty()
	)


func localize_text_for_display(text: String) -> String:
	if not _settings.pseudo_localization or text.is_empty():
		return text
	return PseudoLocalizationScript.expand(text)


func consume_line_advance() -> bool:
	if _choice_mode or _full_line_text.is_empty():
		return true
	if not _reveal_complete:
		_complete_line_reveal()
		return false
	return true


func get_speaker_label_text() -> String:
	return _speaker_label.text


func present_line(speaker_id: StringName, speaker_name: String, text: String, _node_id: String) -> void:
	var display_speaker := localize_text_for_display(speaker_name)
	var display_text := localize_text_for_display(text)
	_append_backlog_entry(display_speaker, display_text)
	_set_portrait(speaker_id, display_speaker)
	_speaker_label.text = display_speaker
	_full_line_text = display_text
	_clear_choices()
	_choice_mode = false
	_show_overlay()
	_start_line_reveal()
	_update_continue_hint()
	_update_disabled_reason()
	_reset_text_scroll()


func present_choices(choices: Array) -> void:
	_choices = _localize_choices(choices)
	_choice_mode = true
	_focused_choice_index = _first_enabled_choice_index()
	_rebuild_choice_buttons()
	_update_continue_hint()
	_update_disabled_reason()
	_focus_current_choice()
	_reset_text_scroll()


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
	_full_line_text = ""
	_revealed_char_count = 0
	_reveal_complete = true
	_reveal_accumulator = 0.0
	_disabled_reason_label.text = ""
	set_process(false)


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
		var choice_text := String(choice.get("text", ""))
		button.text = choice_text
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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


func _localize_choices(choices: Array) -> Array:
	var localized: Array = []
	for choice_value in choices:
		if typeof(choice_value) != TYPE_DICTIONARY:
			continue
		var choice: Dictionary = (choice_value as Dictionary).duplicate(true)
		choice["text"] = localize_text_for_display(String(choice.get("text", "")))
		var disabled_reason := String(choice.get("disabled_reason", ""))
		if not disabled_reason.is_empty():
			choice["disabled_reason"] = localize_text_for_display(disabled_reason)
		localized.append(choice)
	return localized


func _reset_text_scroll() -> void:
	if _text_scroll == null:
		return
	_text_scroll.scroll_vertical = 0


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
	_disabled_reason_label.text = localize_text_for_display(
		String(choice.get("disabled_reason", ""))
	)


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
			_disabled_reason_label.text = localize_text_for_display(
				String(choice.get("disabled_reason", ""))
			)
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
		if not _reveal_complete:
			_complete_line_reveal()
			return true
		skip_requested.emit()
		return true
	return false


func _process(delta: float) -> void:
	if _reveal_complete or _full_line_text.is_empty():
		set_process(false)
		return

	_reveal_accumulator += delta * _settings.chars_per_second()
	while _reveal_accumulator >= 1.0 and _revealed_char_count < _full_line_text.length():
		_revealed_char_count += 1
		_reveal_accumulator -= 1.0
		_text_label.text = _full_line_text.left(_revealed_char_count)

	if _revealed_char_count >= _full_line_text.length():
		_complete_line_reveal()


func _start_line_reveal() -> void:
	_revealed_char_count = 0
	_reveal_accumulator = 0.0
	if _settings.reveal_instantly() or _full_line_text.is_empty():
		_complete_line_reveal()
		return
	_reveal_complete = false
	_text_label.text = ""
	set_process(true)


func _restart_line_reveal() -> void:
	if _full_line_text.is_empty():
		return
	_start_line_reveal()


func _complete_line_reveal() -> void:
	_revealed_char_count = _full_line_text.length()
	_text_label.text = _full_line_text
	_reveal_complete = true
	_reveal_accumulator = 0.0
	set_process(false)


func _apply_visual_theme() -> void:
	var body_color := COLOR_BODY_HIGH_CONTRAST if _settings.high_contrast else COLOR_BODY_DEFAULT
	var speaker_color := COLOR_SPEAKER_HIGH_CONTRAST if _settings.high_contrast else COLOR_SPEAKER_DEFAULT
	var hint_color := COLOR_HINT_HIGH_CONTRAST if _settings.high_contrast else COLOR_HINT_DEFAULT
	var disabled_color := COLOR_DISABLED_HIGH_CONTRAST if _settings.high_contrast else COLOR_DISABLED_DEFAULT
	var panel_color := COLOR_PANEL_HIGH_CONTRAST if _settings.high_contrast else COLOR_PANEL_DEFAULT

	_speaker_label.add_theme_color_override("font_color", speaker_color)
	_text_label.add_theme_color_override("font_color", body_color)
	_continue_hint.add_theme_color_override("font_color", hint_color)
	_disabled_reason_label.add_theme_color_override("font_color", disabled_color)
	_portrait_fallback.add_theme_color_override("font_color", speaker_color)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = panel_color
	panel_style.set_corner_radius_all(6)
	_panel.add_theme_stylebox_override("panel", panel_style)
	_backlog_panel.add_theme_stylebox_override("panel", panel_style.duplicate())

	_text_background.visible = _settings.subtitle_background
	if _settings.subtitle_background:
		_text_background.color = COLOR_SUBTITLE_BACKGROUND if not _settings.high_contrast else Color(0.0, 0.0, 0.0, 0.88)


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
	var nodes := DialogueUiBuilder.build(self, _font, {
		"toggle_backlog": _toggle_backlog,
		"skip_requested": func() -> void: skip_requested.emit(),
		"sync_text_label_width": _sync_text_label_width,
	})
	_root = nodes["root"]
	_panel = nodes["panel"]
	_backlog_panel = nodes["backlog_panel"]
	_backlog_list = nodes["backlog_list"]
	_text_background = nodes["text_background"]
	_portrait_rect = nodes["portrait_rect"]
	_portrait_fallback = nodes["portrait_fallback"]
	_speaker_label = nodes["speaker_label"]
	_text_scroll = nodes["text_scroll"]
	_text_label = nodes["text_label"]
	_choices_box = nodes["choices_box"]
	_continue_hint = nodes["continue_hint"]
	_disabled_reason_label = nodes["disabled_reason_label"]
	_skip_button = nodes["skip_button"]
	_backlog_button = nodes["backlog_button"]
	_apply_text_scale()
	_apply_visual_theme()


func _sync_text_label_width() -> void:
	if _text_scroll == null or _text_label == null:
		return
	_text_label.custom_minimum_size.x = maxf(_text_scroll.size.x, 1.0)
