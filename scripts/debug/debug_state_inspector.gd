class_name DebugStateInspector
extends CanvasLayer

## Developer overlay for deterministic state reset and slice phase/branch jumps.
## Toggle with F10 in debug builds.

signal preset_applied(preset_id: String)

const PresetsScript := preload("res://scripts/debug/debug_state_presets.gd")

var _presets
var _apply_callback: Callable
var _panel: PanelContainer
var _status_label: Label
var _preset_list: ItemList
var _description_label: Label
var _apply_button: Button
var _visible := false


func configure(presets, apply_callback: Callable) -> void:
	_presets = presets
	_apply_callback = apply_callback
	_refresh_preset_list()


func _ready() -> void:
	layer = 90
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	set_process_unhandled_input(true)


func toggle() -> void:
	_visible = not _visible
	visible = _visible
	if _visible:
		_refresh_status()
		_preset_list.grab_focus()


func is_open() -> bool:
	return _visible


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(520, 560)
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin.add_child(_panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	_panel.add_child(root)

	var title := Label.new()
	title.text = "Debug State Inspector (P1-009)"
	title.add_theme_color_override("font_color", Color(0.92, 0.78, 0.42, 1.0))
	root.add_child(title)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(480, 48)
	root.add_child(_status_label)

	_preset_list = ItemList.new()
	_preset_list.custom_minimum_size = Vector2(480, 320)
	_preset_list.item_selected.connect(_on_preset_selected)
	root.add_child(_preset_list)

	_description_label = Label.new()
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.custom_minimum_size = Vector2(480, 56)
	root.add_child(_description_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	root.add_child(buttons)

	_apply_button = Button.new()
	_apply_button.text = "Apply preset"
	_apply_button.pressed.connect(_on_apply_pressed)
	buttons.add_child(_apply_button)

	var close_button := Button.new()
	close_button.text = "Close (F10)"
	close_button.pressed.connect(toggle)
	buttons.add_child(close_button)


func _refresh_preset_list() -> void:
	if _preset_list == null or _presets == null:
		return
	_preset_list.clear()
	for preset_id in _presets.get_preset_ids():
		var preset: Dictionary = _presets.get_preset(preset_id)
		var category := String(preset.get("category", "misc"))
		_preset_list.add_item("[%s] %s" % [category, String(preset.get("label", preset_id))])
		_preset_list.set_item_metadata(_preset_list.item_count - 1, preset_id)


func _refresh_status() -> void:
	if _status_label == null:
		return
	if not has_node("/root/SessionState"):
		_status_label.text = "SessionState unavailable."
		return
	var state: GameState = SessionState.state
	var payload: Dictionary = state.save_payload()
	_status_label.text = (
		"Phase: %s | Quests: %d | Flags: %d | Facts: %d | Pressures: S%d O%d C%d"
		% [
			String(state.get_phase()),
			(payload.get("quest_states", {}) as Dictionary).size(),
			(payload.get("flags", {}) as Dictionary).size(),
			(payload.get("facts", {}) as Dictionary).size(),
			state.get_pressure(GameState.PRESSURE_SUSPICION),
			state.get_pressure(GameState.PRESSURE_SOLIDARITY),
			state.get_pressure(GameState.PRESSURE_SCARCITY),
		]
	)


func _on_preset_selected(index: int) -> void:
	if _presets == null or _description_label == null:
		return
	var preset_id := String(_preset_list.get_item_metadata(index))
	var preset: Dictionary = _presets.get_preset(preset_id)
	_description_label.text = String(preset.get("description", preset_id))


func _on_apply_pressed() -> void:
	if _presets == null or _preset_list.get_selected_items().is_empty():
		return
	var index: int = _preset_list.get_selected_items()[0]
	var preset_id := String(_preset_list.get_item_metadata(index))
	if _apply_callback.is_valid():
		_apply_callback.call(preset_id)
	preset_applied.emit(preset_id)
	_refresh_status()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed(&"debug_toggle_inspector"):
		toggle()
		get_viewport().set_input_as_handled()
