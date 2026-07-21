class_name ControlsOverlay
extends CanvasLayer

## Focus-first controls editor for keyboard/mouse and gamepad bindings (P1-028).

signal closed()

const BindingSettingsScript := preload("res://scripts/settings/input_binding_settings.gd")
const PANEL_MIN_SIZE := Vector2(1040, 760)

var _settings_owner: Node
var _binding_buttons: Dictionary = {}
var _first_binding_button: Button
var _status_label: Label
var _waiting_action: StringName = &""
var _waiting_device: StringName = &""
var _waiting_button: Button


func configure(settings_owner: Node) -> void:
	_settings_owner = settings_owner
	if is_node_ready():
		_refresh_binding_labels()


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _settings_owner == null and has_node("/root/UserSettings"):
		_settings_owner = get_node("/root/UserSettings")
	_build_ui()
	visible = false


func open() -> void:
	_waiting_action = &""
	_waiting_device = &""
	_waiting_button = null
	_refresh_binding_labels()
	_status_label.text = "Select a binding, then press the replacement input."
	visible = true
	add_to_group(&"modal_input_overlay")
	if _first_binding_button != null:
		_first_binding_button.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	_waiting_action = &""
	_waiting_device = &""
	_waiting_button = null
	remove_from_group(&"modal_input_overlay")
	closed.emit()


func is_open() -> bool:
	return visible


func begin_capture(action: StringName, device: StringName, button: Button = null) -> void:
	if not BindingSettingsScript.has_action(action):
		return
	_waiting_action = action
	_waiting_device = device
	_waiting_button = button if button != null else _button_for(action, device)
	if _waiting_button != null:
		_waiting_button.text = "Press input..."
	_status_label.text = (
		"Press a keyboard or mouse input. Esc cancels capture."
		if device == BindingSettingsScript.DEVICE_KEYBOARD_MOUSE
		else "Press a gamepad button or move a stick fully. Esc cancels capture."
	)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	if not _waiting_action.is_empty():
		if event is InputEventKey and (event as InputEventKey).keycode == KEY_ESCAPE:
			_cancel_capture()
			get_viewport().set_input_as_handled()
			return
		if not BindingSettingsScript.is_supported_event(event, _waiting_device):
			return
		_commit_capture(event)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _commit_capture(event: InputEvent) -> void:
	if _settings_owner == null or not _settings_owner.has_method("rebind_action"):
		_status_label.text = "Bindings service unavailable."
		_cancel_capture(false)
		return
	var changed := bool(_settings_owner.call(
		"rebind_action",
		_waiting_action,
		_waiting_device,
		event,
		true
	))
	var action_label := _action_label(_waiting_action)
	var input_label := BindingSettingsScript.event_text(event)
	_cancel_capture(false)
	_refresh_binding_labels()
	_status_label.text = (
		"%s changed to %s." % [action_label, input_label]
		if changed
		else "Could not save that binding."
	)


func _cancel_capture(update_status: bool = true) -> void:
	_waiting_action = &""
	_waiting_device = &""
	var button := _waiting_button
	_waiting_button = null
	_refresh_binding_labels()
	if update_status:
		_status_label.text = "Binding capture cancelled."
	if button != null:
		button.grab_focus()


func _on_restore_defaults() -> void:
	if _settings_owner == null or not _settings_owner.has_method("restore_default_input_bindings"):
		_status_label.text = "Bindings service unavailable."
		return
	var restored := bool(_settings_owner.call("restore_default_input_bindings", true))
	_refresh_binding_labels()
	_status_label.text = "Default controls restored." if restored else "Could not save default controls."
	if _first_binding_button != null:
		_first_binding_button.grab_focus()


