extends "res://tests/godot/test_case.gd"

const ITEM_HAMMER := &"item.forge_hammer"
const ITEM_SWORD := &"item.plain_sword"
const ITEM_SPEARHEAD := &"item.seized_spearhead"


func test_equip_moves_item_out_of_grid_but_keeps_its_weight() -> void:
	var state := GameState.new()
	state.bag.try_add(ITEM_HAMMER)
	var grid_weight := state.bag.get_total_weight()
	var cells_before := state.bag.get_used_cells()
	assert_true(cells_before > 0)

	assert_true(state.equip_from_bag(&"right_hand", ITEM_HAMMER))
	assert_eq(state.equipped_item(&"right_hand"), ITEM_HAMMER)
	assert_eq(state.bag.get_used_cells(), 0, "equipped items leave the grid")
	assert_true(
		is_equal_approx(state.get_carried_weight(), grid_weight),
		"worn weight still counts toward the cap"
	)
	assert_true(
		state.bag.get_speed_multiplier() < 1.0,
		"encumbrance covers worn items too"
	)


func test_unequip_returns_item_to_grid() -> void:
	var state := GameState.new()
	state.bag.try_add(ITEM_HAMMER)
	state.equip_from_bag(&"right_hand", ITEM_HAMMER)

	assert_true(state.unequip_to_bag(&"right_hand"))
	assert_eq(state.equipped_item(&"right_hand"), &"")
	assert_true(state.bag.get_used_cells() > 0)
	assert_true(is_zero_approx(state.bag.reserved_weight_kg))


func test_unequip_into_full_grid_is_rejected_without_mutation() -> void:
	var state := GameState.new()
	state.bag.try_add(ITEM_HAMMER)
	state.equip_from_bag(&"right_hand", ITEM_HAMMER)
	# Fill the freed grid so the hammer has nowhere to go back to.
	while state.bag.try_add(ITEM_SPEARHEAD) == InventoryBag.AddResult.OK:
		pass

	var cells := state.bag.get_used_cells()
	assert_false(state.unequip_to_bag(&"right_hand"))
	assert_eq(state.equipped_item(&"right_hand"), ITEM_HAMMER, "failed unequip keeps the item worn")
	assert_eq(state.bag.get_used_cells(), cells, "failed unequip must not disturb the grid")
	assert_true(
		is_equal_approx(state.bag.reserved_weight_kg, state.bag.profile_for(ITEM_HAMMER).weight_kg),
		"failed unequip must restore reserved weight"
	)


func test_equipping_over_occupied_slot_swaps_back_to_bag() -> void:
	var state := GameState.new()
	state.bag.try_add(ITEM_HAMMER)
	state.bag.try_add(ITEM_SPEARHEAD)
	state.equip_from_bag(&"right_hand", ITEM_HAMMER)

	assert_true(state.equip_from_bag(&"right_hand", ITEM_SPEARHEAD))
	assert_eq(state.equipped_item(&"right_hand"), ITEM_SPEARHEAD)
	assert_true(
		state.bag.find_placement(ITEM_HAMMER) != null,
		"previous occupant returns to the grid"
	)


func test_spearhead_equips_to_left_hand_while_hammer_stays_worn() -> void:
	var state := GameState.new()
	state.bag.try_add(ITEM_HAMMER)
	state.bag.try_add(ITEM_SPEARHEAD)
	state.equip_from_bag(&"right_hand", ITEM_HAMMER)

	assert_true(state.equip_from_bag(&"left_hand", ITEM_SPEARHEAD))
	assert_eq(state.equipped_item(&"right_hand"), ITEM_HAMMER)
	assert_eq(state.equipped_item(&"left_hand"), ITEM_SPEARHEAD)
	assert_eq(state.bag.get_used_cells(), 0)


func test_sword_carry_and_equip_metadata_drive_inventory_state() -> void:
	var db := ContentDB.new()
	assert_true(db.load_from_directories(SessionState.DEMO_CONTENT_DIRS))
	var item := db.get_item(ITEM_SWORD)
	var gameplay: Dictionary = item.get("gameplay", {})
	var equip: Dictionary = gameplay.get("equip", {})
	var state := GameState.new()
	state.bag.set_content_db(db)

	assert_eq(String(item.get("category", "")), "weapon")
	assert_eq(StringName(String(equip.get("slot", ""))), &"right_hand")
	assert_eq(String(equip.get("scene", "")), "res://assets/characters/shared/sword.tscn")
	assert_eq(state.bag.profile_for(ITEM_SWORD).grid_width, 1)
	assert_eq(state.bag.profile_for(ITEM_SWORD).grid_height, 4)
	assert_true(is_equal_approx(state.bag.profile_for(ITEM_SWORD).weight_kg, 1.45))
	assert_eq(state.bag.try_add(ITEM_SWORD), InventoryBag.AddResult.OK)
	assert_true(state.equip_from_bag(&"right_hand", ITEM_SWORD))
	assert_eq(state.equipped_item(&"right_hand"), ITEM_SWORD)


func test_equipment_changed_signal_fires_per_slot() -> void:
	var state := GameState.new()
	state.bag.try_add(ITEM_HAMMER)
	var changed_slots: Array[StringName] = []
	state.equipment_changed.connect(func(slot: StringName) -> void:
		changed_slots.append(slot)
	)
	state.equip_from_bag(&"right_hand", ITEM_HAMMER)
	state.unequip_to_bag(&"right_hand")
	assert_eq(changed_slots, [&"right_hand", &"right_hand"])


func test_worn_weight_blocks_new_pickups_at_the_cap() -> void:
	var state := GameState.new()
	var equipped := 0
	# Wear hammers on every slot the schema allows until the cap area, then
	# confirm the bag refuses weight the grid alone would have accepted.
	for slot: StringName in [&"right_hand", &"left_hand", &"head", &"back"]:
		if state.bag.try_add(ITEM_HAMMER) != InventoryBag.AddResult.OK:
			break
		if state.equip_from_bag(slot, ITEM_HAMMER):
			equipped += 1
	assert_eq(equipped, 4, "four worn hammers keep the grid empty")
	assert_eq(state.bag.get_used_cells(), 0)

	var rejected := false
	for _i in range(8):
		var result := state.bag.try_add(ITEM_HAMMER)
		if result == InventoryBag.AddResult.OVER_WEIGHT:
			rejected = true
			break
		if result != InventoryBag.AddResult.OK:
			break
	assert_true(rejected, "worn weight must count against pickups")
