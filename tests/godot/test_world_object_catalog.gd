extends "res://tests/godot/test_case.gd"

## Physical-object catalog (content/objects, docs/SYSTEMS/OBJECT_CATALOG.md):
## ContentDB lookup plus the bag rules derived from each object's handling class.

const OBJECTS_DIR := "res://content/objects"
const BAG_HANDLING: Array[String] = ["pocketable", "carry_one_hand"]


func _make_db() -> ContentDB:
	var db := ContentDB.new()
	assert_true(db.load_from_directories([OBJECTS_DIR]), "object catalog should load")
	return db


func _bag_with_catalog() -> InventoryBag:
	var bag := InventoryBag.new()
	bag.set_content_db(_make_db())
	return bag


func test_catalog_loads_and_resolves_world_objects() -> void:
	var db := _make_db()
	assert_eq(db.get_load_errors().size(), 0)
	var record := db.get_world_object(&"obj.rye_bread_loaf")
	assert_false(record.is_empty(), "rye loaf should be catalogued")
	assert_eq(String(record.get("category", "")), "food")
	assert_true(record.has("edible"), "food objects carry an edible block")
	assert_true(db.get_item(&"obj.rye_bread_loaf").is_empty(), "objects are not item records")
	assert_true(db.get_ids_by_type(ContentDB.TYPE_WORLD_OBJECT).size() > 50)


func test_pocketable_object_uses_catalog_mass_and_footprint() -> void:
	var bag := _bag_with_catalog()
	assert_eq(bag.try_add(&"obj.rye_bread_loaf"), InventoryBag.AddResult.OK)
	assert_almost_eq(bag.get_total_weight(), 0.8, 0.001)
	assert_eq(bag.get_used_cells(), 2)


func test_heavy_and_two_handed_objects_are_refused_by_the_bag() -> void:
	var bag := _bag_with_catalog()
	assert_eq(bag.check_add(&"obj.barrel_oak"), InventoryBag.AddResult.NOT_CARRIABLE)
	assert_eq(bag.try_add(&"obj.chest_burgher"), InventoryBag.AddResult.NOT_CARRIABLE)
	assert_eq(bag.try_add(&"obj.cargo_crate"), InventoryBag.AddResult.NOT_CARRIABLE)
	assert_true(bag.is_empty())


func test_stackable_object_honours_its_own_max_stack() -> void:
	var bag := _bag_with_catalog()
	for _i in range(5):
		assert_eq(bag.try_add(&"obj.linen_folded"), InventoryBag.AddResult.OK)
	assert_eq(bag.try_add(&"obj.linen_folded"), InventoryBag.AddResult.STACK_FULL)
	assert_eq(bag.placements.size(), 1)


func test_every_catalogued_object_matches_its_handling_class() -> void:
	var db := _make_db()
	var bag := _bag_with_catalog()
	for object_id in db.get_ids_by_type(ContentDB.TYPE_WORLD_OBJECT):
		var record := db.get_world_object(object_id)
		var handling := String(record.get("handling", ""))
		var baggable := BAG_HANDLING.has(handling)
		assert_eq(record.has("carry"), baggable, "%s carry block vs %s" % [object_id, handling])
		var profile := ItemCarryProfile.from_world_object(record)
		assert_eq(profile.bag_allowed, baggable, "%s bag_allowed" % object_id)
		if handling == "fixed":
			assert_false(
				(record.get("actions", []) as Array).has("take"),
				"%s fixed but takeable" % object_id
			)
		if baggable and bag.check_add(object_id) == InventoryBag.AddResult.NOT_CARRIABLE:
			fail("%s should be bag-carriable" % object_id)
