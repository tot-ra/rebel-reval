extends "res://tests/godot/test_case.gd"

## ADR 0033 / SD-15: double-edged hero traits and opponent temperaments.

const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const DUEL := &"dialogue.test_duel"
const TEMPERAMENT_DUEL := &"dialogue.test_duel_temperament"
const CONTENT_DIRS: Array[String] = [
	"res://content/examples/valid",
	"res://content/examples/support",
]

var _state: GameState
var _db: ContentDB
var _runner: Node
var _duel: SpiritDuel


func before_each() -> void:
	super.before_each()
	_state = GameState.new()
	_db = ContentDB.new()
	assert_true(_db.load_from_directories(CONTENT_DIRS))
	var root := Node.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	_runner = RunnerScript.new()
	root.add_child(_runner)
	_duel = SpiritDuel.new()
	_duel.hero_id = &"char.mart"


func test_every_trait_variant_has_a_boon_and_a_cost() -> void:
	for trait_id: StringName in SpiritTraits.TRAITS:
		for origin in SpiritTraits.ORIGINS:
			var variant: Dictionary = SpiritTraits.TRAITS[trait_id][origin]
			assert_true(SpiritTraits.is_double_edged(variant), "%s %s" % [trait_id, origin])


func test_granting_rules_and_save_round_trip() -> void:
	assert_true(_state.grant_trait(&"trait.hears_fear", &"scar"))
	assert_false(_state.grant_trait(&"trait.hears_fear", &"gift"))
	assert_false(_state.grant_trait(&"trait.nonsense", &"gift"))
	assert_false(_state.grant_trait(&"trait.watchful", &"bruise"))
	assert_eq(_state.get_trait_origin(&"trait.hears_fear"), &"scar")
	var restored := GameState.new()
	assert_eq(restored.load_payload(_state.save_payload()), [])
	assert_eq(restored.get_traits(), [&"trait.hears_fear"])
	assert_eq(restored.get_trait_origin(&"trait.hears_fear"), &"scar")
	var legacy := GameState.new().save_payload()
	legacy.erase("traits")
	assert_eq(GameState.new().load_payload(legacy), [])
	var corrupt := GameState.new().save_payload()
	corrupt["traits"] = {"trait.hears_fear": "bruise"}
	assert_true(GameState.new().load_payload(corrupt).size() > 0)


func test_modifiers_combine_across_traits() -> void:
	_state.grant_trait(&"trait.hears_fear", &"scar")
	_state.grant_trait(&"trait.stubborn", &"gift")
	var mods := SpiritTraits.modifiers_for(_state)
	assert_almost_eq(float(mods["composure_delta"]), 5.0, 0.001)
	assert_almost_eq(SpiritTraits.reply_multiplier(mods, &"fear"), 1.1, 0.001)
	assert_almost_eq(SpiritTraits.reply_multiplier(mods, &"shame"), 0.8, 0.001)
	assert_almost_eq(SpiritTraits.incoming_multiplier(mods, &"pressure"), 1.3, 0.001)
	assert_eq(SpiritTraits.reply_multiplier(mods, &"love"), 1.0)
	assert_eq(SpiritTraits.modifiers_for(null)["composure_delta"], 0.0)


func test_a_gifted_reading_of_fear_hits_harder_in_the_arena() -> void:
	_state.grant_trait(&"trait.hears_fear", &"gift")
	assert_true(_duel.begin(_runner, _db, _state, DUEL))
	_duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_true(_duel.answer("deny"))
	# defense counters attack (30), the reply's element is fear (x1.25).
	assert_almost_eq(_duel.opponent.health, SpiritDuel.PRESSURE_MAX - 37.5, 0.001)


func test_a_scar_costs_composure() -> void:
	_state.grant_trait(&"trait.hears_fear", &"scar")
	assert_true(_duel.begin(_runner, _db, _state, DUEL))
	assert_almost_eq(_duel.hero.max_health, SpiritDuel.COMPOSURE_MAX - 10.0, 0.001)


func test_watchfulness_widens_the_parry_window_and_makes_dodging_dearer() -> void:
	assert_true(_duel.begin(_runner, _db, _state, DUEL))
	_duel.tick(SpiritDuel.TELEGRAPH_SEC - 0.22)
	_duel.set_guard(true)
	_duel.tick(0.23)
	assert_eq(_duel.opponent.health, SpiritDuel.PRESSURE_MAX, "no parry without the trait")

	var state := GameState.new()
	state.grant_trait(&"trait.watchful", &"gift")
	var runner2 := RunnerScript.new()
	_runner.get_parent().add_child(runner2)
	var duel2 := SpiritDuel.new()
	duel2.hero_id = &"char.mart"
	assert_true(duel2.begin(runner2, _db, state, DUEL))
	duel2.tick(SpiritDuel.TELEGRAPH_SEC - 0.22)
	duel2.set_guard(true)
	duel2.tick(0.23)
	assert_eq(duel2.opponent.health, SpiritDuel.PRESSURE_MAX - SpiritDuel.PARRY_RETURN_PRESSURE)
	var duel3 := SpiritDuel.new()
	duel3.hero_id = &"char.mart"
	var runner3 := RunnerScript.new()
	_runner.get_parent().add_child(runner3)
	assert_true(duel3.begin(runner3, _db, state, DUEL))
	assert_true(duel3.dodge())
	assert_eq(duel3.hero.stamina, SpiritDuel.RESOLVE_MAX - SpiritDuel.DODGE_RESOLVE_COST - 5.0)


func test_temperament_multipliers_clamp_and_stack() -> void:
	assert_eq(SpiritTraits.temperament_multiplier(["impulsive"], &"defense"), 1.3)
	assert_almost_eq(SpiritTraits.temperament_multiplier(["impulsive"], &"appeal"), 0.7, 0.001)
	assert_eq(SpiritTraits.temperament_multiplier(["impulsive"], &"attack"), 1.0)
	assert_eq(SpiritTraits.temperament_multiplier(["creative", "proud"], &"feint"), 0.78)
	assert_eq(SpiritTraits.temperament_multiplier(["unknown_tag"], &"attack"), 1.0)
	assert_eq(SpiritTraits.temperament_multiplier([], &"attack"), 1.0)


func test_an_impulsive_opponent_falls_for_defense_and_shrugs_off_appeals() -> void:
	assert_true(_duel.begin(_runner, _db, _state, TEMPERAMENT_DUEL))
	_duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_true(_duel.answer("deny"))
	assert_almost_eq(_duel.opponent.health, SpiritDuel.PRESSURE_MAX - 39.0, 0.001)

	var runner2 := RunnerScript.new()
	_runner.get_parent().add_child(runner2)
	var duel2 := SpiritDuel.new()
	duel2.hero_id = &"char.mart"
	assert_true(duel2.begin(runner2, _db, GameState.new(), TEMPERAMENT_DUEL))
	duel2.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_true(duel2.answer("confess"))
	assert_almost_eq(duel2.opponent.health, SpiritDuel.PRESSURE_MAX - 12.0 * 0.7, 0.001)
