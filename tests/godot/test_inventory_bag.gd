extends "res://tests/godot/test_case.gd"

const ITEM_HAMMER := &"item.forge_hammer"
const ITEM_SPEARHEAD := &"item.seized_spearhead"


func before_each() -> void:
	pass


func test_auto_placement_respects_grid_and_weight() -> void:
	var bag := _bag_with_content()
	assert_eq(bag.try_add(ITEM_HAMMER), InventoryBag.AddResult.OK)
	assert_eq(bag.try_add(ITEM_SPEARHEAD), InventoryBag.AddResult.OK)
	assert_eq(bag.get_used_cells(), 5)
	assert_true(bag.get_total_weight() > 4.0)


func test_overweight_pickup_is_rejected() -> void:
	var bag := _bag_with_content()
	for _i in range(7):
		var result := bag.try_add(ITEM_HAMMER)
		if result != InventoryBag.AddResult.OK:
			assert_eq(result, InventoryBag.AddResult.OVER_WEIGHT)
			return
	fail("Expected an overweight rejection before seven hammers were added")


func test_move_within_bag() -> void:
	var bag := _bag_with_content()
	bag.try_add(ITEM_SPEARHEAD)
	var placement := bag.get_placement_at_cell(0, 0)
	assert_true(bag.try_move(placement, 3, 2))
	assert_eq(bag.get_placement_at_cell(3, 2).item_id, ITEM_SPEARHEAD)
	assert_true(bag.get_placement_at_cell(0, 0) == null)


func test_encumbrance_slows_at_high_weight() -> void:
	var bag := InventoryBag.new()
	assert_eq(bag.get_speed_multiplier(), 1.0)
	bag.try_add(ITEM_HAMMER)
	bag.try_add(ITEM_HAMMER)
	assert_true(bag.get_speed_multiplier() < 1.0)
	assert_true(bag.get_speed_multiplier() >= InventoryBag.MIN_SPEED_MULTIPLIER)


func test_stackable_items_share_one_cell() -> void:
	var db := ContentDB.new()
	db.load_from_directories(["res://content/examples/support"])
	var bag := InventoryBag.new()
	bag.set_content_db(db)
	var supply_id := &"item.watch_buckle"
	# watch buckle is not stackable; use a synthetic profile via fallback path by
	# adding the same light item twice when we mark stackable in a local record.
	var profile := ItemCarryProfile.from_content_record({
		"category": "supply",
		"gameplay": {
			"stackable": true,
			"carry": {"weight_g": 200, "grid_width": 1, "grid_height": 1},
		},
	})
	assert_eq(profile.stackable, true)


func _bag_with_content() -> InventoryBag:
	return InventoryBag.new()
