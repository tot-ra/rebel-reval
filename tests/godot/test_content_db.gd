extends "res://tests/godot/test_case.gd"

const EXAMPLE_VALID_DIR := "res://content/examples/valid"
const EXAMPLE_SUPPORT_DIR := "res://content/examples/support"

const CHAR_KALEV := &"char.kalev"
const QUEST_MAKERS_MARK := &"quest.makers_mark"
const ITEM_SEIZED_SPEARHEAD := &"item.seized_spearhead"


func _example_dirs() -> Array[String]:
	return [EXAMPLE_VALID_DIR, EXAMPLE_SUPPORT_DIR]


func _make_db() -> ContentDB:
	var db := ContentDB.new()
	assert_true(db.load_from_directories(_example_dirs()), "example corpus should load")
	return db


func test_loads_validated_example_corpus() -> void:
	var db := _make_db()

	assert_true(db.is_loaded())
	assert_eq(db.get_load_errors().size(), 0)
	assert_eq(db.get_record_count(), 12)
	assert_true(db.has_record(CHAR_KALEV))
	assert_true(db.has_record(QUEST_MAKERS_MARK))
	assert_true(db.has_record(ITEM_SEIZED_SPEARHEAD))


func test_lookup_returns_known_records() -> void:
	var db := _make_db()

	var kalev := db.get_character(CHAR_KALEV)
	assert_eq(db.get_last_lookup_result(), ContentDB.LookupResult.OK)
	assert_eq(String(kalev.get("type", "")), ContentDB.TYPE_CHARACTER)
	assert_eq(String(kalev.get("id", "")), String(CHAR_KALEV))
	assert_eq(String(kalev.get("name", "")), "Kalev")

	var quest := db.get_quest(QUEST_MAKERS_MARK)
	assert_eq(db.get_last_lookup_result(), ContentDB.LookupResult.OK)
	assert_eq(String(quest.get("title", "")), "The Maker's Mark")

	var item := db.get_item(ITEM_SEIZED_SPEARHEAD)
	assert_eq(db.get_last_lookup_result(), ContentDB.LookupResult.OK)
	assert_eq(String(item.get("category", "")), "evidence")


func test_lookup_returns_read_only_copies() -> void:
	var db := _make_db()
	var first := db.lookup(CHAR_KALEV)
	first["name"] = "Mutated"
	(first["brief"] as Dictionary)["want"] = "Mutated nested dictionary"
	(first["relationships"] as Array).clear()

	var second := db.lookup(CHAR_KALEV)
	assert_eq(String(second.get("name", "")), "Kalev")
	assert_ne(String((second["brief"] as Dictionary).get("want", "")), "Mutated nested dictionary")
	assert_true((second["relationships"] as Array).size() > 0)


func test_lookup_rejects_missing_ids() -> void:
	var db := _make_db()

	var missing := db.lookup(&"quest.does_not_exist")
	assert_true(missing.is_empty())
	assert_eq(db.get_last_lookup_result(), ContentDB.LookupResult.MISSING_ID)
	assert_false(db.has_record(&"quest.does_not_exist"))


func test_lookup_rejects_malformed_ids() -> void:
	var db := _make_db()

	var bad_space := db.lookup(&"bad item id")
	assert_true(bad_space.is_empty())
	assert_eq(db.get_last_lookup_result(), ContentDB.LookupResult.MALFORMED_ID)

	var bad_upper := db.lookup(&"Quest.Makers_Mark")
	assert_true(bad_upper.is_empty())
	assert_eq(db.get_last_lookup_result(), ContentDB.LookupResult.MALFORMED_ID)

	var empty_id := db.lookup(&"")
	assert_true(empty_id.is_empty())
	assert_eq(db.get_last_lookup_result(), ContentDB.LookupResult.MALFORMED_ID)


func test_typed_lookup_rejects_wrong_record_type() -> void:
	var db := _make_db()

	var wrong_type := db.get_character(QUEST_MAKERS_MARK)
	assert_true(wrong_type.is_empty())
	assert_eq(db.get_last_lookup_result(), ContentDB.LookupResult.TYPE_MISMATCH)


func test_load_rejects_duplicate_ids() -> void:
	var temp_root := "user://content_db_test_duplicate_%d" % Time.get_ticks_msec()
	_write_json(temp_root.path_join("first.json"), {
		"type": "item",
		"id": "item.duplicate_fixture",
		"name": "First",
	})
	_write_json(temp_root.path_join("second.json"), {
		"type": "item",
		"id": "item.duplicate_fixture",
		"name": "Second",
	})

	var db := ContentDB.new()
	assert_false(db.load_from_directories([temp_root]))
	assert_false(db.is_loaded())
	assert_eq(db.get_record_count(), 0)
	assert_true(db.get_load_errors().size() > 0)
	_remove_tree(temp_root)


func test_load_rejects_malformed_record_shape() -> void:
	var temp_root := "user://content_db_test_malformed_%d" % Time.get_ticks_msec()
	_write_json(temp_root.path_join("bad.json"), {
		"type": "item",
		"id": "bad item id",
		"name": "Broken",
	})

	var db := ContentDB.new()
	assert_false(db.load_from_directories([temp_root]))
	assert_false(db.is_loaded())
	assert_eq(db.get_record_count(), 0)
	assert_true(db.get_load_errors().size() > 0)
	_remove_tree(temp_root)


func _write_json(path: String, body: Dictionary) -> void:
	var directory := path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_true(file != null, "fixture file should be writable: %s" % path)
	file.store_string(JSON.stringify(body))


func _remove_tree(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	_remove_absolute_tree(absolute)


func _remove_absolute_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var child := path.path_join(entry)
			if dir.current_is_dir():
				_remove_absolute_tree(child)
			else:
				DirAccess.remove_absolute(child)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)
