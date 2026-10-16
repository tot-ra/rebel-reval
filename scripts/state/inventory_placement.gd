class_name InventoryPlacement
extends RefCounted

var item_id: StringName = &""
var grid_x: int = 0
var grid_y: int = 0
var quantity: int = 1
## Prestige and wear variant id of this stack (`spear_p1_w1`, docs/SYSTEMS/EQUIPMENT_VARIANTS.md),
## "" for the base item. Extra data: `item_id` stays the stable item id.
var variant: StringName = &""


func _init(
	item: StringName = &"", x: int = 0, y: int = 0, count: int = 1, item_variant: StringName = &""
) -> void:
	item_id = item
	grid_x = x
	grid_y = y
	quantity = maxi(1, count)
	variant = item_variant