func _build_ui() -> void:
	var root := Control.new()
	root.name = "ControlsRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.025, 0.03, 0.045, 0.92)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "ControlsPanel"
	panel.custom_minimum_size = PANEL_MIN_SIZE
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side: StringName in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 22)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	layout.add_child(header)

	var title := Label.new()
	title.text = "Controls"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.94, 0.81, 0.5, 1.0))
	header.add_child(title)

	var reset := _make_button("RestoreDefaultsButton", "Restore defaults")
	reset.pressed.connect(_on_restore_defaults)
	header.add_child(reset)

	var close_button := _make_button("CloseButton", "Close")
	close_button.pressed.connect(close)
	header.add_child(close_button)

	var intro := Label.new()
	intro.text = "Every vertical-slice action has separate keyboard/mouse and gamepad bindings. Changes save outside campaign slots."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_color_override("font_color", Color(0.78, 0.82, 0.9, 1.0))
	layout.add_child(intro)

	var column_header := HBoxContainer.new()
	column_header.add_theme_constant_override("separation", 10)
	layout.add_child(column_header)
	column_header.add_child(_column_label("Action", 300.0))
	column_header.add_child(_column_label("Keyboard / mouse", 300.0))
	column_header.add_child(_column_label("Gamepad", 300.0))

	var scroll := ScrollContainer.new()
	scroll.name = "BindingsScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)

	var rows := VBoxContainer.new()
	rows.name = "BindingRows"
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 5)
	scroll.add_child(rows)

	var previous_category := ""
	for definition: Dictionary in BindingSettingsScript.action_definitions():
		var category := String(definition["category"])
		if category != previous_category:
			var category_label := Label.new()
			category_label.text = category
			category_label.add_theme_font_size_override("font_size", 17)
			category_label.add_theme_color_override("font_color", Color(0.94, 0.81, 0.5, 1.0))
			rows.add_child(category_label)
			previous_category = category
		_add_binding_row(rows, definition)

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.text = "Select a binding, then press the replacement input."
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_color_override("font_color", Color(0.8, 0.86, 0.92, 1.0))
	layout.add_child(_status_label)


func _add_binding_row(parent: VBoxContainer, definition: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var action: StringName = definition["id"]
	row.add_child(_column_label(String(definition["label"]), 300.0))
	for device: StringName in [
		BindingSettingsScript.DEVICE_KEYBOARD_MOUSE,
		BindingSettingsScript.DEVICE_GAMEPAD,
	]:
		var button := _make_button(_binding_button_name(action, device), "Unbound")
		button.custom_minimum_size = Vector2(300, 34)
		button.pressed.connect(begin_capture.bind(action, device, button))
		row.add_child(button)
		_binding_buttons[_binding_key(action, device)] = button
		if _first_binding_button == null:
			_first_binding_button = button


func _make_button(node_name: String, text: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	return button


func _column_label(text: String, width: float) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(width, 30)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _refresh_binding_labels() -> void:
	var bindings = _current_bindings()
	if bindings == null:
		return
	for definition: Dictionary in BindingSettingsScript.action_definitions():
		var action: StringName = definition["id"]
		for device: StringName in [
			BindingSettingsScript.DEVICE_KEYBOARD_MOUSE,
			BindingSettingsScript.DEVICE_GAMEPAD,
		]:
			var button := _button_for(action, device)
			if button != null:
				button.text = bindings.binding_text(action, device)


func _current_bindings():
	if _settings_owner == null:
		return null
	return _settings_owner.get("input_bindings")


func _button_for(action: StringName, device: StringName) -> Button:
	return _binding_buttons.get(_binding_key(action, device)) as Button


func _action_label(action: StringName) -> String:
	for definition: Dictionary in BindingSettingsScript.action_definitions():
		if definition["id"] == action:
			return String(definition["label"])
	return String(action)


func _binding_key(action: StringName, device: StringName) -> String:
	return "%s:%s" % [action, device]


func _binding_button_name(action: StringName, device: StringName) -> String:
	return "%s%s" % [String(action).to_pascal_case(), String(device).to_pascal_case()]
