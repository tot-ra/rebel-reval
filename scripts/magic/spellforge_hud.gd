class_name SpellforgeHud
extends CanvasLayer

## Text-and-shape spellforging surface. It deliberately avoids the retired legacy
## element sprites while remaining readable with keyboard, mouse, and gamepad.

signal element_requested(element_id: StringName)
signal remove_requested
signal cast_requested
signal close_requested

const PANEL_SIZE := Vector2(720.0, 620.0)

var _model: SpellforgeModel
var _element_row: HBoxContainer
var _sequence_label: Label
var _resource_label: Label
var _feedback_label: Label
var _cookbook: VBoxContainer
var _cast_button: Button
var _first_element_button: Button


func configure(model: SpellforgeModel) -> void:
	_model = model
	if is_node_ready():
		refresh()


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false


func open() -> void:
	refresh()
	visible = true
	add_to_group(&"modal_input_overlay")
	if _first_element_button != null:
		_first_element_button.grab_focus()
	elif _cast_button != null:
		_cast_button.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	remove_from_group(&"modal_input_overlay")
	close_requested.emit()


func is_open() -> bool:
	return visible


func refresh() -> void:
	if _model == null or _sequence_label == null:
		return
	_sequence_label.text = "Forged sequence: %s" % SpellforgeModel.sequence_text(
		_model.selected_sequence()
	)
	_feedback_label.text = _model.feedback_text()
	_resource_label.text = _resource_text()
	_rebuild_elements()
	_rebuild_cookbook()
	_cast_button.disabled = _model.selected_sequence().is_empty()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"spellforge_remove"):
		remove_requested.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"spellforge_cast"):
		cast_requested.emit()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var root := Control.new()
	root.name = "SpellforgeRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.018, 0.022, 0.032, 0.9)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "SpellforgePanel"
	panel.custom_minimum_size = PANEL_SIZE
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 24)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	var title := Label.new()
	title.text = "SPELLFORGE"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.96, 0.67, 0.3))
	layout.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Shape an ordered recipe from learned elements (maximum 3)."
	subtitle.add_theme_color_override("font_color", Color(0.75, 0.79, 0.84))
	layout.add_child(subtitle)

	_resource_label = Label.new()
	_resource_label.name = "ResourceLabel"
	layout.add_child(_resource_label)

	_sequence_label = Label.new()
	_sequence_label.name = "SequenceLabel"
	_sequence_label.add_theme_font_size_override("font_size", 20)
	layout.add_child(_sequence_label)

	_element_row = HBoxContainer.new()
	_element_row.name = "ElementButtons"
	_element_row.add_theme_constant_override("separation", 8)
	layout.add_child(_element_row)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	layout.add_child(action_row)

	var remove_button := Button.new()
	remove_button.name = "RemoveButton"
	remove_button.text = "Remove last"
	remove_button.pressed.connect(func() -> void: remove_requested.emit())
	action_row.add_child(remove_button)

	_cast_button = Button.new()
	_cast_button.name = "CastButton"
	_cast_button.text = "Cast forged spell"
	_cast_button.pressed.connect(func() -> void: cast_requested.emit())
	action_row.add_child(_cast_button)

	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "Close"
	close_button.pressed.connect(close)
	action_row.add_child(close_button)

	_feedback_label = Label.new()
	_feedback_label.name = "FeedbackLabel"
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback_label.add_theme_color_override("font_color", Color(0.98, 0.79, 0.44))
	layout.add_child(_feedback_label)

	var separator := HSeparator.new()
	layout.add_child(separator)

	var cookbook_title := Label.new()
	cookbook_title.text = "COOKBOOK"
	cookbook_title.add_theme_font_size_override("font_size", 18)
	layout.add_child(cookbook_title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 250.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)

	_cookbook = VBoxContainer.new()
	_cookbook.name = "CookbookRows"
	_cookbook.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cookbook.add_theme_constant_override("separation", 8)
	scroll.add_child(_cookbook)


func _rebuild_elements() -> void:
	for child in _element_row.get_children():
		child.queue_free()
	_first_element_button = null
	var learned := _model.learned_elements()
	for element_id in _model.catalog_elements():
		var button := Button.new()
		button.name = "%sElement" % SpellforgeModel.display_element(element_id).replace(" ", "")
		button.text = SpellforgeModel.display_element(element_id)
		button.disabled = not learned.has(element_id)
		button.tooltip_text = "Add learned element" if not button.disabled else "Element not learned"
		button.pressed.connect(_on_element_pressed.bind(element_id))
		_element_row.add_child(button)
		if _first_element_button == null and not button.disabled:
			_first_element_button = button
	if _element_row.get_child_count() == 0:
		var empty := Label.new()
		empty.text = "No authored elements are available. Magic remains optional."
		_element_row.add_child(empty)


func _rebuild_cookbook() -> void:
	for child in _cookbook.get_children():
		child.queue_free()
	for row in _model.cookbook_rows():
		var entry := Label.new()
		entry.name = "%sRecipe" % String(row["name"]).replace(" ", "")
		entry.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		entry.text = (
			"%s - %s - %s\n%s"
			% [
				"LEARNED" if bool(row["learned"]) else "LOCKED",
				String(row["name"]),
				String(row["sequence_text"]),
				String(row["summary"]),
			]
		)
		entry.add_theme_color_override(
			"font_color", Color(0.84, 0.9, 0.72) if bool(row["learned"]) else Color(0.5, 0.52, 0.56)
		)
		_cookbook.add_child(entry)


func _resource_text() -> String:
	if _model == null:
		return "Willpower: unavailable"
	return "Willpower: %d" % _model.willpower()


func _on_element_pressed(element_id: StringName) -> void:
	element_requested.emit(element_id)
