class_name DialogueUiBuilder
extends RefCounted

## Builds the DialogueUI node tree so the presenter class stays focused on state.

const TextLayoutScript := preload("res://scripts/dialogue/dialogue_text_layout.gd")

const PORTRAIT_SIZE := 96


static func build(host: CanvasLayer, font: Font, callbacks: Dictionary) -> Dictionary:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	host.add_child(margin)

	var stack := VBoxContainer.new()
	stack.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)

	var backlog_panel := PanelContainer.new()
	backlog_panel.visible = false
	backlog_panel.custom_minimum_size = Vector2(0, 220)
	stack.add_child(backlog_panel)

	var backlog_scroll := ScrollContainer.new()
	backlog_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	backlog_panel.add_child(backlog_scroll)

	var backlog_list := VBoxContainer.new()
	backlog_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	backlog_scroll.add_child(backlog_list)

	var root := Control.new()
	root.custom_minimum_size = Vector2(0, TextLayoutScript.DIALOGUE_ROOT_MIN_HEIGHT)
	stack.add_child(root)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(panel)

	var content := MarginContainer.new()
	content.add_theme_constant_override("margin_left", 16)
	content.add_theme_constant_override("margin_right", 16)
	content.add_theme_constant_override("margin_top", 12)
	content.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(content)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	content.add_child(body)

	var portrait_box := PanelContainer.new()
	portrait_box.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	body.add_child(portrait_box)

	var portrait_stack := Control.new()
	portrait_stack.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	portrait_box.add_child(portrait_stack)

	var portrait_rect := TextureRect.new()
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait_rect.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	portrait_stack.add_child(portrait_rect)

	var portrait_fallback := Label.new()
	portrait_fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait_fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	portrait_fallback.add_theme_font_override("font", font)
	portrait_stack.add_child(portrait_fallback)

	var text_wrap := Control.new()
	text_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(text_wrap)

	var text_background := ColorRect.new()
	text_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	text_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_wrap.add_child(text_background)

	var text_column := VBoxContainer.new()
	text_column.set_anchors_preset(Control.PRESET_FULL_RECT)
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.add_theme_constant_override("separation", 8)
	text_wrap.add_child(text_column)

	var speaker_label := Label.new()
	speaker_label.add_theme_color_override("font_color", Color(0.92, 0.78, 0.42, 1.0))
	speaker_label.add_theme_font_override("font", font)
	text_column.add_child(speaker_label)

	var text_scroll := ScrollContainer.new()
	text_scroll.custom_minimum_size = Vector2(0, TextLayoutScript.BODY_SCROLL_MIN_HEIGHT)
	text_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	text_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	text_column.add_child(text_scroll)

	var text_label := Label.new()
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9, 1.0))
	text_label.add_theme_font_override("font", font)
	text_scroll.add_child(text_label)

	var choices_box := VBoxContainer.new()
	choices_box.add_theme_constant_override("separation", 4)
	text_column.add_child(choices_box)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	text_column.add_child(footer)

	var continue_hint := Label.new()
	continue_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	continue_hint.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82, 1.0))
	continue_hint.add_theme_font_override("font", font)
	footer.add_child(continue_hint)

	var backlog_button := Button.new()
	backlog_button.text = "Backlog"
	backlog_button.add_theme_font_override("font", font)
	if callbacks.has("toggle_backlog"):
		backlog_button.pressed.connect(callbacks["toggle_backlog"])
	footer.add_child(backlog_button)

	var skip_button := Button.new()
	skip_button.text = "Skip"
	skip_button.add_theme_font_override("font", font)
	if callbacks.has("skip_requested"):
		skip_button.pressed.connect(callbacks["skip_requested"])
	footer.add_child(skip_button)

	var disabled_reason_label := Label.new()
	disabled_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	disabled_reason_label.add_theme_color_override("font_color", Color(0.86, 0.55, 0.48, 1.0))
	disabled_reason_label.add_theme_font_override("font", font)
	text_column.add_child(disabled_reason_label)

	if callbacks.has("sync_text_label_width"):
		text_scroll.resized.connect(callbacks["sync_text_label_width"])

	return {
		"root": root,
		"panel": panel,
		"backlog_panel": backlog_panel,
		"backlog_list": backlog_list,
		"text_background": text_background,
		"portrait_rect": portrait_rect,
		"portrait_fallback": portrait_fallback,
		"speaker_label": speaker_label,
		"text_scroll": text_scroll,
		"text_label": text_label,
		"choices_box": choices_box,
		"continue_hint": continue_hint,
		"disabled_reason_label": disabled_reason_label,
		"skip_button": skip_button,
		"backlog_button": backlog_button,
	}
