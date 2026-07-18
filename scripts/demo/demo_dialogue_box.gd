class_name DemoDialogueBox
extends CanvasLayer

## Minimal demo-only dialogue panel for D-002. Replaced by P1-012 after the slice.

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
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var bottom := Control.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -168.0
	margin.add_child(bottom)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.visible = false
	bottom.add_child(_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	_panel.add_child(content)

	_speaker_label = Label.new()
	_speaker_label.add_theme_color_override("font_color", Color(0.92, 0.78, 0.42, 1.0))
	content.add_child(_speaker_label)

	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(720, 72)
	_text_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9, 1.0))
	content.add_child(_text_label)

	_hint_label = Label.new()
	_hint_label.text = "E or A - continue"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint_label.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82, 1.0))
	content.add_child(_hint_label)
