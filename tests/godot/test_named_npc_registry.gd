extends "res://tests/godot/test_case.gd"

## The named-NPC registry loader (docs/SYSTEMS/NAMED_NPCS.md, task R-1562).

const BAD_PATH := "user://named_npcs_bad_faction.json"


func test_loads_the_registry() -> void:
	var registry := NamedNpcRegistry.load_default()
	assert_true(registry.errors.is_empty(), "; ".join(registry.errors))
	assert_true(registry.count() >= 8, "Wave A at least, got %d" % registry.count())
	assert_true(registry.has_npc("char.konrad_preen"))


func test_lookup_by_id_and_faction() -> void:
	var registry := NamedNpcRegistry.load_default()
	var konrad := registry.get_npc("char.konrad_preen")
	assert_eq(konrad.get("faction"), "faction.danish_crown")
	assert_true(registry.get_npc("char.nobody").is_empty())
	var crown := registry.by_faction("faction.danish_crown")
	assert_true(crown.size() >= 2, "Konrad and the guard captain")
	for npc in crown:
		assert_eq(npc["faction"], "faction.danish_crown")


func test_post_at_follows_the_schedule() -> void:
	var registry := NamedNpcRegistry.load_default()
	assert_eq(registry.post_at("char.johann_von_minden", 10.0)["anchor"], "poi.forum")
	assert_eq(registry.post_at("char.johann_von_minden", 2.0)["anchor"], NamedNpcRegistry.HOME)
	var after := registry.post_at("char.johann_von_minden", 14.0)
	assert_eq(after["anchor"], "poi.granary.pikk")
	assert_eq(after["prev_anchor"], NamedNpcRegistry.HOME, "lunch at home between posts")
	assert_true(registry.post_at("char.nobody", 10.0).is_empty())


func test_bad_faction_fails_to_load() -> void:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(NamedNpcRegistry.DATA_PATH))
	raw["npcs"][0]["faction"] = "faction.lizard_union"
	var file := FileAccess.open(BAD_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()
	var registry := NamedNpcRegistry.new()
	assert_false(registry.load_file(BAD_PATH))
	assert_eq(registry.count(), 0, "a broken registry loads nothing")
	assert_true("; ".join(registry.errors).contains("unknown faction"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(BAD_PATH))


func test_census_linked_twice_fails_to_load() -> void:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(NamedNpcRegistry.DATA_PATH))
	for i in 2:
		raw["npcs"][i]["census_mode"] = "replaces"
		raw["npcs"][i]["census_id"] = "cit.lt.inst_town_hall.009"
	var file := FileAccess.open(BAD_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()
	var registry := NamedNpcRegistry.new()
	assert_false(registry.load_file(BAD_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(BAD_PATH))
