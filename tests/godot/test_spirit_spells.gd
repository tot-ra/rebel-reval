extends "res://tests/godot/test_case.gd"

## ADR 0048 / SPL-1 (R-1913): the psychological word spells are one validated catalogue. The five
## starters reproduce today's word spells (SpiritWordSpells slots, element, cost); the loader is
## read-only, deterministic and refuses a broken catalogue instead of publishing half of it.

const BAD_DIR := "user://test_spirit_spells_bad"
## Light each starter element pushes (SPIRIT_SIGHT.md "The seven soul lights").
const STARTER_LIGHT := {
	&"fear": &"aspect.nature",
	&"shame": &"aspect.resonance",
	&"duty": &"aspect.tenacity",
	&"love": &"aspect.unity",
	&"faith": &"aspect.light",
}

var _catalog: SpiritSpellCatalog


func before_each() -> void:
	super.before_each()
	_catalog = SpiritSpellCatalog.new()


func after_each() -> void:
	_remove_bad_dir()
	super.after_each()


func test_catalogue_loads_sixteen_spells_sorted_by_id() -> void:
	assert_true(_catalog.load_catalog(), str(_catalog.errors()))
	assert_eq(_catalog.size(), 16)
	var ids := _catalog.ids()
	var sorted := ids.duplicate()
	sorted.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	assert_eq(ids, sorted)
	for spell_id: StringName in ids:
		assert_true(String(spell_id).begins_with("spell.word."), String(spell_id))
		assert_false(_catalog.lines(spell_id).is_empty(), "%s has default lines" % spell_id)


func test_starters_reproduce_todays_word_spells() -> void:
	assert_true(_catalog.load_catalog())
	var starters := _catalog.starter_ids()
	assert_eq(starters.size(), SpiritWordSpells.SLOT_COUNT)
	for slot in starters.size():
		var record := _catalog.get_spell(starters[slot])
		var element := StringName(String(record["element"]))
		assert_eq(element, SpiritWordSpells.DEFAULT_ELEMENTS[slot], "slot %d element" % slot)
		assert_eq(int(record["cost"]), SpiritWordSpells.WORD_COST, "%s cost" % starters[slot])
		assert_eq(StringName(String(record["kind"])), SpiritSpellCatalog.KIND_LOWERING)
		assert_eq((record["light_vector"] as Array).size(), 1)
		assert_eq(_catalog.light_delta(starters[slot], STARTER_LIGHT[element]), -2)
	assert_eq(starters[0], &"spell.word.intimidate")


func test_kinds_and_deltas_read_from_the_vector() -> void:
	assert_true(_catalog.load_catalog())
	assert_eq(_catalog.light_delta(&"spell.word.praise", &"aspect.unity"), 1)
	assert_eq(_catalog.light_delta(&"spell.word.praise", &"aspect.nature"), 0)
	assert_eq(_catalog.light_delta(&"spell.word.gaslighting", &"aspect.awareness"), -2)
	assert_eq(
		_catalog.ids_for_element(&"fear"),
		[&"spell.word.comfort", &"spell.word.dark_humour", &"spell.word.intimidate"]
	)
	assert_eq(
		_catalog.ids_for_element(&"fear", SpiritSpellCatalog.KIND_RAISING), [&"spell.word.comfort"]
	)
	var gaslighting := _catalog.get_spell(&"spell.word.gaslighting")
	assert_eq(int(gaslighting["guilt"]["church"]), 1)
	assert_false(_catalog.lines(&"spell.word.gaslighting", "weak").is_empty())
	assert_true(_catalog.lines(&"spell.word.gaslighting", "topic.none").is_empty())


func test_returned_records_are_copies() -> void:
	assert_true(_catalog.load_catalog())
	var record := _catalog.get_spell(&"spell.word.praise")
	record["cost"] = 99
	(record["lines"]["default"] as Array).clear()
	assert_eq(int(_catalog.get_spell(&"spell.word.praise")["cost"]), 1)
	assert_false(_catalog.lines(&"spell.word.praise").is_empty())
	assert_true(_catalog.get_spell(&"spell.word.missing").is_empty())


func test_missing_directory_fails_with_reason() -> void:
	assert_false(_catalog.load_catalog("res://content/no_such_spells"))
	assert_eq(_catalog.size(), 0)
	assert_eq(_catalog.errors().size(), 1)


func test_broken_record_keeps_nothing() -> void:
	assert_true(_catalog.load_catalog())
	DirAccess.make_dir_recursive_absolute(BAD_DIR)
	var good := FileAccess.get_file_as_string("res://content/spirit_spells/spell.word.praise.json")
	_write(BAD_DIR.path_join("a.json"), good)
	_write(BAD_DIR.path_join("b.json"), good.replace('"default"', '"weak_only"'))
	assert_false(_catalog.load_catalog(BAD_DIR))
	assert_eq(_catalog.size(), 0, "a failed load publishes nothing")
	assert_true(_catalog.errors()[0].contains("default lines"), str(_catalog.errors()))
	_write(BAD_DIR.path_join("b.json"), good)
	assert_false(_catalog.load_catalog(BAD_DIR))
	assert_true(_catalog.errors()[0].contains("duplicate"), str(_catalog.errors()))


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _remove_bad_dir() -> void:
	var dir := DirAccess.open(BAD_DIR)
	if dir == null:
		return
	for entry: String in dir.get_files():
		dir.remove(entry)
	DirAccess.remove_absolute(BAD_DIR)
