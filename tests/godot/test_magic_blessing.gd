extends "res://tests/godot/test_case.gd"

## R-718 Divine Blessing: fixed rite self outgoing-damage buff.

const CONTENT_DIRS: Array[String] = [
	"res://content/examples/valid",
	"res://content/examples/support",
]
const BLESSING := &"rite.blessing"
const GRANT_BLESSING := &"magic.grant.starter_blessing"
const MODIFIER := &"modifier.blessing"
const CAST_EXECUTOR := preload("res://scripts/magic/magic_cast_executor_2d.gd")
const DUMMY_SCRIPT := preload("res://scripts/combat/combat_training_dummy.gd")
const MODEL_SCRIPT := preload("res://scripts/magic/spellforge_model.gd")
const COMBAT_SCRIPTS: Array[String] = [
	"res://scripts/player.gd",
	"res://scripts/combat/combat_vitals.gd",
	"res://scripts/combat/combat_timed_modifiers.gd",
	"res://scripts/combat/combat_room_enemy.gd",
	"res://scripts/combat/melee_attack_resolver.gd",
	"res://scripts/magic/magic_cast_executor_2d.gd",
]


func _granted_state(db: ContentDB, piety: int) -> GameState:
	var state := GameState.new()
	state.set_magic_resource(GameState.MAGIC_RESOURCE_PIETY, piety)
	assert_true(MagicResolver.apply_grant_operation(state, db, GRANT_BLESSING))
	return state


func _make_db() -> ContentDB:
	var db := ContentDB.new()
	assert_true(db.load_from_directories(CONTENT_DIRS))
	return db


func _add_dummy(host: Node2D, position := Vector2.ZERO) -> CombatTestDummy:
	var dummy := DUMMY_SCRIPT.new() as CombatTestDummy
	host.add_child(dummy)
	dummy.position = position
	dummy.configure_resources(100.0, 100.0, 100.0, 100.0)
	return dummy


func _make_host() -> Node2D:
	var host := Node2D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	return host


func _cast_on(state: GameState, db: ContentDB, caster: Node2D, host: Node2D) -> void:
	var result := MagicResolver.cast(state, db, BLESSING)
	assert_true(CAST_EXECUTOR.execute(result, caster, Vector2.RIGHT, host) == caster)


func test_blessing_resolves_to_self_bonus_and_spends_piety() -> void:
	var db := _make_db()
	var state := _granted_state(db, 2)
	var result := MagicResolver.cast(state, db, BLESSING)
	assert_true(result["ok"])
	assert_eq(result["target_id"], BLESSING)
	assert_eq(state.get_magic_resource(GameState.MAGIC_RESOURCE_PIETY), 1)
	var effect: Dictionary = result["effect"]
	assert_eq(effect["delivery"]["kind"], "self")
	assert_eq(effect["modifier"]["kind"], "damage_bonus")
	assert_eq(effect["modifier"]["modifier_id"], "modifier.blessing")
	assert_eq(effect["modifier"]["stacking"], "replace")

	var poor := _granted_state(db, 0)
	var failed := MagicResolver.cast(poor, db, BLESSING)
	assert_false(failed["ok"])
	assert_eq(failed["reason"], MagicResolver.FAILURE_INSUFFICIENT_PIETY)


func test_self_delivery_raises_melee_damage_until_expiry() -> void:
	var db := _make_db()
	var state := _granted_state(db, 1)
	var host := _make_host()
	var caster := _add_dummy(host)
	var victim := _add_dummy(host, Vector2(24.0, 0.0))

	var result := MagicResolver.cast(state, db, BLESSING)
	var delivered := CAST_EXECUTOR.execute(result, caster, Vector2.RIGHT, host)
	assert_true(delivered == caster, "self delivery must land on the caster")
	assert_eq(host.get_child_count(), 2, "self delivery must not spawn a world node")
	var modifiers := caster.combat_vitals.modifiers
	assert_true(modifiers.is_active(MODIFIER))
	assert_almost_eq(modifiers.remaining_sec(MODIFIER), 6.0, 0.001)
	assert_almost_eq(modifiers.outgoing_damage_bonus(), 0.25, 0.0001)

	var hits := MeleeAttackResolver.strike(
		caster, Vector2.RIGHT, 48.0, 0.35, 8.0, &"blunt"
	)
	assert_eq(hits.size(), 1)
	assert_almost_eq(victim.health, 90.0, 0.0001, "8 * 1.25 = 10 landed")

	caster._process(6.0)
	assert_false(modifiers.is_active(MODIFIER), "buff must expire after its authored duration")
	victim.clear_hit_invulnerability()
	hits = MeleeAttackResolver.strike(caster, Vector2.RIGHT, 48.0, 0.35, 8.0, &"blunt")
	assert_eq(hits.size(), 1)
	assert_almost_eq(victim.health, 82.0, 0.0001)
	host.free()


func test_recast_replaces_instead_of_stacking() -> void:
	var db := _make_db()
	var state := _granted_state(db, 2)
	var host := _make_host()
	var caster := _add_dummy(host)
	var modifiers := caster.combat_vitals.modifiers

	_cast_on(state, db, caster, host)
	caster._process(3.0)
	assert_almost_eq(modifiers.remaining_sec(MODIFIER), 3.0, 0.001)
	_cast_on(state, db, caster, host)
	assert_eq(modifiers.stack_count(MODIFIER), 1)
	assert_almost_eq(modifiers.remaining_sec(MODIFIER), 6.0, 0.001)
	assert_almost_eq(modifiers.outgoing_damage_bonus(), 0.25, 0.0001)
	host.free()


func test_spellforge_casts_rite_by_id_not_sequence() -> void:
	var db := _make_db()
	var state := _granted_state(db, 1)
	var host := _make_host()
	var caster := _add_dummy(host)
	var model := MODEL_SCRIPT.new() as SpellforgeModel
	model.configure(state, db)
	var rows := model.learned_spells()
	assert_eq(rows.size(), 1)
	assert_eq(rows[0]["id"], BLESSING)
	assert_eq(rows[0]["resource"], "resource.piety")
	assert_true(model.arm_spell(BLESSING))
	assert_eq(model.selected_sequence(), [])
	assert_true(model.cast(caster, Vector2.RIGHT, host)["ok"])
	assert_true(model.feedback_text().contains("Blessing"))
	assert_true(caster.combat_vitals.modifiers.is_active(MODIFIER))
	assert_eq(state.get_magic_resource(GameState.MAGIC_RESOURCE_PIETY), 0)
	assert_false(JSON.stringify(state.save_payload()).contains("modifier."))
	host.free()


func test_combat_code_does_not_hard_code_the_rite() -> void:
	for path in COMBAT_SCRIPTS:
		var source := FileAccess.get_file_as_string(path)
		assert_false(source.is_empty(), "missing %s" % path)
		assert_false(source.contains("blessing"), "%s must not hard-code Blessing" % path)
		assert_false(source.contains("rite."), "%s must not hard-code rite IDs" % path)
