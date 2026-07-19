class_name DialogueUI
extends CanvasLayer

const TextScaleScript := preload("res://scripts/dialogue/dialogue_text_scale.gd")
const PortraitResolverScript := preload("res://scripts/dialogue/dialogue_portrait_resolver.gd")
const DialogueSettingsScript := preload("res://scripts/settings/dialogue_settings.gd")
const PseudoLocalizationScript := preload("res://scripts/dialogue/dialogue_pseudo_localization.gd")
const TextLayoutScript := preload("res://scripts/dialogue/dialogue_text_layout.gd")
const DialogueUiBuilder := preload("res://scripts/dialogue/dialogue_ui_builder.gd")
const DialogueUiTheme := preload("res://scripts/dialogue/dialogue_ui_theme.gd")
const DialogueUiInput := preload("res://scripts/dialogue/dialogue_ui_input.gd")
const DialogueUiReveal := preload("res://scripts/dialogue/dialogue_ui_reveal.gd")
const DialogueUiChoices := preload("res://scripts/dialogue/dialogue_ui_choices.gd")

signal choice_selected(choice_id: String)
signal skip_requested()

const FONT_PATH := "res://assets/fonts/NotoSans-Regular.ttf"
const PORTRAIT_SIZE := 96

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
		DialogueUiReveal.restart(self)


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
		DialogueUiReveal.complete(self)
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
	DialogueUiChoices.clear(self)
	_choice_mode = false
	_show_overlay()
	DialogueUiReveal.start(self)
	_update_continue_hint()
	_update_disabled_reason()
	_reset_text_scroll()


func present_choices(choices: Array) -> void:
	_choices = DialogueUiChoices.localize(choices, localize_text_for_display)
	_choice_mode = true
	_focused_choice_index = DialogueUiChoices.first_enabled_index(self)
	DialogueUiChoices.rebuild_buttons(self)
	_update_continue_hint()
	_update_disabled_reason()
	DialogueUiChoices.focus_current(self)
	_reset_text_scroll()


func close() -> void:
	hide_overlay()


func hide_overlay() -> void:
	_visible_active = false
	_choice_mode = false
	_backlog_open = false
	_choices.clear()
	DialogueUiChoices.clear(self)
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
	DialogueUiChoices.focus_current(self)
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


func _reset_text_scroll() -> void:
	if _text_scroll == null:
		return
	_text_scroll.scroll_vertical = 0


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
	DialogueUiChoices.move_focus(self, delta)


func _confirm_focused_choice() -> bool:
	return DialogueUiChoices.confirm_focused(self)


func _unhandled_input(event: InputEvent) -> void:
	if DialogueUiInput.handle_unhandled_input(self, event):
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	DialogueUiReveal.process(self, delta)


func _complete_line_reveal() -> void:
	DialogueUiReveal.complete(self)


func _apply_visual_theme() -> void:
	DialogueUiTheme.apply_visual_theme(self)


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
