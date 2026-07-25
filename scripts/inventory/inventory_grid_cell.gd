class_name InventoryGridCell
extends Button

## One bag grid cell with click-to-select and drag-and-drop support.

const InventoryUiThemeScene := preload("res://scripts/inventory/inventory_ui_theme.gd")

var grid_x: int = 0
var grid_y: int = 0
var get_drag_placement: Callable = Callable()
var drag_label: Callable = Callable()
var can_drop: Callable = Callable()
var drop: Callable = Callable()

var _badge: Label


func _ready() -> void:
	# WHY: the stack count used to be glued onto the item label ("Spearx2"),
	# which fought with the icon. It now sits in its own corner badge.
	_badge = Label.new()
	_badge.name = "QuantityBadge"
	_badge.visible = false
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	InventoryUiThemeScene.apply_quantity_badge(_badge)
	add_child(_badge)
	_badge.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 3
	)


func set_badge_text(text: String) -> void:
	if _badge == null:
		return
	_badge.text = text
	_badge.visible = not text.is_empty()
	_badge.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 3
	)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not get_drag_placement.is_valid():
		return null
	var placement: Variant = get_drag_placement.call(grid_x, grid_y)
	if placement == null:
		return null
	var label := Label.new()
	if drag_label.is_valid():
		label.text = String(drag_label.call(placement))
	InventoryUiThemeScene.apply_body(label)
	var preview := PanelContainer.new()
	preview.add_theme_stylebox_override(
		"panel", InventoryUiThemeScene.cell_style(InventoryUiThemeScene.PANEL_BG, true, true)
	)
	preview.modulate = Color(1, 1, 1, 0.9)
	preview.add_child(label)
	set_drag_preview(preview)
	return {"kind": &"bag", "placement": placement}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not can_drop.is_valid() or not data is Dictionary:
		return false
	return bool(can_drop.call(grid_x, grid_y, data))


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not drop.is_valid() or not data is Dictionary:
		return
	drop.call(grid_x, grid_y, data)
