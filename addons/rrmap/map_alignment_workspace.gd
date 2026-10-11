@tool
class_name MapAlignmentWorkspace
extends VBoxContainer

## Main-screen RRMap workspace with Edit and Align modes.
## Source files remain authoritative; layer offsets/backgrounds are temporary.

const DEFAULT_EXPORT_DIR := "res://build/map_alignment"
const MODE_EDIT := &"edit"
const MODE_ALIGN := &"align"
const TOOL_TERRAIN := 0
const TOOL_BUILDING := 1
const TOOL_PROP := 2
const TOOL_SELECT := 3

var _source_list: ItemList
var _sidebar_scroll: ScrollContainer
var _root_picker: OptionButton
var _layer_picker: OptionButton
var _visible_toggle: CheckButton
var _opacity_slider: HSlider
var _opacity_label: Label
var _status: Label
var _canvas: MapAlignmentCanvas
var _blink_timer: Timer
var _export_dialog: FileDialog
var _background_dialog: FileDialog
var _background_path_label: Label
var _background_visible_toggle: CheckButton
var _background_move_toggle: CheckButton
var _background_opacity_slider: HSlider
var _background_opacity_label: Label
var _background_scale_spin: SpinBox
var _background_x_spin: SpinBox
var _background_y_spin: SpinBox
var _editor_model: MapAlignmentEditorModel
var _edit_mode_toggle: CheckButton
var _save_editor_button: Button
var _revert_editor_button: Button
var _editor_tool_buttons: Array[Button] = []
var _editor_terrain_picker: OptionButton
var _editor_building_picker: OptionButton
var _editor_prop_filter: LineEdit
var _editor_prop_picker: OptionButton
var _editor_width_spin: SpinBox
var _editor_height_spin: SpinBox
var _editor_map_width_spin: SpinBox
var _editor_map_height_spin: SpinBox
var _editor_elevation_spin: SpinBox
var _editor_status: Label
var _mode_edit_button: Button
var _mode_align_button: Button
var _align_toolbar: HBoxContainer
var _edit_toolbar: HBoxContainer
var _align_panel: VBoxContainer
var _edit_panel: VBoxContainer
var _tool_options: VBoxContainer
var _terrain_options: VBoxContainer
var _building_options: VBoxContainer
var _prop_options: VBoxContainer
var _map_settings_panel: VBoxContainer
var _background_panel: VBoxContainer
var _advanced_toggle: CheckButton
var _blink_enabled := false
var _blink_visible := true
var _workspace_mode: StringName = MODE_EDIT
var _editor_tool := TOOL_SELECT
var _show_advanced := false
var _map_paths: Array[String] = []
var _loaded_paths: Array[String] = []
## map_id StringName -> source path; avoids re-parsing every lookup.
var _path_by_map_id: Dictionary = {}
var _definitions: Array[MapDefinition] = []
var _seams: Array[Dictionary] = []
var _load_issues: PackedStringArray = []
var _skipped_map_names: Array[String] = []
var _all_prop_kinds: Array[String] = []

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	set_process_unhandled_key_input(true)
	for kind in MapTypes.ALL_PROP_KINDS:
		_all_prop_kinds.append(String(kind))
	_all_prop_kinds.sort()
	_build_ui()
	_refresh_maps()
	_apply_workspace_mode()

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_theme_constant_override("separation", 4)

	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 6)
	add_child(mode_row)
	var mode_label := Label.new()
	mode_label.text = "Mode"
	mode_row.add_child(mode_label)
	var mode_group := ButtonGroup.new()
	_mode_edit_button = Button.new()
	_mode_edit_button.text = "Edit map"
	_mode_edit_button.toggle_mode = true
	_mode_edit_button.button_group = mode_group
	_mode_edit_button.button_pressed = true
	_mode_edit_button.tooltip_text = "Place and move terrain, buildings, and props on one map"
	_mode_edit_button.pressed.connect(func() -> void: _set_workspace_mode(MODE_EDIT))
	mode_row.add_child(_mode_edit_button)
	_mode_align_button = Button.new()
	_mode_align_button.text = "Align maps"
	_mode_align_button.toggle_mode = true
	_mode_align_button.button_group = mode_group
	_mode_align_button.tooltip_text = (
		"Load neighbors, inspect seams, nudge layers, and use a " +
		"reference background"
	)
	_mode_align_button.pressed.connect(func() -> void: _set_workspace_mode(MODE_ALIGN))
	mode_row.add_child(_mode_align_button)
	var mode_spacer := Control.new()
	mode_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_row.add_child(mode_spacer)
	_save_editor_button = Button.new()
	_save_editor_button.text = "Save map"
	_save_editor_button.tooltip_text = "Write the editable draft back to its .rrmap source"
	_save_editor_button.pressed.connect(_save_editor_map)
	_save_editor_button.disabled = true
	mode_row.add_child(_save_editor_button)
	_revert_editor_button = Button.new()
	_revert_editor_button.text = "Revert"
	_revert_editor_button.pressed.connect(_revert_editor_map)
	_revert_editor_button.disabled = true
	mode_row.add_child(_revert_editor_button)

	_edit_toolbar = HBoxContainer.new()
	_edit_toolbar.add_theme_constant_override("separation", 6)
	add_child(_edit_toolbar)
	_add_button(_edit_toolbar, "Open selected", _edit_selected_map,
		"Load the highlighted .rrmap and start editing it")
	_add_button(_edit_toolbar, "Fit", func() -> void: _canvas.request_fit())
	_add_button(_edit_toolbar, "Export PNG", _choose_export_path)

	_align_toolbar = HBoxContainer.new()
	_align_toolbar.add_theme_constant_override("separation", 6)
	add_child(_align_toolbar)
	_add_button(_align_toolbar, "Load selected", _load_selected_maps,
		"Load every map selected in the source list")
	_add_button(_align_toolbar, "Load all maps", _load_all_maps,
		"Load and arrange every .rrmap source")
	_add_button(_align_toolbar, "Refresh files", _refresh_maps)
	_add_button(_align_toolbar, "Auto-layout", _auto_layout,
		"Rebuild the connected map graph from reciprocal transitions")
	_add_button(_align_toolbar, "Fit all", func() -> void: _canvas.request_fit())
	_add_button(_align_toolbar, "←", func() -> void: _canvas.nudge_selected(Vector2i.LEFT))
	_add_button(_align_toolbar, "↑", func() -> void: _canvas.nudge_selected(Vector2i.UP))
	_add_button(_align_toolbar, "↓", func() -> void: _canvas.nudge_selected(Vector2i.DOWN))
	_add_button(_align_toolbar, "→", func() -> void: _canvas.nudge_selected(Vector2i.RIGHT))
	_add_button(_align_toolbar, "Add background", _choose_background,
		"Choose a reference image beneath every map")
	_add_button(_align_toolbar, "Export PNG", _choose_export_path)

	var split := HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 280
	add_child(split)

	var sidebar_scroll := ScrollContainer.new()
	_sidebar_scroll = sidebar_scroll
	sidebar_scroll.custom_minimum_size.x = 260.0
	sidebar_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(sidebar_scroll)
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 260.0
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar.add_theme_constant_override("separation", 6)
	sidebar_scroll.add_child(sidebar)

	var source_title := Label.new()
	source_title.text = "Map sources"
	sidebar.add_child(source_title)
	_source_list = ItemList.new()
	_source_list.select_mode = ItemList.SELECT_MULTI
	_source_list.custom_minimum_size.y = 140.0
	_source_list.item_activated.connect(_open_source_from_list)
	sidebar.add_child(_source_list)
	var source_hint := Label.new()
	source_hint.text = "Double-click to edit. Cmd/Ctrl or Shift multi-selects for Align."
	source_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sidebar.add_child(source_hint)

	_edit_panel = VBoxContainer.new()
	_edit_panel.add_theme_constant_override("separation", 6)
	sidebar.add_child(_edit_panel)
	_build_editor_controls(_edit_panel)

	_align_panel = VBoxContainer.new()
	_align_panel.add_theme_constant_override("separation", 6)
	sidebar.add_child(_align_panel)
	_build_align_controls(_align_panel)

	_advanced_toggle = CheckButton.new()
	_advanced_toggle.text = "Show advanced"
	_advanced_toggle.tooltip_text = "Map size, ground height, reference background, and blink"
	_advanced_toggle.toggled.connect(func(value: bool) -> void:
		_show_advanced = value
		_apply_workspace_mode()
	)
	sidebar.add_child(_advanced_toggle)

	_map_settings_panel = VBoxContainer.new()
	_map_settings_panel.add_theme_constant_override("separation", 4)
	sidebar.add_child(_map_settings_panel)
	_build_map_settings(_map_settings_panel)

	_background_panel = VBoxContainer.new()
	_background_panel.add_theme_constant_override("separation", 4)
	sidebar.add_child(_background_panel)
	_build_background_controls(_background_panel)

	var display_row := HBoxContainer.new()
	sidebar.add_child(display_row)
	var grid_toggle := CheckButton.new()
	grid_toggle.text = "Grid"
	grid_toggle.button_pressed = true
	grid_toggle.toggled.connect(func(value: bool) -> void:
		_canvas.show_grid = value
		_canvas.queue_redraw()
	)
	display_row.add_child(grid_toggle)
	var feature_toggle := CheckButton.new()
	feature_toggle.text = "Features"
	feature_toggle.button_pressed = true
	feature_toggle.tooltip_text = "Walls, buildings, props, and transitions"
	feature_toggle.toggled.connect(func(value: bool) -> void:
		_canvas.show_features = value
		_canvas.queue_redraw()
	)
	display_row.add_child(feature_toggle)
	var id_toggle := CheckButton.new()
	id_toggle.text = "IDs"
	id_toggle.toggled.connect(func(value: bool) -> void:
		_canvas.show_ids = value
		_canvas.queue_redraw()
	)
	display_row.add_child(id_toggle)

	_canvas = MapAlignmentCanvas.new()
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.custom_minimum_size = Vector2(480, 300)
	_canvas.view_changed.connect(_update_status)
	_canvas.selected_layer_changed.connect(_on_canvas_layer_selected)
	_canvas.edit_cell_clicked.connect(_on_editor_cell_clicked)
	_canvas.background_changed.connect(_sync_background_controls)
	split.add_child(_canvas)

	_status = Label.new()
	_status.text = "Open a map (double-click) to edit, or switch to Align maps."
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.y = 38.0
	add_child(_status)

	_blink_timer = Timer.new()
	_blink_timer.wait_time = 0.55
	_blink_timer.timeout.connect(_blink_tick)
	add_child(_blink_timer)
	_export_dialog = FileDialog.new()
	_export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_export_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_export_dialog.add_filter("*.png", "PNG image")
	_export_dialog.file_selected.connect(_export_png)
	add_child(_export_dialog)
	_background_dialog = FileDialog.new()
	_background_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_background_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_background_dialog.add_filter("*.png,*.jpg,*.jpeg,*.webp,*.svg,*.bmp", "Image files")
	_background_dialog.file_selected.connect(_load_background)
	add_child(_background_dialog)
	_sync_background_controls()

