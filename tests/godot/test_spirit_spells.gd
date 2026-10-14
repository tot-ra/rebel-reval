extends "res://tests/godot/test_case.gd"

## ADR 0048 / SPL-1 (R-1913): the psychological word spells are one validated catalogue. The five
## starters reproduce today's word spells (SpiritWordSpells slots, element, cost); the loader is
## read-only, deterministic and refuses a broken catalogue instead of publishing half of it.
## SPL-2 (R-1914): in a duel the spells shift copies of the opponent's lights; lowering deals
## pressure, raising builds trust, and the duel ends broken, eased or left.

const BAD_DIR := "user://test_spirit_spells_bad"
## Light each starter element pushes (SPIRIT_SIGHT.md "The seven soul lights").
const STARTER_LIGHT := {
	&"fear": &"aspect.nature",
	&"shame": &"aspect.resonance",
	&"duty": &"aspect.tenacity",
	&"love": &"aspect.unity",
	&"faith": &"aspect.light",
}

const CITY_DUEL := &"dialogue.city.spirit_duel"
const PORTER_DUEL := &"dialogue.prologue.porter_confrontation"
const DUEL_DIRS: Array[String] = [
	"res://content/dialogue",
	"res://content/prologue",
	"res://content/examples/valid",
	"res://content/examples/support",
]

var _catalog: SpiritSpellCatalog
var _duel_root: Node


func before_each() -> void:
	super.before_each()
	_catalog = SpiritSpellCatalog.new()


func after_each() -> void:
	_remove_bad_dir()
	if is_instance_valid(_duel_root):
		_duel_root.free()
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


func test_duel_copies_the_lights_and_a_spell_shifts_only_the_copy() -> void:
	var aura := _aura(2)
	var duel := _open(CITY_DUEL, aura)
	assert_eq(duel.duel_light(&"aspect.resonance"), 2)
	var result := duel.land_spell(_spell(&"spell.word.praise"), [])
	assert_eq(duel.duel_light(&"aspect.resonance"), 3)
	assert_eq(duel.duel_light(&"aspect.unity"), 3)
	assert_eq(aura.levels[&"aspect.resonance"], 2, "the resident's own lights never move")
	assert_almost_eq(float(result["trust"]), 2.0 * SpiritDuel.TRUST_PER_POINT, 0.001)
	assert_almost_eq(duel.trust, 16.0, 0.001)
	assert_eq(float(result["pressure"]), 0.0, "praise deals no pressure")
	assert_eq(duel.opponent.health, duel.opponent.max_health)


func test_a_starter_free_strike_deals_todays_word() -> void:
	for level: int in [2, 1, 0]:
		var word := _open(CITY_DUEL, _aura(2, {&"aspect.nature": level}))
		var expected := word.land_word(&"fear", [], SpiritWordSpells.WORD_DAMAGE)
		var spell := _open(CITY_DUEL, _aura(2, {&"aspect.nature": level}))
		var result := spell.land_spell(_spell(&"spell.word.intimidate"), [])
		assert_almost_eq(float(result["pressure"]), expected, 0.001, "nature %d" % level)
		assert_eq(spell.duel_light(&"aspect.nature"), maxi(0, level - 2), "clamped at 0")
	assert_almost_eq(SpiritDuel.PRESSURE_PER_POINT * 2.0, SpiritWordSpells.WORD_DAMAGE, 0.001)


func test_a_light_already_full_cannot_rise() -> void:
	var full := _open(CITY_DUEL, _aura(2, {&"aspect.nature": 5}))
	assert_eq(float(full.land_spell(_spell(&"spell.word.comfort"), [])["trust"]), 0.0)
	assert_eq(full.duel_light(&"aspect.nature"), 5)
	var almost := _open(CITY_DUEL, _aura(2, {&"aspect.nature": 4}))
	assert_almost_eq(float(almost.land_spell(_spell(&"spell.word.comfort"), [])["trust"]), 8.0, 0.001)


