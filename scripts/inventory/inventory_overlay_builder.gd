class_name InventoryOverlayBuilder
extends RefCounted

## Builds the inventory overlay node tree so InventoryOverlay stays focused on state.

const EquipmentSilhouetteScene := preload("res://scripts/inventory/equipment_silhouette.gd")
const InventoryGridCellScene := preload("res://scripts/inventory/inventory_grid_cell.gd")
const InventoryOrnamentFrameScene := preload("res://scripts/inventory/inventory_ornament_frame.gd")
const InventoryUiThemeScene := preload("res://scripts/inventory/inventory_ui_theme.gd")

const CELL_SIZE := 60
const CELL_GAP := 6
const PANEL_PADDING := 32
const SILHOUETTE_WIDTH := 330
const DRAG_KIND_BAG := &"bag"
const DRAG_KIND_EQUIPPED := &"equipped"
const HELP_TOOLTIP := (
	"I or Esc closes the bag. Arrows or WASD move the cursor; Enter/Space picks or places. "
	+ "Drag between packed cells and equipment slots, or click twice to move."
)


static func build(host: InventoryOverlay) -> Dictionary:
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# WHY: ignore outside the satchel so selected goods can be dropped into the
	# world, while the panel itself still owns rearrange/equip clicks.
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("margin_left", 48)
	root.add_theme_constant_override("margin_right", 48)
	root.add_theme_constant_override("margin_top", 36)
	root.add_theme_constant_override("margin_bottom", 36)
	host.add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = InventoryUiThemeScene.DIM_SCRIM
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "BagPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.custom_minimum_size = Vector2(1180, 0)
	panel.clip_contents = false
	InventoryUiThemeScene.apply_panel(panel)
	root.add_child(panel)

	# Hearth glow sits behind the contents so the leather panel is not flat.
	panel.add_child(InventoryUiThemeScene.make_panel_glow())

	# Vector brasswork gives the large panel a shaped, game-like silhouette while
	# remaining resolution-independent at every supported UI scale.
	var ornament: Control = InventoryOrnamentFrameScene.new()
	ornament.name = "OrnamentFrame"
	ornament.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(ornament)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", PANEL_PADDING)
	margin.add_theme_constant_override("margin_right", PANEL_PADDING)
	margin.add_theme_constant_override("margin_top", PANEL_PADDING)
	margin.add_theme_constant_override("margin_bottom", PANEL_PADDING)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_child(header)

	var title_column := VBoxContainer.new()
	title_column.add_theme_constant_override("separation", 0)
	title_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_column)

	var title := Label.new()
	title.name = "BagTitle"
	title.text = "Satchel"
	InventoryUiThemeScene.apply_title(title)
	title_column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Kalev's kit - what he carries through Reval"
	InventoryUiThemeScene.apply_subtitle(subtitle)
	title_column.add_child(subtitle)

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

	var body_row := HBoxContainer.new()
	body_row.add_theme_constant_override("separation", 18)
	layout.add_child(body_row)

	var silhouette_panel := PanelContainer.new()
	silhouette_panel.name = "EquipmentPanel"
	InventoryUiThemeScene.apply_section_panel(silhouette_panel)
	body_row.add_child(silhouette_panel)

	var silhouette_column := VBoxContainer.new()
	silhouette_column.add_theme_constant_override("separation", 8)
	silhouette_panel.add_child(silhouette_column)

	var silhouette_caption := Label.new()
	silhouette_caption.text = "KALEV - WORN GEAR"
	silhouette_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	InventoryUiThemeScene.apply_section_caption(silhouette_caption)
	silhouette_column.add_child(silhouette_caption)
	silhouette_column.add_child(InventoryUiThemeScene.make_brass_rule())

	var silhouette: Control = EquipmentSilhouetteScene.new()
	silhouette.custom_minimum_size = Vector2(
		SILHOUETTE_WIDTH,
		CELL_SIZE * InventoryBag.GRID_HEIGHT + CELL_GAP * (InventoryBag.GRID_HEIGHT - 1) - 8
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
	silhouette.configure_icon_provider(Callable(host, "_equipped_item_icon"))
	silhouette.slot_pressed.connect(host._on_equipment_slot_pressed)
	silhouette_column.add_child(silhouette)

	var grid_panel := PanelContainer.new()
	grid_panel.name = "PackedGoodsPanel"
	grid_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	InventoryUiThemeScene.apply_section_panel(grid_panel)
	body_row.add_child(grid_panel)

	var grid_column := VBoxContainer.new()
	grid_column.add_theme_constant_override("separation", 8)
	grid_panel.add_child(grid_column)

	var grid_caption := Label.new()
	grid_caption.text = "PACKED GOODS - 8 × 5"
	InventoryUiThemeScene.apply_section_caption(grid_caption)
	grid_column.add_child(grid_caption)
	grid_column.add_child(InventoryUiThemeScene.make_brass_rule())

	var grid := GridContainer.new()
	grid.columns = InventoryBag.GRID_WIDTH
	grid.add_theme_constant_override("h_separation", CELL_GAP)
	grid.add_theme_constant_override("v_separation", CELL_GAP)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_column.add_child(grid)

	# Load readout lives under the columns so the eye goes gear -> goods -> cost.
	var meters_panel := PanelContainer.new()
	InventoryUiThemeScene.apply_section_panel(meters_panel)
	layout.add_child(meters_panel)

	var meters_column := VBoxContainer.new()
	meters_column.add_theme_constant_override("separation", 6)
	meters_panel.add_child(meters_column)

	var weight_meter := _add_meter_row(meters_column, "Burden")
	var volume_meter := _add_meter_row(meters_column, "Stowage")

	var speed_label := Label.new()
	InventoryUiThemeScene.apply_body(speed_label)
	meters_column.add_child(speed_label)

	var detail_panel := PanelContainer.new()
	InventoryUiThemeScene.apply_section_panel(detail_panel)
	layout.add_child(detail_panel)

	var detail_column := VBoxContainer.new()
	detail_column.add_theme_constant_override("separation", 4)
	detail_panel.add_child(detail_column)

	var detail_title := Label.new()
	detail_title.text = "Nothing in hand"
	InventoryUiThemeScene.apply_detail_title(detail_title)
	detail_column.add_child(detail_title)

	var detail_label := Label.new()
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.custom_minimum_size = Vector2(0, 34)
	InventoryUiThemeScene.apply_body(detail_label)
	detail_column.add_child(detail_label)

	var equip_button := Button.new()
	equip_button.visible = false
	equip_button.focus_mode = Control.FOCUS_NONE
	equip_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	InventoryUiThemeScene.apply_action_button(equip_button)
	equip_button.pressed.connect(host._on_equip_pressed)
	detail_column.add_child(equip_button)

	var hint := Label.new()
	hint.text = "Select a good, then Equip / drag it onto the matching brass socket. Drag packed cells to rearrange."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	InventoryUiThemeScene.apply_hint(hint)
	layout.add_child(hint)

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
			button.add_theme_font_size_override("font_size", 11)
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
		"detail_title": detail_title,
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
