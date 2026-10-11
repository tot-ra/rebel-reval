extends "res://tests/godot/test_case.gd"

## ADR 0033 / SD-14: magic answers only in the spirit world. The cookbook refuses
## world casts; the spirit duel casts through the same MagicResolver.

const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const ControllerScript := preload("res://scripts/magic/spellforge_controller.gd")
const ModelScript := preload("res://scripts/magic/spellforge_model.gd")
const HudScript := preload("res://scripts/magic/spellforge_hud.gd")
const DUEL := &"dialogue.test_duel"
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
	_state.set_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER, 12)
	_db = ContentDB.new()
	assert_true(_db.load_from_directories(CONTENT_DIRS))
	var root := Node.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	_runner = RunnerScript.new()
	root.add_child(_runner)
	_duel = SpiritDuel.new()
	_duel.hero_id = &"char.mart"


func _grant(operation: StringName) -> void:
	assert_true(MagicResolver.apply_grant_operation(_state, _db, operation))


func test_the_cookbook_refuses_world_casts_and_allows_them_in_the_spirit_world() -> void:
	_grant(&"magic.grant.starter_fireball")
	var model := ModelScript.new() as SpellforgeModel
	model.configure(_state, _db)
	var hud := HudScript.new() as SpellforgeHud
	hud.configure(model)
	var controller := ControllerScript.new() as SpellforgeController
	controller.set("_model", model)
	controller.set("_hud", hud)
	var tree := Engine.get_main_loop() as SceneTree
	var host := Node2D.new()
	tree.root.add_child(host)
	var caster := Node2D.new()
	host.add_child(caster)
	host.add_child(hud)
	controller.set("_caster", caster)

	controller.call("_cast_learned_slot", 0)
	assert_eq(model.feedback_text(), "Magic answers only in the spirit world.")
	assert_eq(_state.get_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER), 12)
	assert_eq(host.get_child_count(), 2, "no delivery node in the physical world")

	_state.in_spirit_world = true
	controller.call("_cast_learned_slot", 0)
	assert_eq(model.feedback_text(), "Fireball cast.")
	assert_eq(_state.get_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER), 10)
	hud.free()
	controller.free()
	host.free()


func test_duels_and_observations_open_and_close_the_spirit_world() -> void:
	assert_false(_state.in_spirit_world)
	assert_true(_duel.begin(_runner, _db, _state, DUEL))
	assert_true(_state.in_spirit_world)
	_duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_true(_duel.answer("deny"))
	assert_false(_state.in_spirit_world, "the duel is over")
	var watch := SpiritObservation.new()
	assert_true(watch.begin(_runner, _db, _state, DUEL))
	assert_true(_state.in_spirit_world)
	watch.play_all()
	assert_false(_state.in_spirit_world)
	assert_false(SpiritDuel.new().begin(_runner, _db, _state, &"dialogue.test_runner.intro"))
	assert_false(_state.in_spirit_world)


func test_a_fireball_in_the_arena_costs_willpower_and_adds_pressure() -> void:
	_grant(&"magic.grant.starter_fireball")
	assert_true(_duel.begin(_runner, _db, _state, DUEL))
	var result := _duel.cast_spell(&"spell.pagan.fireball")
	assert_true(result["ok"])
	assert_eq(result["arena_effect"], &"pressure")
	assert_almost_eq(_duel.opponent.health, SpiritDuel.PRESSURE_MAX - 12.0 * 1.5, 0.001)
	assert_eq(_state.get_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER), 10)


func test_casting_obeys_grants_resources_and_phase() -> void:
	assert_true(_duel.begin(_runner, _db, _state, DUEL))
	assert_eq(_duel.cast_spell(&"spell.pagan.fireball")["reason"], MagicResolver.FAILURE_LOCKED)
	_grant(&"magic.grant.starter_fireball")
	_state.set_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER, 1)
	assert_eq(
		_duel.cast_spell(&"spell.pagan.fireball")["reason"],
		MagicResolver.FAILURE_INSUFFICIENT_WILLPOWER
	)
	_state.set_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER, 12)
	_duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_true(_duel.cast_spell(&"spell.pagan.fireball")["ok"], "allowed while choosing a reply")
	assert_true(_duel.answer("deny"))
	assert_false(_duel.cast_spell(&"spell.pagan.fireball")["ok"], "not after the duel")


func test_iron_skin_softens_the_next_blow() -> void:
	_grant(&"magic.grant.starter_iron_skin")
	assert_true(_duel.begin(_runner, _db, _state, DUEL))
	var result := _duel.cast_spell(&"spell.pagan.iron_skin")
	assert_eq(result["arena_effect"], &"buff")
	_duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_almost_eq(_duel.hero.health, SpiritDuel.COMPOSURE_MAX - 20.0 * 0.65, 0.001)


func test_air_gust_staggers_the_opponent_for_one_blow() -> void:
	_grant(&"magic.grant.starter_air_gust")
	assert_true(_duel.begin(_runner, _db, _state, DUEL))
	assert_eq(_duel.cast_spell(&"spell.pagan.air_gust")["arena_effect"], &"stagger")
	_duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_almost_eq(_duel.hero.health, SpiritDuel.COMPOSURE_MAX - 10.0, 0.001)


func test_healing_mist_restores_composure_and_a_summon_has_no_arena_effect() -> void:
	_grant(&"magic.grant.starter_healing_mist")
	_grant(&"magic.grant.starter_illusionary_double")
	assert_true(_duel.begin(_runner, _db, _state, DUEL))
	_duel.hero.health = 50.0
	assert_eq(_duel.cast_spell(&"spell.pagan.healing_mist")["arena_effect"], &"heal")
	assert_almost_eq(_duel.hero.health, 50.0 + SpiritDuel.SPELL_HEAL_COMPOSURE, 0.001)
	assert_eq(_duel.cast_spell(&"spell.pagan.illusionary_double")["arena_effect"], &"none")


func test_the_open_arena_is_a_modal_overlay_and_leaves_it_on_close() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var host := SpiritArenaHost.new()
	host.duel.hero_id = &"char.mart"
	host.freeze_world = false
	tree.root.add_child(host)
	assert_eq(tree.get_nodes_in_group(&"modal_input_overlay").size(), 0)
	assert_true(host.open_scripted(_db, _state, DUEL))
	assert_eq(tree.get_nodes_in_group(&"modal_input_overlay").size(), 1)
	assert_true(_state.in_spirit_world)
	host.close()
	assert_eq(tree.get_nodes_in_group(&"modal_input_overlay").size(), 0)
	host.free()


## SS-7 (ADR 0041): closing ends the encounter but the hero stays in spirit sight, which is
## still the spirit world; leaving sight leaves it.
func test_closing_an_arena_mid_duel_ends_the_encounter_and_returns_to_sight() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var host := SpiritArenaHost.new()
	host.duel.hero_id = &"char.mart"
	host.freeze_world = false
	tree.root.add_child(host)
	assert_true(host.open_scripted(_db, _state, DUEL))
	assert_true(_state.spirit_encounter_active)
	host.close()
	assert_false(_state.spirit_encounter_active)
	assert_true(_state.spirit_sight and _state.in_spirit_world)
	_state.spirit_sight = false
	assert_false(_state.in_spirit_world)
	host.free()
