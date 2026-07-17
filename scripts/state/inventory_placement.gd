class_name InventoryPlacement
extends RefCounted

var item_id: StringName = &""
var grid_x: int = 0
var grid_y: int = 0
var quantity: int = 1


func _init(
	item: StringName = &"",
	x: int = 0,
	y: int = 0,
	count: int = 1
) -> void:
	item_id = item
	grid_x = x
	grid_y = y
	quantity = maxi(1, count)