func _add_button(parent: Control, text: String, action: Callable, tooltip := "") -> void:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.pressed.connect(action)
	parent.add_child(button)

func _build_align_controls(sidebar: VBoxContainer) -> void:
	var root_label := Label.new()
	root_label.text = "Layout root"
	sidebar.add_child(root_label)
	_root_picker = OptionButton.new()
	_root_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar.add_child(_root_picker)

	var layer_label := Label.new()
	layer_label.text = "Selected layer"
	sidebar.add_child(layer_label)
	_layer_picker = OptionButton.new()
	_layer_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_layer_picker.item_selected.connect(_on_layer_picked)
	sidebar.add_child(_layer_picker)
	_visible_toggle = CheckButton.new()
	_visible_toggle.text = "Layer visible"
	_visible_toggle.button_pressed = true
	_visible_toggle.toggled.connect(_set_selected_visible)
	sidebar.add_child(_visible_toggle)

	var opacity_row := HBoxContainer.new()
	sidebar.add_child(opacity_row)
	var opacity_text := Label.new()
	opacity_text.text = "Opacity"
	opacity_row.add_child(opacity_text)
	_opacity_slider = HSlider.new()
	_opacity_slider.min_value = 0.05
	_opacity_slider.max_value = 1.0
	_opacity_slider.step = 0.05
	_opacity_slider.value = 1.0
	_opacity_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_opacity_slider.value_changed.connect(_set_opacity)
	opacity_row.add_child(_opacity_slider)
	_opacity_label = Label.new()
	_opacity_label.text = "100%"
	opacity_row.add_child(_opacity_label)

	var blink_toggle := CheckButton.new()
	blink_toggle.text = "Blink selected layer"
	blink_toggle.toggled.connect(_set_blink)
	sidebar.add_child(blink_toggle)

