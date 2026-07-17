class_name InventoryOverlay
extends CanvasLayer

const EquipmentSilhouetteScene := preload("res://scripts/inventory/equipment_silhouette.gd")
const InventoryGridCellScene := preload("res://scripts/inventory/inventory_grid_cell.gd")

signal closed()

const CELL_SIZE := 48
const CELL_GAP := 4
const PANEL_PADDING := 16
const SILHOUETTE_WIDTH := 148

const DRAG_KIND_BAG := &"bag"
const DRAG_KIND_EQUIPPED := &"equipped"

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
var _state: GameState
var _selected: InventoryPlacement = null
var _focus_cell := Vector2i.ZERO

var _panel: PanelContainer
var _grid: GridContainer
var _silhouette: Control
var _weight_bar: ProgressBar
var _volume_bar: ProgressBar
var _speed_label: Label
var _detail_label: Label
var _equip_button: Button
var _cell_buttons: Array[Button] = []


func configure(bag: InventoryBag, content_db: ContentDB) -> void:
	_bag = bag
	_content_db = content_db
	if is_node_ready():
		_refresh()


## Optional: enables the equip/unequip UI backed by GameState placement rules.
func configure_state(state: GameState) -> void:
	_state = state
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
	_focus_cell = Vector2i.ZERO
	_refresh()


func close() -> void:
	visible = false
	_selected = null
	closed.emit()


func is_open() -> bool:
	return visible


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.is_echo():
		return

	var delta := _navigation_delta_for_key(key_event.keycode)
	if delta != Vector2i.ZERO:
		_move_focus(delta)
		get_viewport().set_input_as_handled()
		return

	match key_event.keycode:
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_on_cell_pressed(_focus_cell.x, _focus_cell.y)
			get_viewport().set_input_as_handled()


func _navigation_delta_for_key(keycode: Key) -> Vector2i:
	match keycode:
		KEY_UP, KEY_W:
			return Vector2i(0, -1)
		KEY_DOWN, KEY_S:
			return Vector2i(0, 1)
		KEY_LEFT, KEY_A:
			return Vector2i(-1, 0)
		KEY_RIGHT, KEY_D:
			return Vector2i(1, 0)
		_:
			return Vector2i.ZERO


func _move_focus(delta: Vector2i) -> void:
	_focus_cell.x = clampi(_focus_cell.x + delta.x, 0, InventoryBag.GRID_WIDTH - 1)
	_focus_cell.y = clampi(_focus_cell.y + delta.y, 0, InventoryBag.GRID_HEIGHT - 1)
	_refresh()


func get_origin_placement_at(cell_x: int, cell_y: int) -> InventoryPlacement:
	if _bag == null:
		return null
	var placement := _bag.get_placement_at_cell(cell_x, cell_y)
	if placement != null and placement.grid_x == cell_x and placement.grid_y == cell_y:
		return placement
	return null


func item_short_label(placement: InventoryPlacement) -> String:
	return _short_label(_item_record(placement.item_id), placement.quantity)


func can_drop_on_cell(cell_x: int, cell_y: int, data: Dictionary) -> bool:
	if _bag == null:
		return false
	var kind: StringName = data.get("kind", &"")
	if kind == DRAG_KIND_BAG:
		var placement: InventoryPlacement = data.get("placement")
		if placement == null:
			return false
		var profile := _profile_for(placement.item_id)
		return _bag.can_place_at(cell_x, cell_y, profile.grid_width, profile.grid_height, placement)
	if kind == DRAG_KIND_EQUIPPED:
		var item_id: StringName = data.get("item_id", &"")
		if String(item_id).is_empty():
			return false
		var profile := _profile_for(item_id)
		return _bag.can_place_at(cell_x, cell_y, profile.grid_width, profile.grid_height, null)
	return false


