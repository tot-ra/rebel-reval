extends "res://tests/godot/test_case.gd"

const Aura := preload("res://scripts/combat/spirit_aura_profile.gd")


func test_stable_hash_matches_cross_process_golden_vector() -> void:
	var record := {
		"faction": "faction.guild", "profession": "smith",
		"temperament": ["stubborn", "proud"],
	}
	# Independent Python hashlib SHA-256 vector pins the algorithm across runs.
	var expected := [3, 0, 4, 5, 3, 3, 3]
	var profile := Aura.from_record(&"char.stable", record)
	for i in Aura.LIGHT_IDS.size():
		assert_eq(profile.levels[Aura.LIGHT_IDS[i]], expected[i])
	assert_almost_eq(profile.clarity, 189.0 / 255.0, 0.00001)
	record["temperament"] = ["proud", "stubborn", "proud"]
	assert_eq(Aura.from_record(&"char.stable", record).levels, profile.levels)
	assert_eq(Aura.from_record(&"char.stable", record).clarity, profile.clarity)
	for key: String in ["faction", "profession", "temperament"]:
		var changed := record.duplicate(true)
		changed[key] = ["kind"] if key == "temperament" else "different"
		assert_ne(Aura.from_record(&"char.stable", changed).levels, profile.levels)
	assert_ne(Aura.from_record(&"char.other", record).levels, profile.levels)


func test_missing_records_and_all_generated_values_are_bounded() -> void:
	var db := ContentDB.new()
	for i in 128:
		var profile := Aura.for_character(StringName("char.missing_%d" % i), db)
		assert_eq(profile.levels.size(), 7)
		for value: int in profile.levels.values():
			assert_true(value >= 0 and value <= 5)
		assert_true(profile.clarity >= 0.0 and profile.clarity <= 1.0)
		assert_eq(profile.closed_mask, [])
	assert_eq(
		Aura.for_character(&"char.absent", null).levels,
		Aura.for_character(&"char.absent", db).levels
	)


func test_authored_content_wins_and_returned_profiles_are_independent() -> void:
	var db := ContentDB.new()
	assert_true(db.load_from_directories(["res://content/examples/valid"]))
	var profile := Aura.for_character(&"char.aura_fixture", db)
	var expected := [0, 1, 2, 3, 4, 5, 1]
	for i in Aura.LIGHT_IDS.size():
		assert_eq(profile.levels[Aura.LIGHT_IDS[i]], expected[i])
	assert_almost_eq(profile.clarity, 0.75, 0.00001)
	assert_eq(profile.closed_mask, [&"aspect.nature"])
	profile.levels[&"aspect.nature"] = 5
	profile.closed_mask.clear()
	var again := Aura.for_character(&"char.aura_fixture", db)
	assert_eq(again.levels[&"aspect.nature"], 0)
	assert_eq(again.closed_mask, [&"aspect.nature"])
	var record := db.get_character(&"char.aura_fixture")
	record["aura"].erase("clarity")
	record["aura"].erase("closed_mask")
	record["species"] = "dog"
	var defaults := Aura.from_record(&"char.aura_fixture", record)
	assert_eq(defaults.levels, again.levels)
	assert_almost_eq(defaults.clarity, 1.0, 0.00001)
	assert_eq(defaults.closed_mask, [])


func test_hero_uses_live_natural_and_highest_guilt_tier_in_every_school() -> void:
	var state := GameState.new()
	var baseline := Aura.for_character(&"char.apprentice", null, state)
	for aspect in Aura.LIGHT_IDS:
		assert_eq(baseline.levels[aspect],
			Aura.level_for_rank(state.get_natural_aspect_rank(aspect)))
	for school in GuiltLedger.SCHOOLS:
		for tier in 4:
			# Guilt thresholds are 0 / 1 / 3 / 6, not a sum of the three schools.
			var guilt_values := [0, 1, 3, 6]
			assert_eq(state.guilt.from_dict({
				"version": 1, "levels": {String(school): guilt_values[tier]},
			}), [])
			var profile := Aura.for_character(&"char.apprentice", null, state)
			assert_almost_eq(profile.clarity, 1.0 - float(tier) / 3.0, 0.00001)
			assert_eq(profile.levels, baseline.levels)
	var restored := GameState.new()
	assert_eq(restored.load_payload(state.save_payload()), [])
	assert_almost_eq(Aura.for_character(&"char.apprentice", null, restored).clarity, 0.0, 0.00001)
	assert_almost_eq(Aura.for_character(&"char.apprentice", null).clarity, 1.0, 0.00001)