func _build_background_controls(sidebar: VBoxContainer) -> void:
	var separator := HSeparator.new()
	sidebar.add_child(separator)
	var title := Label.new()
	title.text = "Reference background"
	sidebar.add_child(title)
	_background_path_label = Label.new()
	_background_path_label.text = "No image selected"
	_background_path_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_background_path_label.tooltip_text = "No image selected"
	sidebar.add_child(_background_path_label)

	var actions := HBoxContainer.new()
	sidebar.add_child(actions)
	_add_button(actions, "Choose image", _choose_background)
	_add_button(actions, "Clear", _clear_background)

	_background_visible_toggle = CheckButton.new()
	_background_visible_toggle.text = "Background visible"
	_background_visible_toggle.button_pressed = true
	_background_visible_toggle.toggled.connect(func(value: bool) -> void:
		_canvas.set_background_visible(value)
	)
	sidebar.add_child(_background_visible_toggle)
	_background_move_toggle = CheckButton.new()
	_background_move_toggle.text = "Move background"
	_background_move_toggle.tooltip_text = (
		"Left-drag or use arrows to move the background; " +
		"middle-drag still pans"
	)
	_background_move_toggle.toggled.connect(func(value: bool) -> void:
		_canvas.edit_background = value
		_canvas.queue_redraw()
		_update_status()
	)
	sidebar.add_child(_background_move_toggle)

	var opacity_row := HBoxContainer.new()
	sidebar.add_child(opacity_row)
	var opacity_text := Label.new()
	opacity_text.text = "BG opacity"
	opacity_row.add_child(opacity_text)
	_background_opacity_slider = HSlider.new()
	_background_opacity_slider.min_value = 0.0
	_background_opacity_slider.max_value = 1.0
	_background_opacity_slider.step = 0.05
	_background_opacity_slider.value = 0.55
	_background_opacity_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_background_opacity_slider.value_changed.connect(func(value: float) -> void:
		_canvas.set_background_opacity(value)
		_background_opacity_label.text = "%d%%" % roundi(value * 100.0)
	)
	opacity_row.add_child(_background_opacity_slider)
	_background_opacity_label = Label.new()
	_background_opacity_label.text = "55%"
	opacity_row.add_child(_background_opacity_label)

	var transform_grid := GridContainer.new()
	transform_grid.columns = 2
	sidebar.add_child(transform_grid)
	_background_scale_spin = _add_background_spin(transform_grid, "Scale", 0.01, 100.0, 0.01, 1.0)
	_background_scale_spin.value_changed.connect(func(value: float) -> void:
		_canvas.set_background_scale(value)
	)
	_background_x_spin = _add_background_spin(transform_grid, "X", -1000000.0, 1000000.0, 1.0, 0.0)
	_background_x_spin.value_changed.connect(func(value: float) -> void:
		_canvas.set_background_offset(Vector2(value, _background_y_spin.value))
	)
	_background_y_spin = _add_background_spin(transform_grid, "Y", -1000000.0, 1000000.0, 1.0, 0.0)
	_background_y_spin.value_changed.connect(func(value: float) -> void:
		_canvas.set_background_offset(Vector2(_background_x_spin.value, value))
	)

func _add_background_spin(
	parent: GridContainer,
	label_text: String,
	minimum: float,
	maximum: float,
	step: float,
	initial_value: float
) -> SpinBox:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.value = initial_value
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.allow_greater = true
	spin.allow_lesser = true
	parent.add_child(spin)
	return spin

