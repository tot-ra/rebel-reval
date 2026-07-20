@tool
class_name MapAlignmentWorkspace
extends VBoxContainer

## Main-screen multi-map workspace. Source files remain authoritative and the
## editor stores only temporary map-layer and reference-background state.

const DEFAULT_EXPORT_DIR := "res://build/map_alignment"

var _source_list: ItemList
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
var _blink_enabled := false
var _blink_visible := true
var _map_paths: Array[String] = []
var _definitions: Array[MapDefinition] = []
var _seams: Array[Dictionary] = []


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_ui()
	_refresh_maps()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_theme_constant_override("separation", 4)

	var toolbar := HFlowContainer.new()
	toolbar.add_theme_constant_override("h_separation", 6)
	toolbar.add_theme_constant_override("v_separation", 4)
	add_child(toolbar)
	_add_button(toolbar, "Load selected", _load_selected_maps, "Load every map selected in the source list")
	_add_button(toolbar, "Load all maps", _load_all_maps, "Load and arrange every .rrmap source")
	_add_button(toolbar, "Add background", _choose_background, "Choose a reference image to render beneath every map")
	_add_button(toolbar, "Refresh files", _refresh_maps)
	_add_button(toolbar, "Auto-layout", _auto_layout, "Rebuild the connected map graph from reciprocal transitions")
	_add_button(toolbar, "Fit all", func() -> void: _canvas.request_fit())
	_add_button(toolbar, "←", func() -> void: _canvas.nudge_selected(Vector2i.LEFT))
	_add_button(toolbar, "↑", func() -> void: _canvas.nudge_selected(Vector2i.UP))
	_add_button(toolbar, "↓", func() -> void: _canvas.nudge_selected(Vector2i.DOWN))
	_add_button(toolbar, "→", func() -> void: _canvas.nudge_selected(Vector2i.RIGHT))
	_add_button(toolbar, "Export PNG", _choose_export_path)

	var split := HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 290
	add_child(split)

	var sidebar_scroll := ScrollContainer.new()
	sidebar_scroll.custom_minimum_size.x = 250.0
	sidebar_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(sidebar_scroll)
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 250.0
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar.add_theme_constant_override("separation", 6)
	sidebar_scroll.add_child(sidebar)
	var source_title := Label.new()
	source_title.text = "Map sources (Cmd/Ctrl or Shift to multi-select)"
	source_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sidebar.add_child(source_title)
	_source_list = ItemList.new()
	_source_list.select_mode = ItemList.SELECT_MULTI
	_source_list.custom_minimum_size.y = 180.0
	sidebar.add_child(_source_list)

	var root_label := Label.new()
	root_label.text = "Layout root"
	sidebar.add_child(root_label)
	_root_picker = OptionButton.new()
	_root_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar.add_child(_root_picker)

	var layer_label := Label.new()
	layer_label.text = "Selected loaded layer"
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
	var grid_toggle := CheckButton.new()
	grid_toggle.text = "Grid"
	grid_toggle.button_pressed = true
	grid_toggle.toggled.connect(func(value: bool) -> void:
		_canvas.show_grid = value
		_canvas.queue_redraw()
	)
	sidebar.add_child(grid_toggle)
	var feature_toggle := CheckButton.new()
	feature_toggle.text = "Walls/buildings"
	feature_toggle.button_pressed = true
	feature_toggle.toggled.connect(func(value: bool) -> void:
		_canvas.show_features = value
		_canvas.queue_redraw()
	)
	sidebar.add_child(feature_toggle)
	var id_toggle := CheckButton.new()
	id_toggle.text = "Stable IDs"
	id_toggle.toggled.connect(func(value: bool) -> void:
		_canvas.show_ids = value
		_canvas.queue_redraw()
	)
	sidebar.add_child(id_toggle)
	_build_background_controls(sidebar)

	_canvas = MapAlignmentCanvas.new()
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.custom_minimum_size = Vector2(480, 300)
	_canvas.view_changed.connect(_update_status)
	_canvas.selected_layer_changed.connect(_on_canvas_layer_selected)
	_canvas.background_changed.connect(_sync_background_controls)
	split.add_child(_canvas)

	_status = Label.new()
	_status.text = "Select several sources, then Load selected, or use Load all maps."
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
	_background_move_toggle.tooltip_text = "Left-drag or use arrows to move the background; middle-drag still pans"
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


func _refresh_maps() -> void:
	_map_paths.clear()
	_source_list.clear()
	_root_picker.clear()
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
	_status.text = "Found %d .rrmap files. All are preselected; Load selected or Load all maps." % _map_paths.size()


func _load_selected_maps() -> void:
	var paths: Array[String] = []
	for index in _source_list.get_selected_items():
		paths.append(_map_paths[index])
	if paths.is_empty():
		_status.text = "Select at least one map source."
		return
	_load_paths(paths)


func _load_all_maps() -> void:
	_load_paths(_map_paths)


func _load_paths(paths: Array[String]) -> void:
	_definitions.clear()
	var errors := PackedStringArray()
	for path in paths:
		var parsed := MapRrmapParser.parse_file(path)
		if parsed.is_ok():
			_definitions.append(parsed.definition)
		else:
			errors.append_array(parsed.formatted_diagnostics())
	if not errors.is_empty():
		_status.text = "Could not compile all requested maps:\n%s" % "\n".join(errors)
		return
	_auto_layout()


func _auto_layout() -> void:
	if _definitions.is_empty():
		return
	var root_name := _root_picker.get_item_text(_root_picker.selected) if _root_picker.selected >= 0 else ""
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
	for path in _map_paths:
		if path.get_file().get_basename() == String(definition.map_id):
			return path.get_file().get_basename()
	return String(definition.map_id)


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


func _on_canvas_layer_selected(map_id: StringName) -> void:
	for index in _layer_picker.item_count:
		if StringName(_layer_picker.get_item_text(index)) == map_id:
			_layer_picker.select(index)
			break
	_sync_layer_controls()


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
	_status.text = "Loaded reference background %s (%d x %d px)." % [path.get_file(), image.get_width(), image.get_height()]


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
	var background_summary := "no background"
	if _canvas.has_background():
		background_summary = "background %s at (%.0f, %.0f), scale %.3f" % [
			_canvas.background_path.get_file(),
			_canvas.background_offset.x,
			_canvas.background_offset.y,
			_canvas.background_scale,
		]
	if _definitions.is_empty():
		_status.text = "%s. Add/load maps, or adjust the background with its controls." % background_summary
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
	var interaction_hint := "left-drag/arrows: move background; middle-drag: pan" if _canvas.edit_background else "drag: pan; arrows: move selected"
	_status.text = "%d maps | %d reciprocal seams | %d width mismatches | %s | selected: %s at (%.1f, %.1f) cells. Wheel: zoom, %s (Shift: 10)." % [
		_definitions.size(), _seams.size(), mismatch_count, background_summary,
		_canvas.selected_map_id, offset_cells.x, offset_cells.y, interaction_hint,
	]


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
	_status.text = "Exported alignment view to %s" % path if error == OK else "PNG export failed: %s" % error_string(error)
