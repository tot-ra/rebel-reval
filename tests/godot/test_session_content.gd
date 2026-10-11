extends "res://tests/godot/test_case.gd"

const ITEM_SPEARHEAD := &"item.seized_spearhead"


func test_demo_content_dirs_load_without_duplicate_ids() -> void:
	var db := ContentDB.new()
	assert_true(
		db.load_from_directories(SessionState.DEMO_CONTENT_DIRS),
		"session demo dirs must load: %s" % ", ".join(db.get_load_errors())
	)
	assert_true(db.is_loaded())
	assert_eq(db.get_load_errors().size(), 0)


func test_seized_spearhead_exposes_equip_metadata_after_session_load() -> void:
	var db := ContentDB.new()
	assert_true(db.load_from_directories(SessionState.DEMO_CONTENT_DIRS))

	var item := db.get_item(ITEM_SPEARHEAD)
	var equip: Dictionary = item.get("gameplay", {}).get("equip", {})
	assert_false(equip.is_empty(), "spearhead must be equipable once content loads")
	assert_eq(StringName(String(equip.get("slot", ""))), &"left_hand")
	assert_eq(
		String(equip.get("scene", "")),
		"res://assets/characters/shared/spear.tscn"
	)