func _build_editor_controls(sidebar: VBoxContainer) -> void:
	var title := Label.new()
	title.text = "Tools (1-4)"
	sidebar.add_child(title)

	# Keep a hidden toggle so open_source / FileSystem open still enable edit clicks.
	_edit_mode_toggle = CheckButton.new()
	_edit_mode_toggle.visible = false
	_edit_mode_toggle.text = "Edit selected map"
	_edit_mode_toggle.toggled.connect(_set_edit_mode)
	sidebar.add_child(_edit_mode_toggle)

	var tool_row := HFlowContainer.new()
	tool_row.add_theme_constant_override("h_separation", 4)
	tool_row.add_theme_constant_override("v_separation", 4)
	sidebar.add_child(tool_row)
	_editor_tool_buttons.clear()
	var tool_group := ButtonGroup.new()
	var tool_names := ["Terrain", "Building", "Prop", "Select"]
	var tool_tips := [
		"Paint one terrain cell (1)",
		"Place a building footprint (2)",
		"Place a prop from the list (3)",
		"Select and arrow-key move objects; right-click removes (4)",
	]
	for index in tool_names.size():
		var button := Button.new()
		button.text = tool_names[index]
		button.toggle_mode = true
		button.button_group = tool_group
		button.tooltip_text = tool_tips[index]
		button.button_pressed = index == TOOL_SELECT
		var tool_index := index
		button.pressed.connect(func() -> void: _set_editor_tool(tool_index))
		tool_row.add_child(button)
		_editor_tool_buttons.append(button)

	_tool_options = VBoxContainer.new()
	_tool_options.add_theme_constant_override("separation", 4)
	sidebar.add_child(_tool_options)

	_terrain_options = VBoxContainer.new()
	_tool_options.add_child(_terrain_options)
	_editor_terrain_picker = OptionButton.new()
	for terrain in MapTypes.ALL_TERRAINS:
		_editor_terrain_picker.add_item(String(terrain))
	_terrain_options.add_child(_editor_terrain_picker)

	_building_options = VBoxContainer.new()
	_building_options.add_theme_constant_override("separation", 4)
	_tool_options.add_child(_building_options)
	_editor_building_picker = OptionButton.new()
	for kind in MapTypes.ALL_BUILDING_KINDS:
		_editor_building_picker.add_item(String(kind))
	_editor_building_picker.selected = 0
	_building_options.add_child(_editor_building_picker)
	var footprint_label := Label.new()
	footprint_label.text = "Footprint (cells)"
	_building_options.add_child(footprint_label)
	var footprint_grid := GridContainer.new()
	footprint_grid.columns = 2
	_building_options.add_child(footprint_grid)
	_editor_width_spin = _add_editor_spin(footprint_grid, "W", 1.0, 64.0, 1.0, 3.0)
	_editor_height_spin = _add_editor_spin(footprint_grid, "H", 1.0, 64.0, 1.0, 3.0)

	_prop_options = VBoxContainer.new()
	_prop_options.add_theme_constant_override("separation", 4)
	_tool_options.add_child(_prop_options)
	_editor_prop_filter = LineEdit.new()
	_editor_prop_filter.placeholder_text = "Filter props..."
	_editor_prop_filter.tooltip_text = "Type part of a prop kind to narrow the list"
	_editor_prop_filter.text_changed.connect(_on_prop_filter_changed)
	_prop_options.add_child(_editor_prop_filter)
	_editor_prop_picker = OptionButton.new()
	_editor_prop_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prop_options.add_child(_editor_prop_picker)
	_rebuild_prop_picker("")

	var click_hint := Label.new()
	click_hint.text = "Left click uses the tool. Right click removes the top primitive."
	click_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sidebar.add_child(click_hint)

	_editor_status = Label.new()
	_editor_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_editor_status.text = "Open a map to start editing."
	sidebar.add_child(_editor_status)

func _build_map_settings(sidebar: VBoxContainer) -> void:
	var separator := HSeparator.new()
	sidebar.add_child(separator)
	var size_label := Label.new()
	size_label.text = "Map size (cells)"
	sidebar.add_child(size_label)
	var size_grid := GridContainer.new()
	size_grid.columns = 2
	sidebar.add_child(size_grid)
	_editor_map_width_spin = _add_editor_spin(size_grid, "W", 1.0, 2048.0, 1.0, 1.0)
	_editor_map_height_spin = _add_editor_spin(size_grid, "H", 1.0, 2048.0, 1.0, 1.0)
	_editor_map_width_spin.value_changed.connect(_resize_editor_map)
	_editor_map_height_spin.value_changed.connect(_resize_editor_map)
	var elevation_row := HBoxContainer.new()
	sidebar.add_child(elevation_row)
	var elevation_label := Label.new()
	elevation_label.text = "Height"
	elevation_row.add_child(elevation_label)
	_editor_elevation_spin = SpinBox.new()
	_editor_elevation_spin.min_value = 0.0
	_editor_elevation_spin.max_value = 8.0
	_editor_elevation_spin.step = 0.1
	_editor_elevation_spin.value_changed.connect(_set_editor_elevation)
	_editor_elevation_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	elevation_row.add_child(_editor_elevation_spin)

func _add_editor_spin(parent: GridContainer, label_text: String, minimum: float, maximum: float,
	step: float, initial_value: float) -> SpinBox:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.value = initial_value
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(spin)
	return spin

func _set_workspace_mode(mode: StringName) -> void:
	_workspace_mode = mode
	_apply_workspace_mode()
	if mode == MODE_EDIT:
		_edit_mode_toggle.set_pressed_no_signal(true)
		_set_edit_mode(true)
	else:
		# Align mode still allows inspecting the canvas; disable click-to-edit.
		_edit_mode_toggle.set_pressed_no_signal(false)
		_set_edit_mode(false)

