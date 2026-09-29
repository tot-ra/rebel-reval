class_name QuickAccessMenu
extends CanvasLayer

## Compact in-world action bar. Secondary actions live in the Esc settings menu;
## their existing handlers stay here so input bindings and tests share one path.

const STATUS_READY := "Choose an action"
const STATUS_SAVED := "Game saved"
const STATUS_SAVE_FAILED := "Save failed"
const STATUS_IRON_EQUIPPED := "Iron equipped"
const STATUS_IRON_CLEARED := "Iron cleared"
const PANEL_MARGIN := 24.0
const PANEL_HEIGHT := 76.0
const PANEL_WIDTH := 620.0
const ControlsOverlayScript := preload("res://scripts/ui/controls_overlay.gd")
## Click is context-sensitive: in first/third person it acts on what the character
## faces, and only the top-down camera treats it as a travel order. Full rules live
## in the Controls screen and docs/CONTROLS.md.
const HELP_TEXT := "1-5  SPELLS     E  INTERACT     ESC  MENU"

var _inventory_controller: InventoryController
var _journal_controller: JournalController
var _world_map_controller: WorldMapController
var _reflection_controller: ReflectionController
var _save_callback: Callable

var _inventory_button: Button
var _journal_button: Button
var _reflection_button: Button
var _world_map_button: Button
var _camera_button: Button
var _controls_button: Button
var _controls_overlay
var _technique_button: Button
var _magic_button: Button
var _save_button: Button
var _debug_button: Button
var _status_label: Label
var _debug_overlay: DebugOverlay


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
	_refresh_binding_hints()
	if (
		has_node("/root/UserSettings")
		and not UserSettings.input_bindings_changed.is_connected(_on_input_bindings_changed)
	):
		UserSettings.input_bindings_changed.connect(_on_input_bindings_changed)


func _exit_tree() -> void:
	if (
		has_node("/root/UserSettings")
		and UserSettings.input_bindings_changed.is_connected(_on_input_bindings_changed)
	):
		UserSettings.input_bindings_changed.disconnect(_on_input_bindings_changed)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"toggle_controls") or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	if _controls_overlay != null and _controls_overlay.is_open():
		_controls_overlay.close()
	else:
		_on_controls_pressed()


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.name = "QuickAccessPanel"
	# WHY: the surround stays click-through for world interaction; only buttons block input.
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left = -PANEL_WIDTH - PANEL_MARGIN
	panel.offset_top = -PANEL_HEIGHT - PANEL_MARGIN
	panel.offset_right = -PANEL_MARGIN
	panel.offset_bottom = -PANEL_MARGIN
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_theme_constant_override("separation", 4)
	margin.add_child(layout)

	var help := Label.new()
	help.name = "HelpLabel"
	help.text = HELP_TEXT
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help.add_theme_font_size_override("font_size", 10)
	help.add_theme_color_override("font_color", Color(0.77, 0.69, 0.52))
	layout.add_child(help)

	var actions := HBoxContainer.new()
	actions.name = "Actions"
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions.add_theme_constant_override("separation", 5)
	layout.add_child(actions)

	_inventory_button = _create_action_button("InventoryButton", "Inventory [I]", "Open inventory")
	_inventory_button.pressed.connect(_on_inventory_pressed)
	actions.add_child(_inventory_button)

	_journal_button = _create_action_button("JournalButton", "Journal [J]", "Open journal")
	_journal_button.pressed.connect(_on_journal_pressed)
	actions.add_child(_journal_button)

	_reflection_button = _create_action_button(
		"ReflectionButton", "Reflect", "Open the Hingepuu reflection when the soul-tree calls"
	)
	_reflection_button.pressed.connect(_on_reflection_pressed)
	actions.add_child(_reflection_button)

	# WHY: map mode must be mouse-reachable; M alone is not enough.
	_world_map_button = _create_action_button(
		"WorldMapButton", "Map [M]", "Open the local map and fast-travel options"
	)
	_world_map_button.pressed.connect(_on_world_map_pressed)
	actions.add_child(_world_map_button)

	_camera_button = _create_action_button(
		"CameraButton",
		"Camera [C]",
		"Cycle third-person, first-person, and top-down views; right-drag to look around"
	)
	_camera_button.pressed.connect(_on_camera_pressed)
	_camera_button.visible = false
	add_child(_camera_button)

	_controls_button = _create_action_button(
		"ControlsButton", "Controls [K]", "Remap keyboard, mouse, and gamepad controls"
	)
	_controls_button.pressed.connect(_on_controls_pressed)
	_controls_button.visible = false
	add_child(_controls_button)

	# WHY (P1-024e): forge techniques must be mouse-reachable; a hotkey alone is not enough.
	_technique_button = _create_action_button(
		"IronTechniqueButton", "Iron", "Equip or clear the Iron forge technique"
	)
	_technique_button.pressed.connect(_on_technique_pressed)
	actions.add_child(_technique_button)

	_magic_button = _create_action_button(
		"MagicCookbookButton", "Magic [R]", "Open the spell cookbook"
	)
	_magic_button.pressed.connect(_on_magic_pressed)
	actions.add_child(_magic_button)

	_save_button = _create_action_button("SaveButton", "Save game", "Save to the current slot")
	_save_button.pressed.connect(_on_save_pressed)
	_save_button.visible = false
	add_child(_save_button)

	_debug_button = _create_action_button(
		"DebugButton", "Debug", "Toggle debug overlay (FPS, audio, time controls)"
	)
	_debug_button.pressed.connect(_on_debug_pressed)
	_debug_button.visible = false
	add_child(_debug_button)

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.text = STATUS_READY
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", Color(0.91, 0.79, 0.57))
	layout.add_child(_status_label)

	_controls_overlay = ControlsOverlayScript.new()
	_controls_overlay.name = "ControlsOverlay"
	_controls_overlay.configure(UserSettings if has_node("/root/UserSettings") else null)
	_controls_overlay.closed.connect(_on_controls_closed)
	add_child(_controls_overlay)


