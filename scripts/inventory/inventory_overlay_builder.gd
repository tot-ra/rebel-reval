class_name InventoryOverlayBuilder
extends RefCounted

## Builds the inventory overlay node tree so InventoryOverlay stays focused on state.

const EquipmentSilhouetteScene := preload("res://scripts/inventory/equipment_silhouette.gd")
const InventoryGridCellScene := preload("res://scripts/inventory/inventory_grid_cell.gd")

const CELL_SIZE := 48
const CELL_GAP := 4
const PANEL_PADDING := 16
const SILHOUETTE_WIDTH := 148
const DRAG_KIND_BAG := &"bag"
const DRAG_KIND_EQUIPPED := &"equipped"


static func build(host: InventoryOverlay) -> Dictionary:
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 48)
	root.add_theme_constant_override("margin_right", 48)
	root.add_theme_constant_override("margin_top", 36)
	root.add_theme_constant_override("margin_bottom", 36)
	host.add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.05, 0.08, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", PANEL_PADDING)
	margin.add_theme_constant_override("margin_right", PANEL_PADDING)
	margin.add_theme_constant_override("margin_top", PANEL_PADDING)
	margin.add_theme_constant_override("margin_bottom", PANEL_PADDING)
	panel.add_child(margin)

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

	var weight_bar := _add_meter_row(layout, "Weight")
	var volume_bar := _add_meter_row(layout, "Volume")

	var speed_label := Label.new()
	speed_label.add_theme_font_size_override("font_size", 13)
	layout.add_child(speed_label)

	var body_row := HBoxContainer.new()
	body_row.add_theme_constant_override("separation", 16)
	layout.add_child(body_row)

	var silhouette: Control = EquipmentSilhouetteScene.new()
	silhouette.custom_minimum_size = Vector2(
		SILHOUETTE_WIDTH,
		CELL_SIZE * InventoryBag.GRID_HEIGHT + CELL_GAP * (InventoryBag.GRID_HEIGHT - 1)
	)
	silhouette.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	silhouette.configure_drop_handlers(
		Callable(host, "_can_drop_on_slot"),
		Callable(host, "_drop_on_slot"),
		Callable(host, "_equipped_item_label"),
		DRAG_KIND_BAG,
		DRAG_KIND_EQUIPPED
	)
	silhouette.slot_pressed.connect(host._on_equipment_slot_pressed)
	body_row.add_child(silhouette)

	var grid_column := VBoxContainer.new()
	grid_column.add_theme_constant_override("separation", 4)
	body_row.add_child(grid_column)

	var grid_caption := Label.new()
	grid_caption.text = "Packed items"
	grid_caption.add_theme_font_size_override("font_size", 13)
	grid_caption.modulate = Color(0.78, 0.80, 0.84)
	grid_column.add_child(grid_caption)

	var grid := GridContainer.new()
	grid.columns = InventoryBag.GRID_WIDTH
	grid.add_theme_constant_override("h_separation", CELL_GAP)
	grid.add_theme_constant_override("v_separation", CELL_GAP)
	grid_column.add_child(grid)

	var detail_label := Label.new()
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.add_theme_font_size_override("font_size", 13)
	layout.add_child(detail_label)

	var equip_button := Button.new()
	equip_button.visible = false
	equip_button.focus_mode = Control.FOCUS_NONE
	equip_button.pressed.connect(host._on_equip_pressed)
	layout.add_child(equip_button)

	var cell_buttons: Array[Button] = []
	for cell_y in range(InventoryBag.GRID_HEIGHT):
		for cell_x in range(InventoryBag.GRID_WIDTH):
			var button: Button = InventoryGridCellScene.new()
			button.set("grid_x", cell_x)
			button.set("grid_y", cell_y)
			button.set("get_drag_placement", Callable(host, "get_origin_placement_at"))
			button.set("drag_label", Callable(host, "item_short_label"))
			button.set("can_drop", Callable(host, "can_drop_on_cell"))
			button.set("drop", Callable(host, "drop_on_cell"))
			button.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
			button.toggle_mode = false
			button.focus_mode = Control.FOCUS_NONE
			var captured_x := cell_x
			var captured_y := cell_y
			button.pressed.connect(func() -> void:
				host._on_cell_pressed(captured_x, captured_y)
			)
			grid.add_child(button)
			cell_buttons.append(button)

	return {
		"panel": panel,
		"grid": grid,
		"silhouette": silhouette,
		"weight_bar": weight_bar,
		"volume_bar": volume_bar,
		"speed_label": speed_label,
		"detail_label": detail_label,
		"equip_button": equip_button,
		"cell_buttons": cell_buttons,
	}


static func _add_meter_row(parent: VBoxContainer, label_text: String) -> ProgressBar:
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
	return bar