func _apply_workspace_mode() -> void:
	var editing := _workspace_mode == MODE_EDIT
	_mode_edit_button.set_pressed_no_signal(editing)
	_mode_align_button.set_pressed_no_signal(not editing)
	_edit_toolbar.visible = editing
	_align_toolbar.visible = not editing
	_edit_panel.visible = editing
	_align_panel.visible = not editing
	_map_settings_panel.visible = editing and _show_advanced
	_background_panel.visible = (not editing) and _show_advanced
	_save_editor_button.visible = editing
	_revert_editor_button.visible = editing
	_sync_tool_options()
	_update_status()

func _set_editor_tool(tool_index: int) -> void:
	_editor_tool = clampi(tool_index, TOOL_TERRAIN, TOOL_SELECT)
	for index in _editor_tool_buttons.size():
		_editor_tool_buttons[index].set_pressed_no_signal(index == _editor_tool)
	_sync_tool_options()
	_sync_editor_status()

func _sync_tool_options() -> void:
	if _terrain_options == null:
		return
	_terrain_options.visible = _editor_tool == TOOL_TERRAIN
	_building_options.visible = _editor_tool == TOOL_BUILDING
	_prop_options.visible = _editor_tool == TOOL_PROP

func _on_prop_filter_changed(text: String) -> void:
	_rebuild_prop_picker(text)

func _rebuild_prop_picker(filter_text: String) -> void:
	if _editor_prop_picker == null:
		return
	var previous := ""
	if _editor_prop_picker.selected >= 0 and _editor_prop_picker.item_count > 0:
		previous = _editor_prop_picker.get_item_text(_editor_prop_picker.selected)
	_editor_prop_picker.clear()
	var needle := filter_text.strip_edges().to_lower()
	var selected_index := 0
	for kind in _all_prop_kinds:
		if not needle.is_empty() and not kind.to_lower().contains(needle):
			continue
		_editor_prop_picker.add_item(kind)
		if kind == previous:
			selected_index = _editor_prop_picker.item_count - 1
	if _editor_prop_picker.item_count == 0:
		_editor_prop_picker.add_item("barrels")
	_editor_prop_picker.select(selected_index)

func _selected_prop_kind() -> StringName:
	if _editor_prop_picker == null or _editor_prop_picker.item_count == 0:
		return &"barrels"
	var index := maxi(_editor_prop_picker.selected, 0)
	return StringName(_editor_prop_picker.get_item_text(index))

func _refresh_maps() -> void:
	_map_paths.clear()
	_source_list.clear()
	_root_picker.clear()
	_load_issues.clear()
	_skipped_map_names.clear()
	_status.tooltip_text = ""
	var directory := DirAccess.open("res://content/maps")
	if directory == null:
		_status.text = "Cannot open res://content/maps"
		return
	for file_name in directory.get_files():
		if file_name.get_extension().to_lower() == "rrmap":
			_map_paths.append("res://content/maps/%s" % file_name)
	_map_paths.sort()
	for path in _map_paths:
		var display_name := path.get_file().get_basename()
		_source_list.add_item(display_name)
		_root_picker.add_item(display_name)
	var default_index := _map_paths.find("res://content/maps/lower_town_slice.rrmap")
	_root_picker.select(maxi(default_index, 0))
	for index in _map_paths.size():
		_source_list.select(index, false)
	_status.text = (
		"Found %d .rrmap files. Double-click one to edit, or switch to Align maps."
		% _map_paths.size()
	)
	_status.tooltip_text = ""

func _load_selected_maps() -> void:
	var paths: Array[String] = []
	for index in _source_list.get_selected_items():
		paths.append(_map_paths[index])
	if paths.is_empty():
		_status.text = "Select at least one map source."
		return
	_set_workspace_mode(MODE_ALIGN)
	_load_paths(paths)

func _load_all_maps() -> void:
	_set_workspace_mode(MODE_ALIGN)
	_load_paths(_map_paths)

func _edit_selected_map() -> void:
	var selected := _source_list.get_selected_items()
	if selected.is_empty():
		_status.text = "Select one map source to edit."
		return
	var index := selected[0]
	if index < 0 or index >= _map_paths.size():
		return
	open_source(_map_paths[index])

func _open_source_from_list(index: int) -> void:
	if index < 0 or index >= _map_paths.size():
		return
	_source_list.select(index, true)
	open_source(_map_paths[index])

func open_source(path: String) -> void:
	if path.get_extension().to_lower() != "rrmap":
		return
	if not is_node_ready():
		await ready
	if not FileAccess.file_exists(path):
		_status.text = "RRMap source does not exist: %s" % path
		return
	_workspace_mode = MODE_EDIT
	_apply_workspace_mode()
	_load_paths([path], path)
	_edit_mode_toggle.set_pressed_no_signal(true)
	_set_edit_mode(true)
	_set_editor_tool(TOOL_PROP)
	if _sidebar_scroll != null:
		_sidebar_scroll.scroll_vertical = 0
	_source_list.ensure_current_is_visible()

static func parse_map_paths(paths: Array[String]) -> Dictionary:
	var definitions: Array[MapDefinition] = []
	var issues := PackedStringArray()
	var skipped_names: Array[String] = []
	var path_by_map_id := {}
	for path in paths:
		var parsed := MapRrmapParser.parse_file(path)
		if parsed.is_ok():
			definitions.append(parsed.definition)
			path_by_map_id[parsed.definition.map_id] = path
			continue
		skipped_names.append(path.get_file().get_basename())
		issues.append_array(parsed.formatted_diagnostics())
	return {
		"definitions": definitions,
		"issues": issues,
		"skipped_names": skipped_names,
		"path_by_map_id": path_by_map_id,
	}