func test_a_mixed_spell_is_half_pressure_half_trust() -> void:
	var duel := _open(CITY_DUEL, _aura(2))
	var result := duel.land_spell(_spell(&"spell.word.dark_humour"), [])
	assert_almost_eq(float(result["pressure"]), SpiritDuel.PRESSURE_PER_POINT, 0.001)
	assert_almost_eq(float(result["trust"]), SpiritDuel.TRUST_PER_POINT, 0.001)
	assert_eq(duel.duel_light(&"aspect.nature"), 3)
	assert_eq(duel.duel_light(&"aspect.light"), 1)
	assert_almost_eq(SpiritDuel.lowering_share(_spell(&"spell.word.dark_humour")), 0.5, 0.001)
	assert_almost_eq(SpiritDuel.lowering_share(_spell(&"spell.word.intimidate")), 1.0, 0.001)


func test_a_raised_light_makes_its_blows_stronger() -> void:
	var duel := _open(CITY_DUEL, _aura(2))
	assert_almost_eq(duel.light_blow_factor(&"fear"), 1.0, 0.001)
	duel.land_spell(_spell(&"spell.word.comfort"), [])
	assert_almost_eq(duel.light_blow_factor(&"fear"), 1.0 + 2.0 * SpiritDuel.LIGHT_LEVEL_STEP, 0.001)


func test_full_trust_ends_the_duel_eased() -> void:
	var duel := _open(CITY_DUEL, _aura(2))
	for spell_id: StringName in [
		&"spell.word.comfort", &"spell.word.comfort", &"spell.word.shared_prayer",
		&"spell.word.shared_prayer", &"spell.word.praise", &"spell.word.praise",
		&"spell.word.praise", &"spell.word.listen",
	]:
		assert_false(duel.is_over(), "still open before %s" % spell_id)
		duel.land_spell(_spell(spell_id), [])
	assert_true(duel.is_over())
	assert_eq(duel.trust, SpiritDuel.TRUST_MAX)
	assert_eq(duel.phase, SpiritDuel.PHASE_WON)
	assert_eq(duel.ending(), SpiritDuel.ENDING_EASED)
	assert_eq(String(duel.last_outcome["resolution_node_id"]), "resolved_eased")
	assert_false(bool(duel.last_outcome["broken"]))


func test_pressure_zero_ends_the_duel_broken() -> void:
	var duel := _open(CITY_DUEL, _aura(2))
	duel.opponent.health = 4.0
	duel.land_spell(_spell(&"spell.word.intimidate"), [])
	assert_true(duel.is_over())
	assert_eq(duel.ending(), SpiritDuel.ENDING_BROKEN)
	assert_true(bool(duel.last_outcome["broken"]))


func test_leaving_ends_the_duel_left_only_where_authored() -> void:
	var duel := _open(CITY_DUEL, _aura(2))
	assert_true(duel.can_leave())
	assert_true(duel.leave())
	assert_eq(duel.ending(), SpiritDuel.ENDING_LEFT)
	assert_false(duel.can_leave(), "over")
	var porter := _open(PORTER_DUEL, null)
	assert_false(porter.can_leave(), "the prologue duel has no resolved_left")
	assert_false(porter.leave())


func test_the_porter_duel_keeps_its_authored_endings_at_zero_pressure() -> void:
	var porter := _open(PORTER_DUEL, null)
	porter.opponent.health = 1.0
	porter.land_spell(_spell(&"spell.word.intimidate"), [])
	assert_eq(porter.opponent.health, 0.0)
	assert_false(porter.is_over(), "the replies still choose spared, broken or punished")


func test_a_lost_duel_reports_the_lost_ending() -> void:
	var duel := _open(CITY_DUEL, _aura(2))
	duel.hero.health = 1.0
	duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_eq(duel.phase, SpiritDuel.PHASE_LOST)
	assert_eq(duel.ending(), SpiritDuel.ENDING_LOST)


