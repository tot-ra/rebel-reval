class_name ReflectionOverlay
extends CanvasLayer

signal closed()
signal conviction_chosen(option_id: String)

var _panel: PanelContainer
var _intro_label: Label
var _recap_label: Label
var _plain_summary_label: Label
var _marks_box: HBoxContainer
var _options_box: VBoxContainer
var _snapshot: Dictionary = {}


func _ready() -> void:
	layer = 23
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	# WHY: stay out of modal_input_overlay until present(); a permanent group
	# membership permanently blocks Player locomotion via _movement_blocked().
	_build_ui()


func is_open() -> bool:
	return visible


func present(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	visible = true
	add_to_group(&"modal_input_overlay")
	_refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	remove_from_group(&"modal_input_overlay")
	_snapshot = {}
	_clear_options()
	closed.emit()


func get_plain_summary_text() -> String:
	return String(_plain_summary_label.text) if _plain_summary_label != null else ""


func get_mark_labels() -> Array[String]:
	var labels: Array[String] = []
	if _marks_box == null:
		return labels
	for child in _marks_box.get_children():
		if child is Label:
			labels.append((child as Label).text)
	return labels


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 48)
	root.add_theme_constant_override("margin_right", 48)
	root.add_theme_constant_override("margin_top", 36)
	root.add_theme_constant_override("margin_bottom", 36)
	add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.06, 0.04, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	_panel = PanelContainer.new()
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_panel.custom_minimum_size = Vector2(580, 460)
	root.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	var header := Label.new()
	header.text = "Hingepuu"
	header.add_theme_font_size_override("font_size", 22)
	layout.add_child(header)

	_intro_label = Label.new()
	_intro_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_intro_label.add_theme_font_size_override("font_size", 15)
	_intro_label.add_theme_color_override("font_color", Color(0.86, 0.9, 0.82, 1.0))
	layout.add_child(_intro_label)

	var recap_header := Label.new()
	recap_header.text = "What the tree remembers"
	recap_header.add_theme_font_size_override("font_size", 15)
	layout.add_child(recap_header)

	_recap_label = Label.new()
	_recap_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_recap_label.add_theme_font_size_override("font_size", 14)
	layout.add_child(_recap_label)

	var marks_header := Label.new()
	marks_header.text = "Consequence marks"
	marks_header.add_theme_font_size_override("font_size", 15)
	layout.add_child(marks_header)

	_marks_box = HBoxContainer.new()
	_marks_box.add_theme_constant_override("separation", 8)
	layout.add_child(_marks_box)

	_plain_summary_label = Label.new()
	_plain_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_plain_summary_label.add_theme_font_size_override("font_size", 13)
	_plain_summary_label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.76, 1.0))
	layout.add_child(_plain_summary_label)

	var options_header := Label.new()
	options_header.text = "Choose a conviction"
	options_header.add_theme_font_size_override("font_size", 15)
	layout.add_child(options_header)

	_options_box = VBoxContainer.new()
	_options_box.add_theme_constant_override("separation", 6)
	layout.add_child(_options_box)


func _refresh() -> void:
	_intro_label.text = String(_snapshot.get("intro", ""))
	var recap_lines: Array = _snapshot.get("recap_lines", [])
	var recap_text := ""
	for index in recap_lines.size():
		if index > 0:
			recap_text += "\n"
		recap_text += String(recap_lines[index])
	_recap_label.text = recap_text
	_plain_summary_label.text = String(_snapshot.get("plain_summary", ""))
	_refresh_marks(_snapshot.get("marks", []) as Array)
	_refresh_options(_snapshot.get("options", []) as Array)


func _refresh_marks(marks: Array) -> void:
	for child in _marks_box.get_children():
		child.queue_free()
	if marks.is_empty():
		var empty := Label.new()
		empty.text = "No marks yet"
		empty.add_theme_color_override("font_color", Color(0.7, 0.72, 0.68, 1.0))
		_marks_box.add_child(empty)
		return
	for mark_variant in marks:
		if not mark_variant is Dictionary:
			continue
		var mark := mark_variant as Dictionary
		var chip := PanelContainer.new()
		var chip_margin := MarginContainer.new()
		chip_margin.add_theme_constant_override("margin_left", 8)
		chip_margin.add_theme_constant_override("margin_right", 8)
		chip_margin.add_theme_constant_override("margin_top", 4)
		chip_margin.add_theme_constant_override("margin_bottom", 4)
		chip.add_child(chip_margin)
		var label := Label.new()
		label.text = String(mark.get("label", ""))
		label.add_theme_font_size_override("font_size", 13)
		var color: Color = mark.get("color", Color.WHITE)
		label.add_theme_color_override("font_color", color)
		chip_margin.add_child(label)
		_marks_box.add_child(chip)


func _refresh_options(options: Array) -> void:
	_clear_options()
	for option_variant in options:
		if not option_variant is Dictionary:
			continue
		var option := option_variant as Dictionary
		var button := Button.new()
		button.focus_mode = Control.FOCUS_ALL
		button.text = "%s - %s" % [String(option.get("title", "")), String(option.get("summary", ""))]
		button.tooltip_text = String(option.get("plain_text", ""))
		var option_id := String(option.get("id", ""))
		button.pressed.connect(func() -> void:
			conviction_chosen.emit(option_id)
		)
		_options_box.add_child(button)


func _clear_options() -> void:
	if _options_box == null:
		return
	for child in _options_box.get_children():
		child.queue_free()