func _load_paths(paths: Array[String], preferred_path := "") -> void:
	_loaded_paths = paths.duplicate()
	var parsed := parse_map_paths(paths)
	_definitions = parsed["definitions"]
	_load_issues = parsed["issues"]
	_skipped_map_names = parsed["skipped_names"]
	_path_by_map_id = parsed["path_by_map_id"]

	if _definitions.is_empty():
		_seams.clear()
		_canvas.clear()
		_refresh_layer_picker()
		_status.text = "Could not load any requested maps:\n%s" % "\n".join(_load_issues)
		_status.tooltip_text = "\n".join(_load_issues)
		return

	# Keep valid maps visible even when another source has semantic errors. This is
	# intentionally a partial load, not an error waiver: bad sources are listed so
	# the author can fix them without losing the useful alignment context.
	_auto_layout()
	if not preferred_path.is_empty():
		var preferred_id := _map_id_for_path(preferred_path)
		if not preferred_id.is_empty():
			_canvas.select_layer(preferred_id)
			_on_canvas_layer_selected(preferred_id)

func _auto_layout() -> void:
	if _definitions.is_empty():
		return
	var root_name := (
		_root_picker.get_item_text(_root_picker.selected)
		if _root_picker.selected >= 0
		else ""
	)
	var root_id: StringName = &""
	for definition in _definitions:
		if String(definition.map_id) == root_name or _source_basename(definition) == root_name:
			root_id = definition.map_id
			break
	if root_id.is_empty():
		root_id = _definitions[0].map_id
	var layout := MapAlignmentMath.layout_all_maps(_definitions, root_id)
	_seams = layout["seams"]
	_canvas.configure(_definitions, layout["offsets"], _seams)
	_refresh_layer_picker()
	_update_status()

func _source_basename(definition: MapDefinition) -> String:
	var source_path := _source_path_for_map_id(definition.map_id)
	if source_path.is_empty():
		return String(definition.map_id)
	return source_path.get_file().get_basename()

func _map_id_for_path(path: String) -> StringName:
	for map_id in _path_by_map_id.keys():
		if String(_path_by_map_id[map_id]) == path:
			return map_id
	var parsed := MapRrmapParser.parse_file(path)
	if parsed.is_ok():
		_path_by_map_id[parsed.definition.map_id] = path
		return parsed.definition.map_id
	return &""

func _source_path_for_map_id(map_id: StringName) -> String:
	if _path_by_map_id.has(map_id):
		return String(_path_by_map_id[map_id])
	for path in _loaded_paths:
		var resolved := _map_id_for_path(path)
		if resolved == map_id:
			return path
	return ""

func _refresh_layer_picker() -> void:
	_layer_picker.clear()
	for map_id in _canvas.layer_ids():
		_layer_picker.add_item(String(map_id))
	if _layer_picker.item_count > 0:
		_layer_picker.select(0)
		_sync_layer_controls()

func _on_layer_picked(index: int) -> void:
	if index >= 0:
		_canvas.select_layer(StringName(_layer_picker.get_item_text(index)))
	_sync_layer_controls()
	if _workspace_mode == MODE_EDIT:
		_load_editor_for_selected()

func _on_canvas_layer_selected(map_id: StringName) -> void:
	for index in _layer_picker.item_count:
		if StringName(_layer_picker.get_item_text(index)) == map_id:
			_layer_picker.select(index)
			break
	_sync_layer_controls()
	if _workspace_mode == MODE_EDIT:
		_load_editor_for_selected()

func _load_editor_for_selected(force_reload := false) -> void:
	if _editor_model == null:
		_editor_model = MapAlignmentEditorModel.new()
	if _canvas.selected_map_id.is_empty():
		return
	var path := _source_path_for_map_id(_canvas.selected_map_id)
	if path.is_empty():
		_set_editor_status("Could not resolve the selected map's .rrmap source path.")
		return
	# Reloading from disk wiped unsaved drafts and made every layer click feel slow.
	if not force_reload and _editor_model.source_path == path and _editor_model.blueprint != null:
		_sync_editor_controls()
		return
	if not _editor_model.load_source(path):
		_set_editor_status(_editor_model.last_error)
		return
	_sync_editor_controls()

func _set_edit_mode(enabled: bool) -> void:
	_canvas.edit_mode = enabled
	_sync_editor_status()
	if enabled:
		_load_editor_for_selected()

func _sync_editor_controls() -> void:
	if _editor_model == null or _editor_model.blueprint == null:
		_save_editor_button.disabled = true
		_revert_editor_button.disabled = true
		_canvas.selected_primitive_id = &""
		return
	_save_editor_button.disabled = not _editor_model.dirty
	_revert_editor_button.disabled = false
	_editor_map_width_spin.set_value_no_signal(_editor_model.blueprint.size_cells.x)
	_editor_map_height_spin.set_value_no_signal(_editor_model.blueprint.size_cells.y)
	_editor_elevation_spin.set_value_no_signal(_editor_model.blueprint.ground_elevation)
	_canvas.selected_primitive_id = _editor_model.selected_primitive_id
	_sync_editor_status()

func _sync_editor_status() -> void:
	if _editor_status == null:
		return
	if _editor_model == null or _editor_model.blueprint == null:
		_editor_status.text = "Open a map to start editing."
		return
	var tool_names := ["Paint terrain", "Place building", "Place prop", "Select/move"]
	_editor_status.text = "%s | %d x %d | %s%s" % [
		tool_names[_editor_tool],
		_editor_model.blueprint.size_cells.x,
		_editor_model.blueprint.size_cells.y,
		"unsaved" if _editor_model.dirty else "saved",
		("\n" + _editor_model.last_error) if not _editor_model.last_error.is_empty() else "",
	]

