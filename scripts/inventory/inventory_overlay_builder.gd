class_name InventoryOverlayBuilder
extends RefCounted

## Builds the inventory overlay node tree so InventoryOverlay stays focused on state.

const EquipmentSilhouetteScene := preload("res://scripts/inventory/equipment_silhouette.gd")
const InventoryGridCellScene := preload("res://scripts/inventory/inventory_grid_cell.gd")

const CELL_SIZE := 52
const CELL_GAP := 4
const PANEL_PADDING := 18
const SILHOUETTE_WIDTH := 176
const DRAG_KIND_BAG := &"bag"
const DRAG_KIND_EQUIPPED := &"equipped"
const HELP_TOOLTIP := (
	"I or Esc closes the bag. Arrows or WASD move the cursor; Enter/Space picks or places. "
	+ "Drag between packed cells and equipment slots, or click twice to move."
)


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
	panel.custom_minimum_size = Vector2(720, 0)
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", PANEL_PADDING)
	margin.add_theme_constant_override("margin_right", PANEL_PADDING)
	margin.add_theme_constant_override("margin_top", PANEL_PADDING)
	margin.add_theme_constant_override("margin_bottom", PANEL_PADDING)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	layout.add_child(header)

	var title := Label.new()
	title.text = "Bag"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.92, 0.82, 0.56, 1.0))
	header.add_child(title)

	var help_button := Button.new()
	help_button.text = "?"
	help_button.tooltip_text = HELP_TOOLTIP
	help_button.focus_mode = Control.FOCUS_NONE
	help_button.custom_minimum_size = Vector2(32, 28)
	header.add_child(help_button)

	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "Close"
	close_button.tooltip_text = "Close bag (I or Esc)"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(host.close)
	header.add_child(close_button)

	var hint := Label.new()
	hint.text = "Click or drag to move. Hover ? for controls."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color(0.78, 0.80, 0.84)
	layout.add_child(hint)

	var weight_meter := _add_meter_row(layout, "Weight")
	var volume_meter := _add_meter_row(layout, "Volume")

	var speed_label := Label.new()
	speed_label.add_theme_font_size_override("font_size", 13)
	layout.add_child(speed_label)

	var body_row := HBoxContainer.new()
	body_row.add_theme_constant_override("separation", 18)
	layout.add_child(body_row)

	var silhouette_column := VBoxContainer.new()
	silhouette_column.add_theme_constant_override("separation", 4)
	body_row.add_child(silhouette_column)

	var silhouette_caption := Label.new()
	silhouette_caption.text = "Worn"
	silhouette_caption.add_theme_font_size_override("font_size", 13)
	silhouette_caption.modulate = Color(0.78, 0.80, 0.84)
	silhouette_column.add_child(silhouette_caption)

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
		Callable(host, "_equipped_slot_short_label"),
		DRAG_KIND_BAG,
		DRAG_KIND_EQUIPPED
	)
	silhouette.slot_pressed.connect(host._on_equipment_slot_pressed)
	silhouette_column.add_child(silhouette)

	var grid_column := VBoxContainer.new()
	grid_column.add_theme_constant_override("separation", 4)
	grid_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	detail_label.custom_minimum_size = Vector2(0, 48)
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
			button.clip_text = true
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
		"weight_bar": weight_meter["bar"],
		"weight_value": weight_meter["value"],
		"volume_bar": volume_meter["bar"],
		"volume_value": volume_meter["value"],
		"speed_label": speed_label,
		"detail_label": detail_label,
		"equip_button": equip_button,
		"cell_buttons": cell_buttons,
	}


static func _add_meter_row(parent: VBoxContainer, label_text: String) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(64, 0)
	row.add_child(label)

	var bar := ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(280, 18)
	bar.show_percentage = false
	row.add_child(bar)

	var value := Label.new()
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.custom_minimum_size = Vector2(118, 0)
	value.add_theme_font_size_override("font_size", 12)
	value.modulate = Color(0.86, 0.88, 0.90)
	row.add_child(value)
	return {"bar": bar, "value": value}
