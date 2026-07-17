class_name InventoryOverlay
extends CanvasLayer

signal closed()

const CELL_SIZE := 48
const CELL_GAP := 4
const PANEL_PADDING := 16

const CATEGORY_COLORS := {
	"weapon": Color(0.72, 0.38, 0.28, 0.92),
	"evidence": Color(0.55, 0.62, 0.74, 0.92),
	"commission_object": Color(0.78, 0.66, 0.34, 0.92),
	"material": Color(0.42, 0.58, 0.36, 0.92),
	"supply": Color(0.38, 0.62, 0.58, 0.92),
	"quest_tool": Color(0.58, 0.42, 0.72, 0.92),
}

var _bag: InventoryBag
var _content_db: ContentDB
var _selected: InventoryPlacement = null

var _panel: PanelContainer
var _grid: GridContainer
var _weight_bar: ProgressBar
var _volume_bar: ProgressBar
var _speed_label: Label
var _detail_label: Label
var _cell_buttons: Array[Button] = []


func configure(bag: InventoryBag, content_db: ContentDB) -> void:
	_bag = bag
	_content_db = content_db
	if is_node_ready():
		_refresh()


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_refresh()


func open() -> void:
	visible = true
	_selected = null
	_refresh()


func close() -> void:
	visible = false
	_selected = null
	closed.emit()


func is_open() -> bool:
	return visible


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
	root.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", PANEL_PADDING)
	margin.add_theme_constant_override("margin_right", PANEL_PADDING)
	margin.add_theme_constant_override("margin_top", PANEL_PADDING)
	margin.add_theme_constant_override("margin_bottom", PANEL_PADDING)
	_panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	var title := Label.new()
	title.text = "Bag"
	title.add_theme_font_size_override("font_size", 24)
	layout.add_child(title)

	var hint := Label.new()
	hint.text = "I or Esc to close. Click an item, then click a free cell to move it."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color(0.82, 0.84, 0.88)
	layout.add_child(hint)

	_add_meter_row(layout, "Weight", true)
	_add_meter_row(layout, "Volume", false)

	_speed_label = Label.new()
	_speed_label.add_theme_font_size_override("font_size", 13)
	layout.add_child(_speed_label)

	_grid = GridContainer.new()
	_grid.columns = InventoryBag.GRID_WIDTH
	_grid.add_theme_constant_override("h_separation", CELL_GAP)
	_grid.add_theme_constant_override("v_separation", CELL_GAP)
	layout.add_child(_grid)

	_detail_label = Label.new()
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.add_theme_font_size_override("font_size", 13)
	layout.add_child(_detail_label)

	for cell_y in range(InventoryBag.GRID_HEIGHT):
		for cell_x in range(InventoryBag.GRID_WIDTH):
			var button := Button.new()
			button.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
			button.toggle_mode = false
			button.focus_mode = Control.FOCUS_NONE
			var captured_x := cell_x
			var captured_y := cell_y
			button.pressed.connect(func() -> void:
				_on_cell_pressed(captured_x, captured_y)
			)
			_grid.add_child(button)
			_cell_buttons.append(button)


func _add_meter_row(parent: VBoxContainer, label_text: String, is_weight: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(64, 0)
	row.add_child(label)

	var bar := ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(320, 18)
	bar.show_percentage = false
	row.add_child(bar)

	if is_weight:
		_weight_bar = bar
	else:
		_volume_bar = bar


func _refresh() -> void:
	if _bag == null or _grid == null:
		return

	_weight_bar.max_value = InventoryBag.MAX_WEIGHT_KG
	_weight_bar.value = _bag.get_total_weight()
	_volume_bar.max_value = float(_bag.get_total_cells())
	_volume_bar.value = float(_bag.get_used_cells())

	var speed_percent := int(round(_bag.get_speed_multiplier() * 100.0))
	_speed_label.text = "Movement speed: %d%% (heavier loads slow Kalev down)" % speed_percent

	for index in _cell_buttons.size():
		var cell_x := index % InventoryBag.GRID_WIDTH
		var cell_y := index / InventoryBag.GRID_WIDTH
		var button := _cell_buttons[index]
		var placement := _bag.get_placement_at_cell(cell_x, cell_y)
		_style_cell_button(button, placement, cell_x, cell_y)

	_update_detail_label()


func _style_cell_button(
	button: Button,
	placement: InventoryPlacement,
	cell_x: int,
	cell_y: int
) -> void:
	var is_origin := (
		placement != null
		and placement.grid_x == cell_x
		and placement.grid_y == cell_y
	)
	if placement == null or not is_origin:
		button.text = ""
		button.modulate = Color(0.18, 0.2, 0.24, 0.95)
		button.add_theme_color_override("font_color", Color.WHITE)
		if _selected != null:
			var profile := _profile_for(_selected.item_id)
			if _bag.can_place_at(cell_x, cell_y, profile.grid_width, profile.grid_height, _selected):
				button.modulate = Color(0.24, 0.34, 0.28, 0.95)
		return

	var profile := _profile_for(placement.item_id)
	var record := _item_record(placement.item_id)
	var category := String(record.get("category", "supply"))
	var color: Color = CATEGORY_COLORS.get(category, CATEGORY_COLORS["supply"])
	if not is_origin:
		color = color.darkened(0.12)
		button.text = ""
	else:
		button.text = _short_label(record, placement.quantity)
	button.modulate = color
	if placement == _selected:
		button.modulate = button.modulate.lightened(0.18)
	button.add_theme_color_override("font_color", Color(0.98, 0.98, 0.96))
	button.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)


func _on_cell_pressed(cell_x: int, cell_y: int) -> void:
	if _bag == null:
		return

	var placement := _bag.get_placement_at_cell(cell_x, cell_y)
	if _selected == null:
		if placement != null and placement.grid_x == cell_x and placement.grid_y == cell_y:
			_selected = placement
		_refresh()
		return

	if placement == _selected:
		_selected = null
		_refresh()
		return

	if _bag.try_move(_selected, cell_x, cell_y):
		_selected = null
	_refresh()


func _update_detail_label() -> void:
	if _detail_label == null:
		return
	if _selected == null:
		_detail_label.text = "Select an item to inspect or move it within the bag."
		return

	var record := _item_record(_selected.item_id)
	var profile := _profile_for(_selected.item_id)
	var name_text := String(record.get("name", String(_selected.item_id)))
	_detail_label.text = (
		"%s\n%.2f kg each, %dx%d cells, quantity %d"
		% [name_text, profile.weight_kg, profile.grid_width, profile.grid_height, _selected.quantity]
	)


func _item_record(item_id: StringName) -> Dictionary:
	if _content_db != null and _content_db.is_loaded():
		var record := _content_db.get_item(item_id)
		if not record.is_empty():
			return record
	return {"name": String(item_id), "category": "supply"}


func _profile_for(item_id: StringName) -> ItemCarryProfile:
	return ItemCarryProfile.from_content_record(_item_record(item_id))


func _short_label(record: Dictionary, quantity: int) -> String:
	var name_text := String(record.get("name", "Item"))
	var words := name_text.split(" ", false)
	var short := words[0].substr(0, 3)
	if quantity > 1:
		return "%s x%d" % [short, quantity]
	return short.substr(0, 4)
