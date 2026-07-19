class_name QuickAccessMenu
extends CanvasLayer

## Persistent entry point for player-facing systems. New global features should
## join this surface instead of relying on undocumented hotkeys.

const STATUS_READY := "Choose an action"
const STATUS_SAVED := "Game saved"
const STATUS_SAVE_FAILED := "Save failed"
const PANEL_MARGIN_RIGHT := 20.0
const MINIMAP_GAP := 12.0
const PANEL_HEIGHT := 96.0

var _inventory_controller: InventoryController
var _journal_controller: JournalController
var _save_callback: Callable

var _inventory_button: Button
var _journal_button: Button
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


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.name = "QuickAccessPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	var panel_top := MinimapHud.PANEL_MARGIN + MinimapHud.total_hud_height() + MINIMAP_GAP
	panel.offset_left = -506.0
	panel.offset_top = panel_top
	panel.offset_right = -PANEL_MARGIN_RIGHT
	panel.offset_bottom = panel_top + PANEL_HEIGHT
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	margin.add_child(layout)

	var header := Label.new()
	header.name = "Header"
	header.text = "Quick access"
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.92, 0.82, 0.56, 1.0))
	layout.add_child(header)

	var actions := HBoxContainer.new()
	actions.name = "Actions"
	actions.add_theme_constant_override("separation", 8)
	layout.add_child(actions)

	_inventory_button = _create_action_button("InventoryButton", "Inventory [I]", "Open inventory")
	_inventory_button.pressed.connect(_on_inventory_pressed)
	actions.add_child(_inventory_button)

	_journal_button = _create_action_button("JournalButton", "Journal [J]", "Open journal")
	_journal_button.pressed.connect(_on_journal_pressed)
	actions.add_child(_journal_button)

	_save_button = _create_action_button("SaveButton", "Save game", "Save to the current slot")
	_save_button.pressed.connect(_on_save_pressed)
	actions.add_child(_save_button)

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.text = STATUS_READY
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
	_save_button.disabled = not _save_callback.is_valid()


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


func _on_save_pressed() -> void:
	if not _save_callback.is_valid():
		_status_label.text = STATUS_SAVE_FAILED
		return
	_status_label.text = STATUS_SAVED if bool(_save_callback.call()) else STATUS_SAVE_FAILED