func test_hero_natural_wins_over_authored_levels_and_survives_save_load() -> void:
	var state := GameState.new()
	var ranks := [0, 5, 10, 15, 25, 40, 50]
	var payload := state.save_payload()
	for i in Aura.LIGHT_IDS.size():
		payload["natural"]["aspects"][String(Aura.LIGHT_IDS[i])] = ranks[i]
	assert_eq(state.load_payload(payload), [])
	state.guilt.record_act(&"act.aura_test", &"act.unarmed_victim", true)
	var authored := {}
	for light in Aura.LIGHT_IDS:
		authored[String(light)] = 0
	var record := {"aura": {"levels": authored, "clarity": 1.0}}
	var profile := Aura.from_record(&"char.apprentice", record, state)
	for i in Aura.LIGHT_IDS.size():
		assert_eq(profile.levels[Aura.LIGHT_IDS[i]], Aura.level_for_rank(ranks[i]))
	assert_almost_eq(profile.clarity, 0.0, 0.00001)
	var restored := GameState.new()
	assert_eq(restored.load_payload(state.save_payload()), [])
	assert_eq(Aura.for_character(&"char.apprentice", null, restored).levels, profile.levels)
	assert_true(state.grant_natural_points(5))
	for i in 5:
		assert_eq(state.spend_natural_point(&"aspect.affection"), &"")
	assert_eq(Aura.for_character(&"char.apprentice", null, state).levels[&"aspect.affection"], 2)
	assert_eq(Aura.from_record(&"char.custom", {"is_player": true}, state).levels,
		Aura.for_character(&"char.apprentice", null, state).levels)


func test_natural_rank_bands_include_all_boundaries_and_locks() -> void:
	assert_eq(Aura.LIGHT_IDS, GameState.NATURAL_ASPECT_IDS)
	var ranks := [-1, 0, 4, 5, 9, 10, 14, 15, 24, 25, 39, 40, 50, 99]
	var expected := [0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 5]
	for i in ranks.size():
		assert_eq(Aura.level_for_rank(ranks[i]), expected[i])
		assert_eq(Aura.level_for_rank(ranks[i], true), 0)


func test_species_are_clear_with_nature_unity_and_optional_awareness() -> void:
	for species: String in ["dog", "horse", "cat", "cow", "pig", "sheep", "goat",
		"chicken", "crow", "rat", "unknown"]:
		var profile := Aura.from_record(&"char.animal", {"species": species})
		assert_almost_eq(profile.clarity, 1.0, 0.00001)
		assert_true(profile.levels[&"aspect.nature"] > 0)
		assert_true(profile.levels[&"aspect.unity"] > 0)
		assert_eq(profile.levels[&"aspect.awareness"] > 0, species in ["dog", "horse"])
		for light: StringName in [&"aspect.affection", &"aspect.tenacity",
			&"aspect.resonance", &"aspect.light"]:
			assert_eq(profile.levels[light], 0)
	assert_eq(Aura.for_species("DOG").levels, Aura.for_species("dog").levels)


func test_element_mapping_is_the_adr_contract() -> void:
	var expected := [&"fear", &"coin", &"duty", &"love", &"shame", &"sight", &"faith"]
	for i in Aura.LIGHT_IDS.size():
		assert_eq(Aura.ELEMENTS[Aura.LIGHT_IDS[i]], expected[i])
