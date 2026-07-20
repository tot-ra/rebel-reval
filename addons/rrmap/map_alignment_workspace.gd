@tool
class_name MapAlignmentWorkspace
extends VBoxContainer

## Main-screen Godot workspace for visual .rrmap seam review. It supports visual
## positioning only: source files remain authoritative and are never rewritten.

const DEFAULT_EXPORT_DIR := "res://build/map_alignment"

var _base_picker: OptionButton
var _neighbor_picker: OptionButton
var _pair_picker: OptionButton
var _opacity_slider: HSlider
var _opacity_label: Label
var _status: Label
var _canvas: MapAlignmentCanvas
var _blink_timer: Timer
var _export_dialog: FileDialog
var _blink_enabled := false
var _blink_visible := true
var _map_paths: Array[String] = []
var _pairs: Array[Dictionary] = []


func _ready() -> void:
	_build_ui()
	_refresh_maps()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_theme_constant_override("separation", 6)

	var title := Label.new()
	title.text = "RRMap Alignment"
	title.add_theme_font_size_override("font_size", 22)
	add_child(title)

	var source_row := HBoxContainer.new()
	source_row.add_theme_constant_override("separation", 8)
	add_child(source_row)
	_base_picker = _add_labeled_picker(source_row, "Base map")
	_neighbor_picker = _add_labeled_picker(source_row, "Neighbor")
	var load_button := Button.new()
	load_button.text = "Load maps"
	load_button.tooltip_text = "Parse and compile both .rrmap sources"
	load_button.pressed.connect(_load_selected_maps)
	source_row.add_child(load_button)
	var refresh_button := Button.new()
	refresh_button.text = "Refresh files"
	refresh_button.pressed.connect(_refresh_maps)
	source_row.add_child(refresh_button)

	var align_row := HBoxContainer.new()
	align_row.add_theme_constant_override("separation", 8)
	add_child(align_row)
	_pair_picker = _add_labeled_picker(align_row, "Linked seam")
	_pair_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pair_picker.item_selected.connect(_on_pair_selected)
	var auto_button := Button.new()
	auto_button.text = "Auto-align"
	auto_button.tooltip_text = "Make linked map edges touch and center their reciprocal transitions"
	auto_button.pressed.connect(_auto_align)
	align_row.add_child(auto_button)
	var fit_button := Button.new()
	fit_button.text = "Fit"
	fit_button.pressed.connect(func() -> void: _canvas.fit_to_maps())
	align_row.add_child(fit_button)
	_add_nudge_button(align_row, "←", Vector2i.LEFT)
	_add_nudge_button(align_row, "↑", Vector2i.UP)
	_add_nudge_button(align_row, "↓", Vector2i.DOWN)
	_add_nudge_button(align_row, "→", Vector2i.RIGHT)

	var view_row := HBoxContainer.new()
	view_row.add_theme_constant_override("separation", 8)
	add_child(view_row)
	var grid_toggle := CheckButton.new()
	grid_toggle.text = "Grid"
	grid_toggle.button_pressed = true
	grid_toggle.toggled.connect(func(value: bool) -> void:
		_canvas.show_grid = value
		_canvas.queue_redraw()
	)
	view_row.add_child(grid_toggle)
	var feature_toggle := CheckButton.new()
	feature_toggle.text = "Walls/buildings"
	feature_toggle.button_pressed = true
	feature_toggle.toggled.connect(func(value: bool) -> void:
		_canvas.show_features = value
		_canvas.queue_redraw()
	)
	view_row.add_child(feature_toggle)
	var id_toggle := CheckButton.new()
	id_toggle.text = "Stable IDs"
	id_toggle.toggled.connect(func(value: bool) -> void:
		_canvas.show_ids = value
		_canvas.queue_redraw()
	)
	view_row.add_child(id_toggle)
	var blink_toggle := CheckButton.new()
	blink_toggle.text = "Blink neighbor"
	blink_toggle.toggled.connect(_set_blink)
	view_row.add_child(blink_toggle)
	var opacity_text := Label.new()
	opacity_text.text = "Neighbor opacity"
	view_row.add_child(opacity_text)
	_opacity_slider = HSlider.new()
	_opacity_slider.min_value = 0.05
	_opacity_slider.max_value = 1.0
	_opacity_slider.step = 0.05
	_opacity_slider.value = 0.55
	_opacity_slider.custom_minimum_size.x = 150.0
	_opacity_slider.value_changed.connect(_set_opacity)
	view_row.add_child(_opacity_slider)
	_opacity_label = Label.new()
	_opacity_label.text = "55%"
	view_row.add_child(_opacity_label)
	var export_button := Button.new()
	export_button.text = "Export PNG"
	export_button.pressed.connect(_choose_export_path)
	view_row.add_child(export_button)

	_status = Label.new()
	_status.text = "Choose two maps. Mouse wheel zooms, drag pans, arrow keys nudge the neighbor by one cell (Shift: 10)."
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.y = 42.0
	add_child(_status)

	_canvas = MapAlignmentCanvas.new()
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.custom_minimum_size = Vector2(640, 400)
	_canvas.view_changed.connect(_update_status)
	add_child(_canvas)

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


