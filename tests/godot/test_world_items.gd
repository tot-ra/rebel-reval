extends "res://tests/godot/test_case.gd"

const WORLD_ITEM_SCENE := preload("res://scenes/world/world_item.tscn")

const LOC_SMITHY := &"loc.kalev_smithy"
const OBJ_SPEAR := &"world.spearhead_anvil"
const ITEM_SPEARHEAD := &"item.seized_spearhead"
const ITEM_HAMMER := &"item.forge_hammer"


func test_place_and_take_world_item_round_trip() -> void:
	var state := _state_with_content()
	assert_true(state.place_world_item(LOC_SMITHY, OBJ_SPEAR, ITEM_SPEARHEAD, Vector2(600, 200)))
	assert_true(state.is_world_item_placed(LOC_SMITHY, OBJ_SPEAR))
	assert_eq(state.get_world_items(LOC_SMITHY).size(), 1)
	var taken := state.take_world_item(LOC_SMITHY, OBJ_SPEAR)
	assert_eq(taken.get("item_id"), ITEM_SPEARHEAD)
	assert_false(state.is_world_item_placed(LOC_SMITHY, OBJ_SPEAR))


func test_check_add_reports_capacity_without_mutating_bag() -> void:
	var state := _state_with_content()
	var bag := state.bag
	for _i in range(7):
		if bag.try_add(ITEM_HAMMER) != InventoryBag.AddResult.OK:
			break
	assert_eq(bag.check_add(ITEM_HAMMER), InventoryBag.AddResult.OVER_WEIGHT)
	assert_eq(bag.check_add(ITEM_SPEARHEAD), InventoryBag.AddResult.OVER_WEIGHT)


func test_world_item_contains_logic_point() -> void:
	var root := _make_root()
	var item: WorldItem = WORLD_ITEM_SCENE.instantiate()
	item.configure(OBJ_SPEAR, ITEM_SPEARHEAD, LOC_SMITHY, Vector2(400, 300))
	root.add_child(item)
	assert_true(item.contains_logic_point(Vector2(410, 305)))
	assert_false(item.contains_logic_point(Vector2(500, 500)))
	_cleanup_node(root)


func test_pickup_moves_item_into_bag_and_state() -> void:
	var state := _state_with_content()
	state.place_world_item(LOC_SMITHY, OBJ_SPEAR, ITEM_SPEARHEAD, Vector2(300, 300))

	assert_eq(state.bag.check_add(ITEM_SPEARHEAD), InventoryBag.AddResult.OK)
	assert_true(state.bag.try_add(ITEM_SPEARHEAD) == InventoryBag.AddResult.OK)
	state.add_item(ITEM_SPEARHEAD)
	state.take_world_item(LOC_SMITHY, OBJ_SPEAR)

	assert_false(state.is_world_item_placed(LOC_SMITHY, OBJ_SPEAR))
	assert_true(state.has_item(ITEM_SPEARHEAD))
	assert_eq(state.bag.find_placement(ITEM_SPEARHEAD).item_id, ITEM_SPEARHEAD)


func test_overweight_pickup_stays_in_world() -> void:
	var state := _state_with_content()
	state.place_world_item(LOC_SMITHY, OBJ_SPEAR, ITEM_SPEARHEAD, Vector2(100, 100))
	for _i in range(8):
		var result := state.bag.try_add(ITEM_HAMMER)
		if result == InventoryBag.AddResult.OVER_WEIGHT:
			break
	assert_eq(state.bag.check_add(ITEM_SPEARHEAD), InventoryBag.AddResult.OVER_WEIGHT)
	assert_true(state.is_world_item_placed(LOC_SMITHY, OBJ_SPEAR))


func test_drop_removes_from_bag_and_records_world_item() -> void:
	var state := _state_with_content()
	assert_true(state.bag.try_add(ITEM_SPEARHEAD) == InventoryBag.AddResult.OK)
	var placement := state.bag.find_placement(ITEM_SPEARHEAD)
	assert_true(state.bag.remove(placement))
	assert_true(state.place_world_item(LOC_SMITHY, &"world.dropped.item.seized_spearhead.0", ITEM_SPEARHEAD, Vector2(220, 180)))
	assert_true(state.is_world_item_placed(LOC_SMITHY, &"world.dropped.item.seized_spearhead.0"))
	assert_true(state.bag.find_placement(ITEM_SPEARHEAD) == null)


func _state_with_content() -> GameState:
	var state := GameState.new()
	var db := ContentDB.new()
	db.load_from_directories([
		"res://content/examples/support",
		"res://content/examples/valid",
	])
	state.bag.set_content_db(db)
	return state


func _make_root() -> Node2D:
	var root := Node2D.new()
	(_tree().root as Window).add_child(root)
	return root


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _cleanup_node(node: Node) -> void:
	if is_instance_valid(node):
		node.free()
