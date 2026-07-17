class_name InventoryGridCell
extends Button

## One bag grid cell with click-to-select and drag-and-drop support.

var grid_x: int = 0
var grid_y: int = 0
var get_drag_placement: Callable = Callable()
var drag_label: Callable = Callable()
var can_drop: Callable = Callable()
var drop: Callable = Callable()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not get_drag_placement.is_valid():
		return null
	var placement: Variant = get_drag_placement.call(grid_x, grid_y)
	if placement == null:
		return null
	var preview := Label.new()
	if drag_label.is_valid():
		preview.text = String(drag_label.call(placement))
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