func _set_editor_status(message: String) -> void:
	if _editor_status != null:
		_editor_status.text = message

func _resize_editor_map(_value: float) -> void:
	if _editor_model == null or _editor_model.blueprint == null:
		return
	var next_size := Vector2i(roundi(_editor_map_width_spin.value),
		roundi(_editor_map_height_spin.value))
	if next_size == _editor_model.blueprint.size_cells:
		return
	if not _editor_model.set_size(next_size):
		_set_editor_status(_editor_model.last_error)
		return
	_apply_editor_preview(true)

func _set_editor_elevation(value: float) -> void:
	if _editor_model == null or _editor_model.blueprint == null:
		return
	if is_equal_approx(_editor_model.blueprint.ground_elevation, value):
		return
	if not _editor_model.set_ground_elevation(value):
		_set_editor_status(_editor_model.last_error)
		return
	_apply_editor_preview(false)

func _on_editor_cell_clicked(cell: Vector2i, button_index: int) -> void:
	if _workspace_mode != MODE_EDIT:
		return
	if _editor_model == null or _editor_model.blueprint == null:
		_load_editor_for_selected()
	if _editor_model == null or _editor_model.blueprint == null:
		return
	if button_index == MOUSE_BUTTON_RIGHT:
		var removed: StringName = _editor_model.remove_primitive_at(cell)
		_set_editor_status("Removed %s" % removed
			if not removed.is_empty() else "No editable primitive at %s" % cell)
		if not removed.is_empty():
			# Removals may delete terrain rectangles; rebuild the terrain texture.
			_apply_editor_preview(true)
	elif _editor_tool == TOOL_TERRAIN:
		var terrain := StringName(_editor_terrain_picker.get_item_text(_editor_terrain_picker.selected))
		_editor_model.paint_terrain(cell, terrain)
		_apply_editor_preview(true)
	elif _editor_tool == TOOL_BUILDING:
		var kind := StringName(_editor_building_picker.get_item_text(_editor_building_picker.selected))
		_editor_model.add_building(kind, cell, Vector2i(roundi(_editor_width_spin.value),
			roundi(_editor_height_spin.value)))
		_apply_editor_preview(false)
	elif _editor_tool == TOOL_PROP:
		var prop_kind := _selected_prop_kind()
		if _editor_model.add_prop(prop_kind, cell).is_empty():
			_set_editor_status(_editor_model.last_error)
		else:
			_apply_editor_preview(false)
	elif _editor_tool == TOOL_SELECT:
		var primitive := _editor_model.select_primitive_at(cell)
		_canvas.selected_primitive_id = _editor_model.selected_primitive_id
		_canvas.queue_redraw()
		_set_editor_status(
			"Selected %s (%s). Arrow keys move; right click removes."
			% [primitive.get("id", "nothing"), primitive.get("primitive", "")]
		)

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if _workspace_mode == MODE_EDIT:
		match key.keycode:
			KEY_1:
				_set_editor_tool(TOOL_TERRAIN)
				get_viewport().set_input_as_handled()
				return
			KEY_2:
				_set_editor_tool(TOOL_BUILDING)
				get_viewport().set_input_as_handled()
				return
			KEY_3:
				_set_editor_tool(TOOL_PROP)
				get_viewport().set_input_as_handled()
				return
			KEY_4:
				_set_editor_tool(TOOL_SELECT)
				get_viewport().set_input_as_handled()
				return
	if not _canvas.edit_mode or _editor_model == null:
		return
	if _editor_model.selected_primitive_id.is_empty():
		return
	var delta := Vector2i.ZERO
	match key.keycode:
		KEY_LEFT: delta = Vector2i.LEFT
		KEY_RIGHT: delta = Vector2i.RIGHT
		KEY_UP: delta = Vector2i.UP
		KEY_DOWN: delta = Vector2i.DOWN
	if delta == Vector2i.ZERO:
		return
	if key.shift_pressed:
		delta *= 10
	if _editor_model.move_primitive(_editor_model.selected_primitive_id, delta):
		_apply_editor_preview(false)
		get_viewport().set_input_as_handled()
	else:
		_set_editor_status(_editor_model.last_error)

func _apply_editor_preview(rebuild_terrain: bool) -> void:
	if _editor_model == null or _editor_model.definition == null:
		_sync_editor_controls()
		return
	_canvas.selected_primitive_id = _editor_model.selected_primitive_id
	_canvas.update_layer_definition(_canvas.selected_map_id, _editor_model.definition, rebuild_terrain)
	for index in _definitions.size():
		if _definitions[index].map_id == _canvas.selected_map_id:
			_definitions[index] = _editor_model.definition
			break
	_sync_editor_controls()
	_update_status()

func _save_editor_map() -> void:
	if _editor_model == null or not _editor_model.save():
		_set_editor_status(_editor_model.last_error if _editor_model != null else "No editor session")
		return
	_apply_editor_preview(true)
	_set_editor_status("Saved %s" % _editor_model.source_path)

func _revert_editor_map() -> void:
	if _editor_model == null or not _editor_model.revert():
		_set_editor_status(_editor_model.last_error if _editor_model != null else "No editor session")
		return
	_apply_editor_preview(true)

