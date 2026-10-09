extends "res://tests/godot/test_case.gd"

## SS-5 (ADR 0041 section 5): the opponent's soul lights shape the spirit duel.

const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const DUEL_ID := &"dialogue.test_duel"
const CONTENT_DIRS: Array[String] = [
	"res://content/examples/valid",
	"res://content/examples/support",
]
const NATURE := &"aspect.nature"
const UNITY := &"aspect.unity"
const RESONANCE := &"aspect.resonance"

var _state: GameState
var _db: ContentDB
var _runner: Node


func before_each() -> void:
	super.before_each()
	_state = GameState.new()
	_db = ContentDB.new()
	assert_true(_db.load_from_directories(CONTENT_DIRS))
	var root := Node.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	_runner = RunnerScript.new()
	root.add_child(_runner)


func _profile(level: int, overrides: Dictionary = {}) -> SpiritAuraProfile:
	var profile := SpiritAuraProfile.new()
	for light in SpiritAuraProfile.LIGHT_IDS:
		profile.levels[light] = int(overrides.get(light, level))
	return profile


func _duel(opponent: SpiritAuraProfile = null, hero: SpiritAuraProfile = null) -> SpiritDuel:
	var duel := SpiritDuel.new()
	duel.hero_id = &"char.mart"
	duel.opponent_aura = opponent
	duel.hero_aura = hero
	assert_true(duel.begin(_runner, _db, _state, DUEL_ID))
	return duel


func test_missing_profile_and_neutral_profile_keep_todays_numbers() -> void:
	for profile: SpiritAuraProfile in [null, _profile(2)]:
		var duel := _duel(profile, profile)
		assert_eq(duel.opponent.max_health, SpiritDuel.PRESSURE_MAX)
		duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
		assert_eq(duel.hero.health, SpiritDuel.COMPOSURE_MAX - 20.0)
		assert_true(duel.answer("deny"))
		assert_almost_eq(duel.opponent.health, SpiritDuel.PRESSURE_MAX - 30.0, 0.001)


func test_pressure_pool_scales_with_the_sum_of_levels() -> void:
	assert_almost_eq(_duel(_profile(3)).opponent.max_health, 60.0 * 21.0 / 14.0, 0.001)
	assert_almost_eq(_duel(_profile(1)).opponent.max_health, 30.0, 0.001)
	assert_almost_eq(_duel(_profile(0)).opponent.max_health, 30.0, 0.001, "floored")
	assert_almost_eq(_duel(_profile(5)).opponent.max_health, 120.0, 0.001, "capped")


func test_opponent_blow_uses_the_light_guarding_its_element() -> void:
	# The opening blow is shame; shame is guarded by resonance.
	var strong := _duel(_profile(2, {RESONANCE: 5}))
	strong.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_almost_eq(strong.hero.health, 100.0 - 20.0 * 1.3, 0.001)
	var weak := _duel(_profile(2, {RESONANCE: 0, NATURE: 5}))
	weak.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_almost_eq(weak.hero.health, 100.0 - 20.0 * 0.8, 0.001, "other lights do not matter")


func test_closed_light_takes_words_harder() -> void:
	# deny is a fear word (nature guards fear): defense counters attack = 30.
	var closed := _duel(_profile(2, {NATURE: 0}))
	closed.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_true(closed.answer("deny"))
	assert_almost_eq(closed.opponent.health, closed.opponent.max_health - 30.0 * 1.5, 0.001)
	var dim := _duel(_profile(2, {NATURE: 1}))
	dim.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_true(dim.answer("deny"))
	assert_almost_eq(dim.opponent.health, dim.opponent.max_health - 30.0 * 1.25, 0.001)


func test_hero_light_scales_his_words() -> void:
	var duel := _duel(_profile(2), _profile(2, {NATURE: 5}))
	duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_true(duel.answer("deny"))
	assert_almost_eq(duel.opponent.health, 60.0 - 30.0 * 1.3, 0.001)


func test_combined_product_is_clamped() -> void:
	assert_eq(SpiritDuel.word_product(1.4, 1.4, 1.5, 1.3), SpiritDuel.WORD_PRODUCT_MAX)
	assert_eq(SpiritDuel.word_product(0.6, 0.6, 0.6, 0.8), SpiritDuel.WORD_PRODUCT_MIN)
	assert_almost_eq(SpiritDuel.word_product(1.0, 1.2, 1.0, 1.25), 1.5, 0.0001)
	# Closed light x1.5 with a topic hit x1.5 is 2.25 unclamped: the product caps at x2.
	var duel := _duel(_profile(2, {NATURE: 0}))
	assert_almost_eq(duel.light_word_factor(&"fear"), 1.5, 0.0001)
	assert_eq(SpiritDuel.word_product(1.0, 1.0, SpiritDuel.TOPIC_ON, duel.light_word_factor(&"fear")), 2.0)  # gdlint: ignore=max-line-length


