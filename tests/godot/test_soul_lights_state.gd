extends "res://tests/godot/test_case.gd"
## SS-8 (R-1491, ADR 0041 section 6): hero soul lights are NATURAL ranks seen through
## bands; the apprentice's new-game baseline; awareness sets the spirit-sight radius.

const Aura := preload("res://scripts/combat/spirit_aura_profile.gd")
const NATURE := &"aspect.nature"
const UNITY := &"aspect.unity"
const AWARENESS := &"aspect.awareness"
const HERO := &"char.apprentice"


func test_new_game_starts_with_the_apprentice_baseline() -> void:
	var state := GameState.new_apprentice_game()
	var expected_ranks := {
		NATURE: 10, &"aspect.affection": 5, &"aspect.tenacity": 5, UNITY: 10,
		&"aspect.resonance": 5, AWARENESS: 15, &"aspect.light": 5,
	}
	var expected_levels := {
		NATURE: 2, &"aspect.affection": 1, &"aspect.tenacity": 1, UNITY: 2,
		&"aspect.resonance": 1, AWARENESS: 3, &"aspect.light": 1,
	}
	var profile := Aura.from_record(HERO, {}, state)
	for aspect: StringName in GameState.NATURAL_ASPECT_IDS:
		assert_eq(state.get_natural_aspect_rank(aspect), expected_ranks[aspect], String(aspect))
		assert_eq(profile.levels[aspect], expected_levels[aspect], String(aspect))
	# The first-allocation rules are untouched: no free points, flag still open.
	assert_eq(state.get_natural_unspent_points(), 0)
	assert_false(state.get_flag(&"flag.natural.initial_allocation"))


func test_bare_state_stays_neutral() -> void:
	# Loader, presets and scratch states build on GameState.new(); none gets the gift.
	var state := GameState.new()
	for aspect: StringName in GameState.NATURAL_ASPECT_IDS:
		assert_eq(state.get_natural_aspect_rank(aspect), GameState.NATURAL_ASPECT_BASELINE)


func test_band_edges_and_locked_aspect() -> void:
	var cases := [
		[0, 0], [4, 0], [5, 1], [9, 1], [10, 2], [14, 2],
		[15, 3], [24, 3], [25, 4], [39, 4], [40, 5], [50, 5],
	]
	for pair: Array in cases:
		assert_eq(Aura.level_for_rank(int(pair[0])), int(pair[1]), "rank %d" % int(pair[0]))
	assert_eq(Aura.level_for_rank(50, true), 0, "a locked aspect is a closed light")


func test_spending_a_point_crosses_a_band() -> void:
	var state := GameState.new_apprentice_game()
	assert_true(state.grant_natural_points(5))
	for i in 4:
		assert_eq(state.spend_natural_point(NATURE), &"")
	assert_eq(state.get_natural_aspect_rank(NATURE), 14)
	assert_eq(Aura.from_record(HERO, {}, state).levels[NATURE], 2, "rank 14 is still level 2")
	assert_eq(state.spend_natural_point(NATURE), &"")
	assert_eq(Aura.from_record(HERO, {}, state).levels[NATURE], 3, "rank 15 crosses into 3")


func test_save_load_round_trip_keeps_ranks() -> void:
	var state := GameState.new_apprentice_game()
	assert_true(state.grant_natural_points(1))
	assert_eq(state.spend_natural_point(AWARENESS), &"")
	var restored := GameState.new()
	assert_eq(restored.load_payload(state.save_payload()), [])
	assert_eq(restored.get_natural_aspects(), state.get_natural_aspects())
	assert_eq(restored.get_natural_aspect_rank(AWARENESS), 16)
	assert_eq(
		Aura.from_record(HERO, {}, restored).levels, Aura.from_record(HERO, {}, state).levels
	)


func test_old_save_keeps_its_stored_ranks() -> void:
	# A Kalev-era save has flat ranks (or no natural section at all); loading never
	# applies the apprentice baseline on top of it.
	var old := GameState.new()
	var payload := old.save_payload()
	var flat := GameState.new()
	assert_eq(flat.load_payload(payload), [])
	assert_eq(flat.get_natural_aspect_rank(AWARENESS), 5)
	assert_eq(flat.get_natural_aspect_rank(NATURE), 5)
	payload.erase("natural")
	var missing := GameState.new_apprentice_game()
	assert_eq(missing.load_payload(payload), [])
	for aspect: StringName in GameState.NATURAL_ASPECT_IDS:
		assert_eq(missing.get_natural_aspect_rank(aspect), GameState.NATURAL_ASPECT_BASELINE)


func test_awareness_sets_the_sight_radius() -> void:
	var expected := {0: 12.0, 1: 12.0, 2: 12.0, 3: 16.0, 4: 20.0, 5: 24.0}
	for level: int in expected:
		assert_almost_eq(Aura.sight_radius_for_level(level), float(expected[level]), 0.0001)
	assert_eq(Aura.hero_awareness_level(null), 1)
	var state := GameState.new_apprentice_game()
	assert_eq(Aura.hero_awareness_level(state), 3)
	assert_almost_eq(
		Aura.sight_radius_for_level(Aura.hero_awareness_level(state)), 16.0, 0.0001,
		"the apprentice starts seeing auras out to 16 m"
	)
	assert_true(state.grant_natural_points(10))
	for i in 10:
		assert_eq(state.spend_natural_point(AWARENESS), &"")
	assert_almost_eq(Aura.sight_radius_for_level(Aura.hero_awareness_level(state)), 20.0, 0.0001)
