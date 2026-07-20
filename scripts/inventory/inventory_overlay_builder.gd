class_name InventoryOverlayBuilder
extends RefCounted

## Builds the inventory overlay node tree so InventoryOverlay stays focused on state.

const EquipmentSilhouetteScene := preload("res://scripts/inventory/equipment_silhouette.gd")
const InventoryGridCellScene := preload("res://scripts/inventory/inventory_grid_cell.gd")
const InventoryUiThemeScene := preload("res://scripts/inventory/inventory_ui_theme.gd")

const CELL_SIZE := 52
const CELL_GAP := 4
const PANEL_PADDING := 20
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
	dim.color = InventoryUiThemeScene.DIM_SCRIM
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "BagPanel"
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.custom_minimum_size = Vector2(740, 0)
	InventoryUiThemeScene.apply_panel(panel)
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
	title.name = "BagTitle"
	title.text = "Satchel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	InventoryUiThemeScene.apply_title(title)
	header.add_child(title)

	var help_button := Button.new()
	help_button.text = "?"
	help_button.tooltip_text = HELP_TOOLTIP
	help_button.focus_mode = Control.FOCUS_NONE
	help_button.custom_minimum_size = Vector2(32, 28)
	InventoryUiThemeScene.apply_action_button(help_button)
	header.add_child(help_button)

	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "Close"
	close_button.tooltip_text = "Close bag (I or Esc)"
	close_button.focus_mode = Control.FOCUS_NONE
	InventoryUiThemeScene.apply_action_button(close_button)
	close_button.pressed.connect(host.close)
	header.add_child(close_button)

	layout.add_child(InventoryUiThemeScene.make_brass_rule())

	var hint := Label.new()
	hint.text = "Click or drag to stow. Hover ? for controls."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	InventoryUiThemeScene.apply_hint(hint)
	layout.add_child(hint)

	var weight_meter := _add_meter_row(layout, "Burden")
	var volume_meter := _add_meter_row(layout, "Stowage")

	var speed_label := Label.new()
	InventoryUiThemeScene.apply_body(speed_label)
	layout.add_child(speed_label)

	var body_row := HBoxContainer.new()
	body_row.add_theme_constant_override("separation", 20)
	layout.add_child(body_row)

	var silhouette_column := VBoxContainer.new()
	silhouette_column.add_theme_constant_override("separation", 6)
	body_row.add_child(silhouette_column)

	var silhouette_caption := Label.new()
	silhouette_caption.text = "Worn gear"
	InventoryUiThemeScene.apply_caption(silhouette_caption)
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
	grid_column.add_theme_constant_override("separation", 6)
	grid_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_row.add_child(grid_column)

	var grid_caption := Label.new()
	grid_caption.text = "Packed goods"
	InventoryUiThemeScene.apply_caption(grid_caption)
	grid_column.add_child(grid_caption)

	var grid := GridContainer.new()
	grid.columns = InventoryBag.GRID_WIDTH
	grid.add_theme_constant_override("h_separation", CELL_GAP)
	grid.add_theme_constant_override("v_separation", CELL_GAP)
	grid_column.add_child(grid)

	layout.add_child(InventoryUiThemeScene.make_brass_rule())

	var detail_label := Label.new()
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.custom_minimum_size = Vector2(0, 48)
	InventoryUiThemeScene.apply_body(detail_label)
	layout.add_child(detail_label)

	var equip_button := Button.new()
	equip_button.visible = false
	equip_button.focus_mode = Control.FOCUS_NONE
	InventoryUiThemeScene.apply_action_button(equip_button)
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
			InventoryUiThemeScene.apply_cell_button(
				button,
				InventoryUiThemeScene.LEATHER_EMPTY,
				false,
				false
			)
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
	label.custom_minimum_size = Vector2(72, 0)
	InventoryUiThemeScene.apply_meter_label(label)
	row.add_child(label)

	var bar := ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(280, 18)
	bar.show_percentage = false
	InventoryUiThemeScene.apply_progress_bar(bar)
	row.add_child(bar)

	var value := Label.new()
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.custom_minimum_size = Vector2(118, 0)
	InventoryUiThemeScene.apply_meter_value(value)
	row.add_child(value)
	return {"bar": bar, "value": value}
