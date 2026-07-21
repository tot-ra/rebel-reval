class_name JournalOverlay
extends CanvasLayer

signal closed()

var _state: GameState
var _content_db: ContentDB

var _panel: PanelContainer
var _objective_title: Label
var _objective_body: Label
var _evidence_list: ItemList


func configure(state: GameState, content_db: ContentDB) -> void:
	_state = state
	_content_db = content_db
	if is_node_ready():
		_refresh()


func _ready() -> void:
	layer = 21
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_refresh()


func open() -> void:
	visible = true
	_refresh()


func close() -> void:
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


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
	_panel.custom_minimum_size = Vector2(520, 360)
	root.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	var header := Label.new()
	header.text = "Journal"
	header.add_theme_font_size_override("font_size", 22)
	layout.add_child(header)

	var objective_header := Label.new()
	objective_header.text = "Current objective"
	objective_header.add_theme_font_size_override("font_size", 16)
	layout.add_child(objective_header)

	_objective_title = Label.new()
	_objective_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_title.add_theme_font_size_override("font_size", 15)
	_objective_title.add_theme_color_override("font_color", Color(0.92, 0.9, 0.82, 1.0))
	layout.add_child(_objective_title)

	_objective_body = Label.new()
	_objective_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_body.add_theme_font_size_override("font_size", 14)
	layout.add_child(_objective_body)

	var evidence_header := Label.new()
	evidence_header.text = "Discovered evidence"
	evidence_header.add_theme_font_size_override("font_size", 16)
	layout.add_child(evidence_header)

	_evidence_list = ItemList.new()
	_evidence_list.custom_minimum_size = Vector2(0, 120)
	_evidence_list.fixed_icon_size = Vector2.ZERO
	layout.add_child(_evidence_list)

	var hint := Label.new()
	hint.text = "Press J or Esc to close"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.72, 0.72, 0.68, 1.0))
	layout.add_child(hint)


func _refresh() -> void:
	if _objective_title == null:
		return
	if _state == null or _content_db == null:
		_objective_title.text = "No active objective"
		_objective_body.text = ""
		_evidence_list.clear()
		return

	var snapshot := JournalModel.build_snapshot(_state, _content_db)
	var objectives: Array = snapshot.get("objectives", [])
	if objectives.is_empty():
		_objective_title.text = "No active objective"
		_objective_body.text = ""
	else:
		var primary: Dictionary = objectives[0]
		_objective_title.text = String(primary.get("quest_title", ""))
		_objective_body.text = String(primary.get("text", ""))

	_evidence_list.clear()
	var evidence: Array = snapshot.get("evidence", [])
	if evidence.is_empty():
		_evidence_list.add_item("No evidence recorded yet.")
	else:
		for entry in evidence:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			_evidence_list.add_item(String((entry as Dictionary).get("text", "")))
