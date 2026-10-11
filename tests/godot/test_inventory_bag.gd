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


func test_stackable_items_share_one_cell_and_accumulate_quantity() -> void:
	const STACKABLE_ITEM := &"item.test_stackable_supply"
	var fixture_dir := "user://inventory_stackable_test_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixture_dir))
	var fixture_path := fixture_dir.path_join("item.json")
	var fixture := {
		"type": "item",
		"id": String(STACKABLE_ITEM),
		"category": "supply",
		"gameplay": {
			"stackable": true,
			"carry": {
				"weight_g": 200,
				"grid_width": 1,
				"grid_height": 1,
			},
		},
	}
	var file := FileAccess.open(fixture_path, FileAccess.WRITE)
	assert_true(file != null, "test fixture should be writable")
	if file == null:
		return
	file.store_string(JSON.stringify(fixture))
	file.close()

	var db := ContentDB.new()
	assert_true(db.load_from_directories([fixture_dir]), "temporary item fixture should load")
	var bag := InventoryBag.new()
	bag.set_content_db(db)
	assert_eq(bag.try_add(STACKABLE_ITEM), InventoryBag.AddResult.OK)
	assert_eq(bag.try_add(STACKABLE_ITEM, 2), InventoryBag.AddResult.OK)

	assert_eq(bag.placements.size(), 1, "stackable items share one placement")
	var placement := bag.find_placement(STACKABLE_ITEM)
	assert_true(placement != null)
	if placement != null:
		assert_eq(placement.quantity, 3)
	assert_eq(bag.get_used_cells(), 1, "a stack occupies one grid cell")
	assert_true(is_equal_approx(bag.get_total_weight(), 0.6), "weight includes every stack item")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_dir))


func _bag_with_content() -> InventoryBag:
	return InventoryBag.new()
