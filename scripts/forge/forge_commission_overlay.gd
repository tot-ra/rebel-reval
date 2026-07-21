class_name ForgeCommissionOverlay
extends CanvasLayer

signal closed()
signal option_selected(option_id: String)

var _panel: PanelContainer
var _title_label: Label
var _customer_value: Label
var _object_value: Label
var _purpose_value: Label
var _materials_value: Label
var _leverage_list: ItemList
var _options_box: VBoxContainer
var _resolved_label: Label
var _snapshot: Dictionary = {}
var _option_buttons: Array[Button] = []


func _ready() -> void:
	layer = 22
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func is_open() -> bool:
	return visible


func present_commission(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	visible = true
	_refresh()


func close() -> void:
	visible = false
	_snapshot = {}
	_clear_option_buttons()
	closed.emit()


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
	dim.color = Color(0.04, 0.05, 0.08, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	_panel = PanelContainer.new()
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_panel.custom_minimum_size = Vector2(560, 420)
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
	header.text = "Forge commission"
	header.add_theme_font_size_override("font_size", 22)
	layout.add_child(header)

	_title_label = Label.new()
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.add_theme_font_size_override("font_size", 17)
	_title_label.add_theme_color_override("font_color", Color(0.92, 0.9, 0.82, 1.0))
	layout.add_child(_title_label)

	_customer_value = _add_field_row(layout, "Customer")
	_object_value = _add_field_row(layout, "Object")
	_purpose_value = _add_field_row(layout, "Known purpose")
	_materials_value = _add_field_row(layout, "Materials")

	var leverage_header := Label.new()
	leverage_header.text = "Discovered leverage"
	leverage_header.add_theme_font_size_override("font_size", 15)
	layout.add_child(leverage_header)

	_leverage_list = ItemList.new()
	_leverage_list.custom_minimum_size = Vector2(0, 72)
	_leverage_list.fixed_icon_size = Vector2.ZERO
	layout.add_child(_leverage_list)

	var options_header := Label.new()
	options_header.text = "Forging options"
	options_header.add_theme_font_size_override("font_size", 15)
	layout.add_child(options_header)

	_options_box = VBoxContainer.new()
	_options_box.add_theme_constant_override("separation", 6)
	layout.add_child(_options_box)

	_resolved_label = Label.new()
	_resolved_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_resolved_label.add_theme_font_size_override("font_size", 14)
	_resolved_label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.72, 1.0))
	layout.add_child(_resolved_label)

	var hint := Label.new()
	hint.text = "Press Esc to close"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.72, 0.72, 0.68, 1.0))
	layout.add_child(hint)


func _add_field_row(parent: VBoxContainer, label_text: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var label := Label.new()
	label.text = "%s:" % label_text
	label.custom_minimum_size.x = 140
	label.add_theme_font_size_override("font_size", 14)
	row.add_child(label)

	var value := Label.new()
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.add_theme_font_size_override("font_size", 14)
	row.add_child(value)
	return value


func _refresh() -> void:
	if _title_label == null:
		return

	_title_label.text = String(_snapshot.get("title", ""))
	_customer_value.text = String(_snapshot.get("customer_name", ""))
	_object_value.text = String(_snapshot.get("object_name", ""))
	_purpose_value.text = String(_snapshot.get("known_purpose", ""))
	_materials_value.text = String(_snapshot.get("materials", ""))

	_leverage_list.clear()
	var leverage: Array = _snapshot.get("discovered_leverage", [])
	if leverage.is_empty():
		_leverage_list.add_item("No leverage discovered yet.")
	else:
		for entry in leverage:
			_leverage_list.add_item(String(entry))

	_clear_option_buttons()
	var already_resolved := bool(_snapshot.get("already_resolved", false))
	_resolved_label.visible = already_resolved
	_resolved_label.text = "This commission is already resolved."
	_options_box.visible = not already_resolved

	if already_resolved:
		return

	for option_value in _snapshot.get("forging_options", []) as Array:
		if typeof(option_value) != TYPE_DICTIONARY:
			continue
		var option := option_value as Dictionary
		var button := Button.new()
		button.text = String(option.get("label", ""))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.disabled = not bool(option.get("enabled", true))
		if button.disabled:
			var reason := String(option.get("disabled_reason", ""))
			if not reason.is_empty():
				button.tooltip_text = reason
		var option_id := String(option.get("id", ""))
		button.pressed.connect(func() -> void:
			option_selected.emit(option_id)
		)
		_options_box.add_child(button)
		_option_buttons.append(button)


func _clear_option_buttons() -> void:
	for button in _option_buttons:
		if is_instance_valid(button):
			button.queue_free()
	_option_buttons.clear()
	if _options_box != null:
		for child in _options_box.get_children():
			child.queue_free()
