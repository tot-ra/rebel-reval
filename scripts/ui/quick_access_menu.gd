class_name QuickAccessMenu
extends CanvasLayer

## Persistent bottom entry point for player-facing systems plus passive shortcut
## hints. New global features should join this surface instead of undocumented hotkeys.

const STATUS_READY := "Choose an action"
const STATUS_SAVED := "Game saved"
const STATUS_SAVE_FAILED := "Save failed"
const STATUS_IRON_EQUIPPED := "Iron equipped"
const STATUS_IRON_CLEARED := "Iron cleared"
const PANEL_MARGIN := 24.0
const PANEL_HEIGHT := 118.0
const PANEL_WIDTH := 860.0
const HELP_TEXT := (
	"WASD or arrows - move | Click - travel | E - interact | "
	+ "C - camera | N - map | I - inventory | J - journal | Iron - technique"
)

var _inventory_controller: InventoryController
var _journal_controller: JournalController
var _save_callback: Callable

var _inventory_button: Button
var _journal_button: Button
var _camera_button: Button
var _technique_button: Button
var _save_button: Button
var _status_label: Label


func configure(
	inventory_controller: InventoryController,
	journal_controller: JournalController,
	save_callback: Callable = Callable()
) -> void:
	_inventory_controller = inventory_controller
	_journal_controller = journal_controller
	_save_callback = save_callback
	_refresh_availability()


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_resolve_dependencies()
	_refresh_availability()
	_refresh_technique_button()


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.name = "QuickAccessPanel"
	# Ignore on the panel so click-to-move works around the buttons; buttons still STOP.
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left = -PANEL_WIDTH
	panel.offset_top = -PANEL_HEIGHT - PANEL_MARGIN
	panel.offset_right = -PANEL_MARGIN
	panel.offset_bottom = -PANEL_MARGIN
	add_child(panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_theme_constant_override("separation", 6)
	margin.add_child(layout)

	var header := Label.new()
	header.name = "Header"
	header.text = "Quick access"
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.92, 0.82, 0.56, 1.0))
	layout.add_child(header)

	# WHY: keep mouse-transparent help so click-to-move still works beside buttons.
	var help := Label.new()
	help.name = "HelpLabel"
	help.text = HELP_TEXT
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_font_size_override("font_size", 12)
	help.add_theme_color_override("font_color", Color(0.82, 0.86, 0.9, 0.92))
	layout.add_child(help)

	var actions := HBoxContainer.new()
	actions.name = "Actions"
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions.add_theme_constant_override("separation", 8)
	layout.add_child(actions)

	_inventory_button = _create_action_button("InventoryButton", "Inventory [I]", "Open inventory")
	_inventory_button.pressed.connect(_on_inventory_pressed)
	actions.add_child(_inventory_button)

	_journal_button = _create_action_button("JournalButton", "Journal [J]", "Open journal")
	_journal_button.pressed.connect(_on_journal_pressed)
	actions.add_child(_journal_button)

	_camera_button = _create_action_button("CameraButton", "Camera [C]", "Toggle first-person view")
	_camera_button.pressed.connect(_on_camera_pressed)
	actions.add_child(_camera_button)

	# WHY (P1-024e): forge techniques must be mouse-reachable; a hotkey alone is not enough.
	_technique_button = _create_action_button(
		"IronTechniqueButton",
		"Iron",
		"Equip or clear the Iron forge technique"
	)
	_technique_button.pressed.connect(_on_technique_pressed)
	actions.add_child(_technique_button)

	_save_button = _create_action_button("SaveButton", "Save game", "Save to the current slot")
	_save_button.pressed.connect(_on_save_pressed)
	actions.add_child(_save_button)

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.text = STATUS_READY
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.72, 0.75, 0.78, 1.0))
	layout.add_child(_status_label)


func _create_action_button(node_name: String, label: String, tooltip: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = label
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_ALL
	return button


func _resolve_dependencies() -> void:
	var owner_node := get_parent()
	if _inventory_controller == null:
		_inventory_controller = owner_node.get_node_or_null("InventoryController") as InventoryController
	if _journal_controller == null:
		_journal_controller = owner_node.get_node_or_null("JournalController") as JournalController
	if not _save_callback.is_valid() and has_node("/root/SessionState"):
		_save_callback = Callable(SessionState, "save_game")


func _refresh_availability() -> void:
	if _inventory_button == null:
		return
	_inventory_button.disabled = _inventory_controller == null
	_journal_button.disabled = _journal_controller == null
	_camera_button.disabled = _find_map_view_runtime() == null
	_technique_button.disabled = not has_node("/root/SessionState")
	_save_button.disabled = not _save_callback.is_valid()


func _refresh_technique_button() -> void:
	if _technique_button == null:
		return
	var equipped := _equipped_technique()
	if equipped == ForgeTechnique.ID_IRON:
		_technique_button.text = "Iron: on"
	else:
		_technique_button.text = "Iron"


func _equipped_technique() -> StringName:
	if not has_node("/root/SessionState"):
		return &""
	return SessionState.state.equipped_forge_technique()


func _on_inventory_pressed() -> void:
	if _inventory_controller == null:
		return
	if _journal_controller != null:
		_journal_controller.close()
	_inventory_controller.toggle()
	_status_label.text = "Inventory opened" if _inventory_controller.is_open() else STATUS_READY


func _on_journal_pressed() -> void:
	if _journal_controller == null:
		return
	if _inventory_controller != null:
		_inventory_controller.close()
	_journal_controller.toggle()
	_status_label.text = "Journal opened" if _journal_controller.is_open() else STATUS_READY


func _on_camera_pressed() -> void:
	var runtime := _find_map_view_runtime()
	if runtime == null:
		return
	runtime.toggle_camera_view()
	_status_label.text = "First-person view" if runtime.is_first_person() else STATUS_READY


func _on_technique_pressed() -> void:
	if not has_node("/root/SessionState"):
		return
	var state: GameState = SessionState.state
	if state.equipped_forge_technique() == ForgeTechnique.ID_IRON:
		state.set_equipped_forge_technique(&"")
		_status_label.text = STATUS_IRON_CLEARED
	else:
		# WHY: clear any other allowlisted technique first so Iron is the sole equip.
		state.set_equipped_forge_technique(ForgeTechnique.ID_IRON)
		_status_label.text = STATUS_IRON_EQUIPPED
	_refresh_technique_button()


func _find_map_view_runtime() -> MapViewRuntime:
	var node: Node = get_parent()
	while node != null:
		if node.has_node("MapViewRuntime"):
			return node.get_node("MapViewRuntime") as MapViewRuntime
		node = node.get_parent()
	return null


func _on_save_pressed() -> void:
	if not _save_callback.is_valid():
		_status_label.text = STATUS_SAVE_FAILED
		return
	_status_label.text = STATUS_SAVED if bool(_save_callback.call()) else STATUS_SAVE_FAILED