func _add_labeled_picker(parent: HBoxContainer, text: String) -> OptionButton:
	var label := Label.new()
	label.text = text
	parent.add_child(label)
	var picker := OptionButton.new()
	picker.custom_minimum_size.x = 230.0
	parent.add_child(picker)
	return picker


func _add_nudge_button(parent: HBoxContainer, text: String, delta: Vector2i) -> void:
	var button := Button.new()
	button.text = text
	button.tooltip_text = "Nudge neighbor one cell"
	button.pressed.connect(func() -> void: _canvas.nudge_neighbor(delta))
	parent.add_child(button)


func _refresh_maps() -> void:
	_map_paths.clear()
	_base_picker.clear()
	_neighbor_picker.clear()
	var directory := DirAccess.open("res://content/maps")
	if directory == null:
		_status.text = "Cannot open res://content/maps"
		return
	for file_name in directory.get_files():
		if file_name.get_extension().to_lower() == "rrmap":
			_map_paths.append("res://content/maps/%s" % file_name)
	_map_paths.sort()
	for path in _map_paths:
		_base_picker.add_item(path.get_file().get_basename())
		_neighbor_picker.add_item(path.get_file().get_basename())
	var base_default := _map_paths.find("res://content/maps/lower_town_slice.rrmap")
	var neighbor_default := _map_paths.find("res://content/maps/market_civic_quarter.rrmap")
	_base_picker.select(maxi(base_default, 0))
	_neighbor_picker.select(maxi(neighbor_default, mini(1, _map_paths.size() - 1)))
	_status.text = "Found %d .rrmap files. Select two maps and click Load maps." % _map_paths.size()


func _load_selected_maps() -> void:
	if _map_paths.is_empty():
		return
	var base_result := MapRrmapParser.parse_file(_map_paths[_base_picker.selected])
	var neighbor_result := MapRrmapParser.parse_file(_map_paths[_neighbor_picker.selected])
	if not base_result.is_ok() or not neighbor_result.is_ok():
		var errors := PackedStringArray()
		errors.append_array(base_result.formatted_diagnostics())
		errors.append_array(neighbor_result.formatted_diagnostics())
		_status.text = "Could not compile maps:\n%s" % "\n".join(errors)
		return
	_canvas.configure(base_result.definition, neighbor_result.definition)
	_pairs = MapAlignmentMath.find_transition_pairs(base_result.definition, neighbor_result.definition)
	_pair_picker.clear()
	for pair in _pairs:
		_pair_picker.add_item("%s (%s) ↔ %s (%s)" % [
			pair["base"]["id"], pair["base_side"], pair["neighbor"]["id"], pair["neighbor_side"],
		])
	if _pairs.is_empty():
		_pair_picker.add_item("No reciprocal transition pair")
		_canvas.base_transition = {}
		_canvas.neighbor_transition = {}
		_canvas.set_neighbor_offset(Vector2(_canvas.base_definition.world_size().x, 0.0))
	else:
		_on_pair_selected(0)
		_auto_align()
	call_deferred("_fit_after_layout")


