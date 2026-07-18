class_name InventoryBag
extends RefCounted

## Kalev's worn travel bag: rectangular grid plus a separate weight budget.
## Volume is expressed as occupied cells; weight slows movement when the bag is heavy.

const GRID_WIDTH := 8
const GRID_HEIGHT := 5
const MAX_WEIGHT_KG := 28.0
const MIN_SPEED_MULTIPLIER := 0.65

enum AddResult {
	OK,
	UNKNOWN_ITEM,
	NO_SPACE,
	OVER_WEIGHT,
	STACK_FULL,
}

var placements: Array[InventoryPlacement] = []
## Weight carried outside the grid (equipped items); counts toward the cap
## and encumbrance. Maintained by GameState equipment placement.
var reserved_weight_kg := 0.0
var _occupied: PackedByteArray = PackedByteArray()


func _init() -> void:
	_reset_occupancy()


func is_empty() -> bool:
	return placements.is_empty()


func get_used_cells() -> int:
	var used := 0
	for value in _occupied:
		if value == 1:
			used += 1
	return used


func get_total_cells() -> int:
	return GRID_WIDTH * GRID_HEIGHT


func get_total_weight() -> float:
	var total := 0.0
	for placement in placements:
		var profile := _profile_for(placement.item_id)
		total += profile.total_weight(placement.quantity)
	return total


func get_weight_ratio() -> float:
	if is_zero_approx(MAX_WEIGHT_KG):
		return 0.0
	return clampf((get_total_weight() + reserved_weight_kg) / MAX_WEIGHT_KG, 0.0, 1.0)


func get_speed_multiplier() -> float:
	return lerpf(1.0, MIN_SPEED_MULTIPLIER, get_weight_ratio())


func get_placement_at_cell(cell_x: int, cell_y: int) -> InventoryPlacement:
	if not _cell_in_bounds(cell_x, cell_y):
		return null
	for placement in placements:
		var profile := _profile_for(placement.item_id)
		if _rect_contains(
			placement.grid_x,
			placement.grid_y,
			profile.grid_width,
			profile.grid_height,
			cell_x,
			cell_y
		):
			return placement
	return null


func can_place_at(
	cell_x: int,
	cell_y: int,
	width: int,
	height: int,
	ignore: InventoryPlacement = null
) -> bool:
	if width < 1 or height < 1:
		return false
	if cell_x < 0 or cell_y < 0 or cell_x + width > GRID_WIDTH or cell_y + height > GRID_HEIGHT:
		return false

	for y in range(cell_y, cell_y + height):
		for x in range(cell_x, cell_x + width):
			var occupant := get_placement_at_cell(x, y)
			if occupant != null and occupant != ignore:
				return false
	return true


func check_add(item_id: StringName, quantity: int = 1) -> AddResult:
	if item_id.is_empty():
		return AddResult.UNKNOWN_ITEM

	var profile := _profile_for(item_id)
	var add_count := maxi(1, quantity)

	if profile.stackable:
		for placement in placements:
			if placement.item_id != item_id:
				continue
			var next_quantity := placement.quantity + add_count
			if next_quantity > ItemCarryProfile.MAX_STACK_SIZE:
				return AddResult.STACK_FULL
			var added_weight := profile.weight_kg * add_count
			if get_total_weight() + reserved_weight_kg + added_weight > MAX_WEIGHT_KG + 0.001:
				return AddResult.OVER_WEIGHT
			return AddResult.OK

	var added_weight := profile.total_weight(add_count)
	if get_total_weight() + reserved_weight_kg + added_weight > MAX_WEIGHT_KG + 0.001:
		return AddResult.OVER_WEIGHT
	if _find_auto_placement(profile).x < 0:
		return AddResult.NO_SPACE
	return AddResult.OK


func try_add(item_id: StringName, quantity: int = 1) -> AddResult:
	if item_id.is_empty():
		return AddResult.UNKNOWN_ITEM

	var profile := _profile_for(item_id)
	var add_count := maxi(1, quantity)

	if profile.stackable:
		for placement in placements:
			if placement.item_id != item_id:
				continue
			var next_quantity := placement.quantity + add_count
			if next_quantity > ItemCarryProfile.MAX_STACK_SIZE:
				return AddResult.STACK_FULL
			var added_weight := profile.weight_kg * add_count
			if get_total_weight() + reserved_weight_kg + added_weight > MAX_WEIGHT_KG + 0.001:
				return AddResult.OVER_WEIGHT
			placement.quantity = next_quantity
			return AddResult.OK

	var added_weight := profile.total_weight(add_count)
	if get_total_weight() + reserved_weight_kg + added_weight > MAX_WEIGHT_KG + 0.001:
		return AddResult.OVER_WEIGHT

	var origin := _find_auto_placement(profile)
	if origin.x < 0:
		return AddResult.NO_SPACE

	placements.append(InventoryPlacement.new(item_id, origin.x, origin.y, add_count))
	_rebuild_occupancy()
	return AddResult.OK


func try_move(placement: InventoryPlacement, cell_x: int, cell_y: int) -> bool:
	if placement == null:
		return false
	var profile := _profile_for(placement.item_id)
	if not can_place_at(cell_x, cell_y, profile.grid_width, profile.grid_height, placement):
		return false
	placement.grid_x = cell_x
	placement.grid_y = cell_y
	_rebuild_occupancy()
	return true


func remove(placement: InventoryPlacement) -> bool:
	var index := placements.find(placement)
	if index < 0:
		return false
	placements.remove_at(index)
	_rebuild_occupancy()
	return true


func set_content_db(content_db: ContentDB) -> void:
	_content_db = content_db


## Public carry-stat lookup so equipment state can weigh worn items.
func profile_for(item_id: StringName) -> ItemCarryProfile:
	return _profile_for(item_id)


func find_placement(item_id: StringName) -> InventoryPlacement:
	for placement in placements:
		if placement.item_id == item_id:
			return placement
	return null


var _content_db: ContentDB = null


func _profile_for(item_id: StringName) -> ItemCarryProfile:
	if _content_db != null and _content_db.is_loaded():
		var record: Dictionary = _content_db.get_item(item_id)
		if not record.is_empty():
			return ItemCarryProfile.from_content_record(record)
	return ItemCarryProfile.fallback(item_id)


func _find_auto_placement(profile: ItemCarryProfile) -> Vector2i:
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			if can_place_at(x, y, profile.grid_width, profile.grid_height):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _reset_occupancy() -> void:
	_occupied = PackedByteArray()
	_occupied.resize(get_total_cells())
	_occupied.fill(0)


func _rebuild_occupancy() -> void:
	_reset_occupancy()
	for placement in placements:
		var profile := _profile_for(placement.item_id)
		for y in range(placement.grid_y, placement.grid_y + profile.grid_height):
			for x in range(placement.grid_x, placement.grid_x + profile.grid_width):
				_occupied[_cell_index(x, y)] = 1


func _cell_in_bounds(cell_x: int, cell_y: int) -> bool:
	return cell_x >= 0 and cell_y >= 0 and cell_x < GRID_WIDTH and cell_y < GRID_HEIGHT


func _cell_index(cell_x: int, cell_y: int) -> int:
	return cell_y * GRID_WIDTH + cell_x


static func _rect_contains(
	rect_x: int,
	rect_y: int,
	rect_w: int,
	rect_h: int,
	cell_x: int,
	cell_y: int
) -> bool:
	return (
		cell_x >= rect_x
		and cell_y >= rect_y
		and cell_x < rect_x + rect_w
		and cell_y < rect_y + rect_h
	)