func test_a_retry_restores_the_lights_and_clears_trust() -> void:
	var duel := _open(CITY_DUEL, _aura(2))
	duel.land_spell(_spell(&"spell.word.praise"), [])
	duel.hero.health = 1.0
	duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_true(duel.retry())
	assert_eq(duel.trust, 0.0)
	assert_eq(duel.duel_light(&"aspect.resonance"), 2)


func test_an_answering_raising_spell_builds_trust_instead_of_pressure() -> void:
	var duel := _open(CITY_DUEL, _aura(2))
	duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_eq(duel.phase, SpiritDuel.PHASE_ANSWER)
	var before := duel.opponent.health
	assert_true(duel.answer("calm_family", true, _spell(&"spell.word.listen")))
	assert_eq(duel.opponent.health, before, "a raising answer deals no pressure")
	assert_true(duel.trust > 0.0)
	assert_eq(duel.duel_light(&"aspect.unity"), 3)


func test_an_answering_starter_keeps_todays_reply_pressure() -> void:
	var plain := _open(CITY_DUEL, _aura(2))
	plain.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_true(plain.answer("press_secret", true))
	var spelled := _open(CITY_DUEL, _aura(2))
	spelled.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_true(spelled.answer("press_secret", true, _spell(&"spell.word.reproach")))
	assert_almost_eq(spelled.opponent.health, plain.opponent.health, 0.001)
	assert_eq(spelled.trust, 0.0)


func test_a_dark_spell_records_guilt_once_per_person() -> void:
	var duel := _open(CITY_DUEL, _aura(2))
	duel.opponent_id = &"res.test_baker"
	var church := duel._state.guilt.level(GuiltLedger.SCHOOL_CHURCH)
	duel.land_spell(_spell(&"spell.word.gaslighting"), [])
	duel.land_spell(_spell(&"spell.word.gaslighting"), [])
	assert_eq(duel._state.guilt.level(GuiltLedger.SCHOOL_CHURCH), church + 1, "once per person")
	assert_eq(duel._state.guilt.level(GuiltLedger.SCHOOL_FOLK), 1)
	assert_eq(duel._state.guilt.level(GuiltLedger.SCHOOL_CIVIC), 0)
	duel.opponent_id = &"res.test_cooper"
	duel.land_spell(_spell(&"spell.word.gaslighting"), [])
	assert_eq(duel._state.guilt.level(GuiltLedger.SCHOOL_CHURCH), church + 2, "a second person")
	var praise_church := duel._state.guilt.level(GuiltLedger.SCHOOL_CHURCH)
	duel.land_spell(_spell(&"spell.word.praise"), [])
	assert_eq(duel._state.guilt.level(GuiltLedger.SCHOOL_CHURCH), praise_church, "no guilt record")


func test_word_spell_ids_never_reach_the_pagan_cast_path() -> void:
	var duel := _open(CITY_DUEL, _aura(2))
	var cast := duel.cast_spell(&"spell.word.intimidate")
	assert_false(bool(cast.get("ok", true)))


func _open(dialogue_id: StringName, aura: SpiritAuraProfile) -> SpiritDuel:
	if not is_instance_valid(_duel_root):
		_duel_root = Node.new()
		(Engine.get_main_loop() as SceneTree).root.add_child(_duel_root)
	var db := ContentDB.new()
	assert_true(db.load_from_directories(DUEL_DIRS))
	var runner := DialogueRunner.new()
	_duel_root.add_child(runner)
	var duel := SpiritDuel.new()
	duel.opponent_aura = aura
	assert_true(duel.begin(runner, db, GameState.new(), dialogue_id), String(dialogue_id))
	return duel


func _aura(level: int, overrides: Dictionary = {}) -> SpiritAuraProfile:
	var aura := SpiritAuraProfile.new()
	for light: StringName in SpiritAuraProfile.LIGHT_IDS:
		aura.levels[light] = int(overrides.get(light, level))
	return aura


func _spell(spell_id: StringName) -> Dictionary:
	var spells := SpiritWordSpells.catalog()
	assert_true(spells != null and spells.has_spell(spell_id), String(spell_id))
	return spells.get_spell(spell_id)


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