func drop_on_cell(cell_x: int, cell_y: int, data: Dictionary) -> void:
	if _bag == null:
		return
	var kind: StringName = data.get("kind", &"")
	if kind == DRAG_KIND_BAG:
		var placement: InventoryPlacement = data.get("placement")
		if placement != null and _bag.try_move(placement, cell_x, cell_y):
			_selected = null
	elif kind == DRAG_KIND_EQUIPPED and _state != null:
		var slot: StringName = data.get("slot", &"")
		var item_id: StringName = data.get("item_id", &"")
		if slot.is_empty() or item_id.is_empty():
			return
		if not _state.unequip_to_bag(slot):
			return
		var placement := _bag.find_placement(item_id)
		if placement != null:
			_bag.try_move(placement, cell_x, cell_y)
		_selected = null
	_refresh()


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
	hint.text = (
		"I or Esc to close. Arrows or WASD move selection; Enter/Space picks or places. "
		+ "Drag items between the bag and hand slots, or click cells to move them."
	)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color(0.82, 0.84, 0.88)
	layout.add_child(hint)

	_add_meter_row(layout, "Weight", true)
	_add_meter_row(layout, "Volume", false)

	_speed_label = Label.new()
	_speed_label.add_theme_font_size_override("font_size", 13)
	layout.add_child(_speed_label)

	var body_row := HBoxContainer.new()
	body_row.add_theme_constant_override("separation", 16)
	layout.add_child(body_row)

	_silhouette = EquipmentSilhouetteScene.new()
	_silhouette.custom_minimum_size = Vector2(SILHOUETTE_WIDTH, CELL_SIZE * InventoryBag.GRID_HEIGHT + CELL_GAP * (InventoryBag.GRID_HEIGHT - 1))
	_silhouette.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_silhouette.configure_drop_handlers(
		Callable(self, "_can_drop_on_slot"),
		Callable(self, "_drop_on_slot"),
		Callable(self, "_equipped_item_label"),
		DRAG_KIND_BAG,
		DRAG_KIND_EQUIPPED
	)
	_silhouette.slot_pressed.connect(_on_equipment_slot_pressed)
	body_row.add_child(_silhouette)

	var grid_column := VBoxContainer.new()
	grid_column.add_theme_constant_override("separation", 4)
	body_row.add_child(grid_column)

	var grid_caption := Label.new()
	grid_caption.text = "Packed items"
	grid_caption.add_theme_font_size_override("font_size", 13)
	grid_caption.modulate = Color(0.78, 0.80, 0.84)
	grid_column.add_child(grid_caption)

	_grid = GridContainer.new()
	_grid.columns = InventoryBag.GRID_WIDTH
	_grid.add_theme_constant_override("h_separation", CELL_GAP)
	_grid.add_theme_constant_override("v_separation", CELL_GAP)
	grid_column.add_child(_grid)

	_detail_label = Label.new()
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.add_theme_font_size_override("font_size", 13)
	layout.add_child(_detail_label)

	_equip_button = Button.new()
	_equip_button.visible = false
	_equip_button.focus_mode = Control.FOCUS_NONE
	_equip_button.pressed.connect(_on_equip_pressed)
	layout.add_child(_equip_button)

	for cell_y in range(InventoryBag.GRID_HEIGHT):
		for cell_x in range(InventoryBag.GRID_WIDTH):
			var button: Button = InventoryGridCellScene.new()
			button.set("grid_x", cell_x)
			button.set("grid_y", cell_y)
			button.set("get_drag_placement", Callable(self, "get_origin_placement_at"))
			button.set("drag_label", Callable(self, "item_short_label"))
			button.set("can_drop", Callable(self, "can_drop_on_cell"))
			button.set("drop", Callable(self, "drop_on_cell"))
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
	_weight_bar.value = _bag.get_total_weight() + _bag.reserved_weight_kg
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
	_refresh_equipment_ui()


func _refresh_equipment_ui() -> void:
	_equip_button.visible = false
	if _silhouette == null:
		return

	var equipped: Dictionary[StringName, StringName] = {}
	if _state != null:
		for slot: StringName in EquipmentSilhouetteScene.SLOT_ORDER:
			var item_id := _state.equipped_item(slot)
			if not String(item_id).is_empty():
				equipped[slot] = item_id
	_silhouette.set_equipped(equipped)

	if _selected != null:
		var equip_info := _equip_info(_selected.item_id)
		if not equip_info.is_empty():
			_equip_button.visible = true
			_equip_button.text = "Equip %s (%s)" % [
				String(_item_record(_selected.item_id).get("name", "item")),
				String(equip_info.get("slot", "")).replace("_", " "),
			]