func test_elements_map_to_their_guarding_lights() -> void:
	assert_eq(SpiritDuel.light_for_element(&"fear"), NATURE)
	assert_eq(SpiritDuel.light_for_element(&"love"), UNITY)
	assert_eq(SpiritDuel.light_for_element(&"shame"), RESONANCE)
	assert_eq(SpiritDuel.light_for_element(&"sight"), &"")
	assert_eq(SpiritDuel.light_for_element(&""), &"")
	assert_eq(SpiritDuel.light_level(_profile(0), &"sight"), SpiritDuel.NEUTRAL_LIGHT_LEVEL)


func test_word_spell_gets_the_same_light_scaling() -> void:
	var duel := _duel(_profile(2, {RESONANCE: 0}))
	duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	var landed := duel.land_word(&"shame", [], 10.0)
	assert_almost_eq(landed, 15.0, 0.001)
	var neutral := _duel()
	neutral.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_almost_eq(neutral.land_word(&"shame", [], 10.0), 10.0, 0.001)


func test_spells_through_magic_resolver_get_no_light_multiplier() -> void:
	# A cast_spell damage impact is amount x SPELL_DAMAGE_SCALE whatever the lights say.
	var closed := _duel(_profile(0))
	var neutral := _duel()
	assert_true(closed.light_word_factor(&"shame") > 1.0, "the word path sees the closed light")
	for duel: SpiritDuel in [closed, neutral]:
		duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	var source := FileAccess.get_file_as_string("res://scripts/combat/spirit_duel.gd")
	var cast_body := source.substr(source.find("func cast_spell"), source.find("func retry") - source.find("func cast_spell"))  # gdlint: ignore=max-line-length
	assert_false(cast_body.contains("light_"), "cast_spell applies no light factor")


func test_determinism() -> void:
	var results: Array[float] = []
	for _run in 2:
		var duel := _duel(_profile(3, {NATURE: 0}), _profile(4))
		duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
		duel.answer("deny")
		results.append(duel.opponent.health)
		results.append(duel.hero.health)
	assert_eq(results[0], results[2])
	assert_eq(results[1], results[3])


func test_aura_view_dims_the_hit_light_and_recovers() -> void:
	var view := SpiritAuraView.new()
	view.set_profile(_profile(3))
	view.dim_light(NATURE)
	assert_almost_eq(view.light_dim[0], 1.0, 0.001)
	assert_almost_eq(view.light_dim[1], 0.0, 0.001)
	view._tick_duel_feedback(10.0)
	assert_almost_eq(view.light_dim[0], 0.0, 0.001, "recovers")
	view.free()


func test_falling_pressure_lowers_clarity_and_a_break_shatters() -> void:
	var view := SpiritAuraView.new()
	view.set_profile(_profile(3))
	assert_almost_eq(view.effective_clarity(), 1.0, 0.001)
	view.set_pressure_fraction(0.0)
	assert_almost_eq(view.effective_clarity(), SpiritAuraView.PRESSURE_CLARITY_FLOOR, 0.001)
	view.shatter_now()
	view._tick_duel_feedback(SpiritAuraView.SHATTER_SEC + 0.1)
	assert_almost_eq(view.shatter, 1.0, 0.001)
	assert_almost_eq(view.turbulence(), 1.0, 0.001)
	view.dim_light(NATURE)
	assert_almost_eq(view.light_dim[0], 0.0, 0.001, "a shattered aura takes no more dimming")
	view.free()


func test_duel_drives_the_aura_view() -> void:
	var view := SpiritAuraView.new()
	view.set_profile(_profile(2))
	var duel := _duel(_profile(2))
	view.bind_duel(duel)
	duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_true(duel.answer("deny"))
	assert_almost_eq(view.light_dim[0], 1.0, 0.001, "the fear word dimmed the nature light")
	assert_true(view.pressure_fraction < 1.0)
	view.unbind_duel()
	view.free()


func test_element_colors_follow_the_soul_light_palette() -> void:
	var colors := SpiritSpellCard.ELEMENT_COLORS
	assert_true(colors["fear"].r > 0.8 and colors["fear"].g < 0.3, "fear red")
	assert_true(colors["coin"].r > 0.9 and colors["coin"].g > 0.45 and colors["coin"].b < 0.3, "coin orange")  # gdlint: ignore=max-line-length
	assert_true(colors["duty"].r > 0.9 and colors["duty"].g > 0.8, "duty yellow")
	assert_true(colors["love"].g > colors["love"].r and colors["love"].g > colors["love"].b, "love green")  # gdlint: ignore=max-line-length
	assert_true(colors["shame"].b > colors["shame"].r and colors["shame"].b > 0.8, "shame blue")
	assert_true(colors["faith"].b > colors["faith"].g and colors["faith"].r > colors["faith"].g, "faith violet")  # gdlint: ignore=max-line-length
