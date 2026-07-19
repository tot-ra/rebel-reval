class_name DemoDialogueBox
extends CanvasLayer

## Minimal demo-only dialogue panel for D-002. Replaced by P1-012 after the slice.

const TextScaleScript := preload("res://scripts/dialogue/dialogue_text_scale.gd")

var _panel: PanelContainer
var _speaker_label: Label
var _text_label: Label
var _hint_label: Label


func _ready() -> void:
	layer = 40
	_build_ui()
	hide_box()


func is_showing() -> bool:
	return _panel.visible


func show_line(speaker_name: String, line_text: String) -> void:
	_speaker_label.text = speaker_name
	_text_label.text = line_text
	_panel.visible = true
	visible = true


func hide_box() -> void:
	_panel.visible = false
	_speaker_label.text = ""
	_text_label.text = ""


func get_speaker_name() -> String:
	return _speaker_label.text


func get_line_text() -> String:
	return _text_label.text


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	add_child(margin)

	var stack := VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_child(stack)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(spacer)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(0, 168)
	_panel.visible = false
	stack.add_child(_panel)

	var content := MarginContainer.new()
	content.add_theme_constant_override("margin_left", 24)
	content.add_theme_constant_override("margin_right", 24)
	content.add_theme_constant_override("margin_top", 18)
	content.add_theme_constant_override("margin_bottom", 18)
	_panel.add_child(content)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	content.add_child(body)

	_speaker_label = Label.new()
	_speaker_label.add_theme_color_override("font_color", Color(0.92, 0.78, 0.42, 1.0))
	_speaker_label.add_theme_font_size_override("font_size", TextScaleScript.speaker_size("normal"))
	body.add_child(_speaker_label)

	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(720, 88)
	_text_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9, 1.0))
	_text_label.add_theme_font_size_override("font_size", TextScaleScript.body_size("normal"))
	body.add_child(_text_label)

	_hint_label = Label.new()
	_hint_label.text = "Click, E, or A - continue"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint_label.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82, 1.0))
	_hint_label.add_theme_font_size_override("font_size", TextScaleScript.hint_size("normal"))
	body.add_child(_hint_label)