func _can_drop_on_slot(slot: StringName, data: Dictionary) -> bool:
	if _state == null:
		return false
	var kind: StringName = data.get("kind", &"")
	if kind == DRAG_KIND_BAG:
		var placement: InventoryPlacement = data.get("placement")
		if placement == null:
			return false
		return _slot_accepts_item(slot, placement.item_id)
	if kind == DRAG_KIND_EQUIPPED:
		var from_slot: StringName = data.get("slot", &"")
		var item_id: StringName = data.get("item_id", &"")
		if from_slot == slot or String(item_id).is_empty():
			return false
		return _slot_accepts_item(slot, item_id)
	return false


func _drop_on_slot(slot: StringName, data: Dictionary) -> void:
	if _state == null:
		return
	var kind: StringName = data.get("kind", &"")
	if kind == DRAG_KIND_BAG:
		var placement: InventoryPlacement = data.get("placement")
		if placement != null and _state.equip_from_bag(slot, placement.item_id):
			_selected = null
	elif kind == DRAG_KIND_EQUIPPED:
		var from_slot: StringName = data.get("slot", &"")
		var item_id: StringName = data.get("item_id", &"")
		if from_slot.is_empty() or from_slot == slot:
			return
		if not _state.unequip_to_bag(from_slot):
			return
		if not _state.equip_from_bag(slot, item_id):
			_state.equip_from_bag(from_slot, item_id)
		_selected = null
	_refresh()


func _slot_accepts_item(slot: StringName, item_id: StringName) -> bool:
	var equip_info := _equip_info(item_id)
	if equip_info.is_empty():
		return false
	return StringName(String(equip_info.get("slot", ""))) == slot


func _on_equipment_slot_pressed(slot: StringName) -> void:
	if _state == null:
		return
	if not String(_state.equipped_item(slot)).is_empty():
		_state.unequip_to_bag(slot)
		_selected = null
		_refresh()
		return
	if _selected != null and _slot_accepts_item(slot, _selected.item_id):
		if _state.equip_from_bag(slot, _selected.item_id):
			_selected = null
			_refresh()


func _equipped_item_label(item_id: StringName) -> String:
	var record := _item_record(item_id)
	return String(record.get("name", String(item_id)))


func _on_equip_pressed() -> void:
	if _state == null or _selected == null:
		return
	var equip_info := _equip_info(_selected.item_id)
	if equip_info.is_empty():
		return
	var slot := StringName(String(equip_info.get("slot", "")))
	if _state.equip_from_bag(slot, _selected.item_id):
		_selected = null
	_refresh()


func _equip_info(item_id: StringName) -> Dictionary:
	var record := _item_record(item_id)
	var gameplay: Dictionary = record.get("gameplay", {})
	return gameplay.get("equip", {})


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
		if Vector2i(cell_x, cell_y) == _focus_cell:
			button.modulate = button.modulate.lightened(0.14)
		return

	var record := _item_record(placement.item_id)
	var category := String(record.get("category", "supply"))
	var color: Color = CATEGORY_COLORS.get(category, CATEGORY_COLORS["supply"])
	button.text = _short_label(record, placement.quantity)
	button.modulate = color
	if placement == _selected:
		button.modulate = button.modulate.lightened(0.18)
	if Vector2i(cell_x, cell_y) == _focus_cell:
		button.modulate = button.modulate.lightened(0.14)
	button.add_theme_color_override("font_color", Color(0.98, 0.98, 0.96))
	button.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)


func _on_cell_pressed(cell_x: int, cell_y: int) -> void:
	if _bag == null:
		return

	_focus_cell = Vector2i(cell_x, cell_y)

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
		_detail_label.text = (
			"Select an item to inspect it, drag it onto a hand slot, "
			+ "or use Enter/Space on a destination cell to move it."
		)
		return

	var record := _item_record(_selected.item_id)
	var profile := _profile_for(_selected.item_id)
	var name_text := String(record.get("name", String(_selected.item_id)))
	var equip_hint := ""
	var equip_info := _equip_info(_selected.item_id)
	if not equip_info.is_empty():
		equip_hint = "\nDrag onto the %s slot to wear it." % String(equip_info.get("slot", "")).replace("_", " ")
	_detail_label.text = (
		"%s\n%.2f kg each, %dx%d cells, quantity %d%s"
		% [name_text, profile.weight_kg, profile.grid_width, profile.grid_height, _selected.quantity, equip_hint]
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
