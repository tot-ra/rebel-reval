class_name ForgeFeedbackOverlay
extends CanvasLayer

signal closed
signal sequence_finished(option_id: String)

var _panel: PanelContainer
var _heading_label: Label
var _body_label: Label
var _hint_label: Label
var _sequence: ForgeFeedbackSequence
var _on_complete: Callable


func _ready() -> void:
	layer = 23
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sequence = ForgeFeedbackSequence.new()
	_build_ui()


func is_open() -> bool:
	return visible


func start_forging(
	option_id: String, snapshot: Dictionary, on_complete: Callable = Callable()
) -> void:
	_on_complete = on_complete
	_sequence.reset(option_id, snapshot)
	visible = true
	add_to_group(&"modal_input_overlay")
	_advance_phase()


func close() -> void:
	if not visible:
		return
	visible = false
	remove_from_group(&"modal_input_overlay")
	_on_complete = Callable()
	closed.emit()


func get_sequence() -> ForgeFeedbackSequence:
	return _sequence


func get_trace() -> Array[StringName]:
	return ForgeFeedbackSequence.trace_phases(_sequence.get_option_id(), _sequence.get_snapshot())


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_accept"):
		_advance_phase()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_cancel"):
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
	dim.color = Color(0.08, 0.05, 0.03, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	_panel = PanelContainer.new()
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_panel.custom_minimum_size = Vector2(520, 220)
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
	header.text = "Forging"
	header.add_theme_font_size_override("font_size", 22)
	layout.add_child(header)

	_heading_label = Label.new()
	_heading_label.add_theme_font_size_override("font_size", 17)
	_heading_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.62, 1.0))
	layout.add_child(_heading_label)

	_body_label = Label.new()
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_font_size_override("font_size", 15)
	layout.add_child(_body_label)

	_hint_label = Label.new()
	_hint_label.text = "Press Enter to continue"
	_hint_label.add_theme_font_size_override("font_size", 12)
	_hint_label.add_theme_color_override("font_color", Color(0.72, 0.72, 0.68, 1.0))
	layout.add_child(_hint_label)


func _advance_phase() -> void:
	var phase := _sequence.advance()
	if phase.is_empty():
		_finish_sequence()
		return
	_refresh(phase)


func _refresh(phase: StringName) -> void:
	_heading_label.text = _sequence.heading_for(phase)
	_body_label.text = _sequence.body_for(phase)


func _finish_sequence() -> void:
	var option_id := _sequence.get_option_id()
	visible = false
	remove_from_group(&"modal_input_overlay")
	sequence_finished.emit(option_id)
	if _on_complete.is_valid():
		_on_complete.call()
	_on_complete = Callable()
	closed.emit()