func _sync_layer_controls() -> void:
	var layer := _canvas.layer(_canvas.selected_map_id)
	if layer.is_empty():
		return
	_visible_toggle.set_pressed_no_signal(bool(layer["visible"]))
	var opacity := float(layer["opacity"])
	_opacity_slider.set_value_no_signal(opacity)
	_opacity_label.text = "%d%%" % roundi(opacity * 100.0)

func _set_selected_visible(value: bool) -> void:
	_canvas.set_layer_visible(_canvas.selected_map_id, value)

func _set_opacity(value: float) -> void:
	_canvas.set_selected_opacity(value)
	_opacity_label.text = "%d%%" % roundi(value * 100.0)

func _set_blink(value: bool) -> void:
	_blink_enabled = value
	_blink_visible = true
	if value:
		_blink_timer.start()
	else:
		_blink_timer.stop()
		_canvas.set_selected_opacity(_opacity_slider.value)

func _blink_tick() -> void:
	_blink_visible = not _blink_visible
	_canvas.set_selected_opacity(_opacity_slider.value if _blink_visible else 0.03)

func _choose_background() -> void:
	_background_dialog.popup_centered_ratio(0.75)

func _load_background(path: String) -> void:
	var image := Image.new()
	var error := image.load(path)
	if error != OK or image.is_empty():
		_status.text = "Could not load background image %s: %s" % [path, error_string(error)]
		return
	_canvas.set_background(ImageTexture.create_from_image(image), path)
	_canvas.request_fit()
	_status.text = "Loaded reference background %s (%d x %d px)." % [path.get_file(), image.get_width(
		), image.get_height()]

func _clear_background() -> void:
	_canvas.clear_background()
	_sync_background_controls()
	_update_status()

func _sync_background_controls() -> void:
	if _canvas == null:
		return
	var has_image := _canvas.has_background()
	var display_path := _canvas.background_path if has_image else "No image selected"
	_background_path_label.text = display_path.get_file() if has_image else display_path
	_background_path_label.tooltip_text = display_path
	_background_visible_toggle.disabled = not has_image
	_background_move_toggle.disabled = not has_image
	_background_opacity_slider.editable = has_image
	_background_scale_spin.editable = has_image
	_background_x_spin.editable = has_image
	_background_y_spin.editable = has_image
	_background_visible_toggle.set_pressed_no_signal(_canvas.background_visible)
	_background_move_toggle.set_pressed_no_signal(_canvas.edit_background)
	_background_opacity_slider.set_value_no_signal(_canvas.background_opacity)
	_background_opacity_label.text = "%d%%" % roundi(_canvas.background_opacity * 100.0)
	_background_scale_spin.set_value_no_signal(_canvas.background_scale)
	_background_x_spin.set_value_no_signal(_canvas.background_offset.x)
	_background_y_spin.set_value_no_signal(_canvas.background_offset.y)

func _update_status() -> void:
	if _workspace_mode == MODE_EDIT:
		if _editor_model != null and _editor_model.blueprint != null:
			_status.text = (
				(
					"Editing %s. Tools 1-4 | click to place | right-click remove | "
					+ "arrows move selection | Save map writes .rrmap."
				)
				% _editor_model.source_path.get_file()
			)
		else:
			_status.text = "Edit map: double-click a source or press Open selected."
		return
	var background_summary := "no background"
	if _canvas.has_background():
		background_summary = "background %s at (%.0f, %.0f), scale %.3f" % [
			_canvas.background_path.get_file(),
			_canvas.background_offset.x,
			_canvas.background_offset.y,
			_canvas.background_scale,
		]
	if _definitions.is_empty():
		_status.text = "%s. Load maps, or adjust the background under Show advanced." % background_summary
		return
	var mismatch_count := 0
	for seam in _seams:
		if not is_equal_approx(float(seam["base_span_cells"]), float(seam["neighbor_span_cells"])):
			mismatch_count += 1
	var selected := _canvas.layer(_canvas.selected_map_id)
	var offset_cells := Vector2.ZERO
	if not selected.is_empty():
		var definition: MapDefinition = selected["definition"]
		offset_cells = Vector2(selected["offset"]) / float(definition.cell_size)
	var interaction_hint := (
		"left-drag/arrows: move background; middle-drag: pan"
		if _canvas.edit_background
		else "drag: pan; arrows: move selected"
	)
	_status.text = (
		"%d maps | %d seams | %d width mismatches | %s | selected: %s at (%.1f, %.1f). %s"
		% [
			_definitions.size(),
			_seams.size(),
			mismatch_count,
			background_summary,
			_canvas.selected_map_id,
			offset_cells.x,
			offset_cells.y,
			interaction_hint,
		]
	)
	if not _load_issues.is_empty():
		_status.text += " Skipped %d map(s): %s." % [_skipped_map_names.size(), ", ".join(
			_skipped_map_names)]
		_status.tooltip_text = "\n".join(_load_issues)

func _choose_export_path() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEFAULT_EXPORT_DIR))
	_export_dialog.current_dir = ProjectSettings.globalize_path(DEFAULT_EXPORT_DIR)
	_export_dialog.current_file = "rrmap-multi-map-layout.png"
	_export_dialog.popup_centered_ratio(0.7)

func _export_png(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var rect := Rect2i(Vector2i(_canvas.global_position.round()), Vector2i(_canvas.size.round()))
	rect = rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	if not rect.has_area():
		_status.text = "PNG export failed: canvas is outside the editor viewport."
		return
	var error := image.get_region(rect).save_png(path)
	if error == OK:
		_status.text = "Exported alignment view to %s" % path
	else:
		_status.text = "PNG export failed: %s" % error_string(error)