func _create_action_button(node_name: String, label: String, tooltip: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = label
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size.y = 30.0
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color(0.94, 0.88, 0.72))
	button.add_theme_stylebox_override("normal", _button_style(Color(0.16, 0.18, 0.17, 0.94)))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.31, 0.27, 0.19, 0.98)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.38, 0.29, 0.17)))
	return button


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.07, 0.065, 0.92)
	style.border_color = Color(0.57, 0.45, 0.27, 0.85)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.48)
	style.shadow_size = 7
	return style


func _button_style(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color(0.42, 0.36, 0.25, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	return style


func trigger_secondary_action(action: StringName) -> void:
	# WHY: Esc presents secondary commands while their original handlers remain
	# the single route used by mouse, controller, and existing tests.
	match action:
		&"camera":
			_on_camera_pressed()
		&"controls":
			_on_controls_pressed()
		&"save":
			_on_save_pressed()
		&"debug":
			_on_debug_pressed()


func _resolve_dependencies() -> void:
	var owner_node := get_parent()
	if _inventory_controller == null:
		_inventory_controller = (
			owner_node.get_node_or_null("InventoryController") as InventoryController
		)
	if _journal_controller == null:
		_journal_controller = owner_node.get_node_or_null("JournalController") as JournalController
	if _world_map_controller == null:
		_world_map_controller = (
			owner_node.get_node_or_null("WorldMapController") as WorldMapController
		)
	if _reflection_controller == null:
		_reflection_controller = (
			owner_node.get_node_or_null("ReflectionController") as ReflectionController
		)
	if not _save_callback.is_valid() and has_node("/root/SessionState"):
		_save_callback = Callable(SessionState, "save_game")


func refresh_action_availability() -> void:
	_resolve_dependencies()
	_refresh_availability()
	_refresh_technique_button()


func _refresh_availability() -> void:
	if _inventory_button == null:
		return
	_inventory_button.disabled = _inventory_controller == null
	_journal_button.disabled = _journal_controller == null
	_reflection_button.disabled = (
		_reflection_controller == null or not _reflection_controller.is_available()
	)
	_world_map_button.disabled = _world_map_controller == null
	_camera_button.disabled = _find_map_view_runtime() == null
	_controls_button.disabled = not has_node("/root/UserSettings")
	_technique_button.disabled = not has_node("/root/SessionState")
	if _magic_button != null:
		_magic_button.disabled = _find_spellforge_controller() == null
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
	if _world_map_controller != null:
		_world_map_controller.close()
	if _reflection_controller != null:
		_reflection_controller.close()
	_inventory_controller.toggle()
	_status_label.text = "Inventory opened" if _inventory_controller.is_open() else STATUS_READY


func _on_journal_pressed() -> void:
	if _journal_controller == null:
		return
	if _inventory_controller != null:
		_inventory_controller.close()
	if _world_map_controller != null:
		_world_map_controller.close()
	if _reflection_controller != null:
		_reflection_controller.close()
	_journal_controller.toggle()
	_status_label.text = "Journal opened" if _journal_controller.is_open() else STATUS_READY


func _on_reflection_pressed() -> void:
	if _reflection_controller == null or not _reflection_controller.is_available():
		return
	if _inventory_controller != null:
		_inventory_controller.close()
	if _journal_controller != null:
		_journal_controller.close()
	if _world_map_controller != null:
		_world_map_controller.close()
	_reflection_controller.open()
	_refresh_availability()
	_status_label.text = "Hingepuu reflection opened"


func _on_world_map_pressed() -> void:
	if _world_map_controller == null:
		return
	if _reflection_controller != null:
		_reflection_controller.close()
	_world_map_controller.toggle()
	_status_label.text = "Map opened" if _world_map_controller.is_open() else STATUS_READY


func _on_camera_pressed() -> void:
	var runtime := _find_map_view_runtime()
	if runtime == null:
		return
	runtime.toggle_camera_view()
	_status_label.text = runtime.camera_mode_label()


func _on_controls_pressed() -> void:
	open_controls_overlay()


func open_controls_overlay() -> void:
	if _controls_overlay == null:
		return
	if _inventory_controller != null:
		_inventory_controller.close()
	if _journal_controller != null:
		_journal_controller.close()
	if _world_map_controller != null:
		_world_map_controller.close()
	_controls_overlay.open()
	_status_label.text = "Controls opened"


func _on_controls_closed() -> void:
	_status_label.text = STATUS_READY
	# The controls shortcut lives in Esc; the hidden legacy button cannot take focus.



func _on_input_bindings_changed(_bindings) -> void:
	_refresh_binding_hints()


func _refresh_binding_hints() -> void:
	if not has_node("/root/UserSettings") or UserSettings.input_bindings == null:
		return
	var bindings = UserSettings.input_bindings
	if _inventory_button != null:
		_inventory_button.text = (
			"Inventory [%s]" % bindings.binding_text(&"toggle_inventory", &"keyboard_mouse")
		)
	if _journal_button != null:
		_journal_button.text = (
			"Journal [%s]" % bindings.binding_text(&"toggle_journal", &"keyboard_mouse")
		)
	if _world_map_button != null:
		_world_map_button.text = (
			"Map [%s]" % bindings.binding_text(&"toggle_world_map", &"keyboard_mouse")
		)
	if _camera_button != null:
		_camera_button.text = (
			"Camera [%s]" % bindings.binding_text(&"toggle_camera_view", &"keyboard_mouse")
		)
	if _controls_button != null:
		_controls_button.text = (
			"Controls [%s]" % bindings.binding_text(&"toggle_controls", &"keyboard_mouse")
		)
	if _magic_button != null:
		_magic_button.text = (
			"Magic [%s]" % bindings.binding_text(&"toggle_spellforge", &"keyboard_mouse")
		)


func _on_magic_pressed() -> void:
	var controller := _find_spellforge_controller()
	if controller == null:
		return
	controller.toggle()
	_status_label.text = "Spell cookbook opened" if controller.is_open() else STATUS_READY


func _find_spellforge_controller() -> SpellforgeController:
	var owner_node := get_parent()
	if owner_node == null:
		return null
	return owner_node.get_node_or_null("SpellforgeController") as SpellforgeController


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


func _on_debug_pressed() -> void:
	if _debug_overlay == null:
		_debug_overlay = _find_debug_overlay()
	if _debug_overlay != null:
		_debug_overlay.toggle_visibility()
		_status_label.text = "Debug overlay opened" if _debug_overlay.visible else STATUS_READY


func _find_debug_overlay() -> DebugOverlay:
	var node := get_parent()
	while node != null:
		if node.has_node("DebugOverlay"):
			return node.get_node("DebugOverlay") as DebugOverlay
		node = node.get_parent()
	return null