func _fit_after_layout() -> void:
	await get_tree().process_frame
	_canvas.fit_to_maps()
	_update_status()


func _on_pair_selected(index: int) -> void:
	if index < 0 or index >= _pairs.size():
		return
	var pair := _pairs[index]
	_canvas.base_transition = pair["base"]
	_canvas.neighbor_transition = pair["neighbor"]
	_canvas.queue_redraw()
	_update_status()


func _auto_align() -> void:
	if _pairs.is_empty() or _pair_picker.selected < 0:
		return
	var pair := _pairs[_pair_picker.selected]
	_canvas.set_neighbor_offset(MapAlignmentMath.aligned_neighbor_offset(
		_canvas.base_definition,
		_canvas.neighbor_definition,
		pair["base"],
		pair["neighbor"]
	))
	_update_status()


func _set_opacity(value: float) -> void:
	_canvas.neighbor_opacity = value
	_opacity_label.text = "%d%%" % roundi(value * 100.0)
	_canvas.queue_redraw()


func _set_blink(value: bool) -> void:
	_blink_enabled = value
	_blink_visible = true
	if value:
		_blink_timer.start()
	else:
		_blink_timer.stop()
		_set_opacity(_opacity_slider.value)


func _blink_tick() -> void:
	_blink_visible = not _blink_visible
	_canvas.neighbor_opacity = _opacity_slider.value if _blink_visible else 0.03
	_canvas.queue_redraw()


func _update_status() -> void:
	if _canvas.base_definition == null or _canvas.neighbor_definition == null:
		return
	var cells := MapAlignmentMath.offset_in_neighbor_cells(_canvas.neighbor_definition, _canvas.neighbor_offset_px)
	var message := "Neighbor offset: (%.2f, %.2f) cells | (%d, %d) px" % [
		cells.x, cells.y, roundi(_canvas.neighbor_offset_px.x), roundi(_canvas.neighbor_offset_px.y),
	]
	if not _pairs.is_empty() and _pair_picker.selected >= 0:
		var pair := _pairs[_pair_picker.selected]
		var base_span := MapAlignmentMath.seam_span_cells(_canvas.base_definition, pair["base"], pair["base_side"])
		var neighbor_span := MapAlignmentMath.seam_span_cells(_canvas.neighbor_definition, pair["neighbor"], pair["neighbor_side"])
		message += " | seam spans %.1f vs %.1f cells" % [base_span, neighbor_span]
		if not is_equal_approx(base_span, neighbor_span):
			message += " - WIDTH MISMATCH"
	_status.text = message + "\nVisual-only: apply intended coordinate changes in the .rrmap source, then reload."


func _choose_export_path() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEFAULT_EXPORT_DIR))
	_export_dialog.current_dir = ProjectSettings.globalize_path(DEFAULT_EXPORT_DIR)
	var base_name := String(_canvas.base_definition.map_id) if _canvas.base_definition != null else "base"
	var neighbor_name := String(_canvas.neighbor_definition.map_id) if _canvas.neighbor_definition != null else "neighbor"
	_export_dialog.current_file = "%s--%s.png" % [base_name, neighbor_name]
	_export_dialog.popup_centered_ratio(0.7)


func _export_png(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var rect := Rect2i(Vector2i(_canvas.global_position.round()), Vector2i(_canvas.size.round()))
	rect = rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	if not rect.has_area():
		_status.text = "PNG export failed: canvas is outside the editor viewport."
		return
	var cropped := image.get_region(rect)
	var error := cropped.save_png(path)
	if error == OK:
		_status.text = "Exported alignment view to %s" % path
	else:
		_status.text = "PNG export failed: %s" % error_string(error)
