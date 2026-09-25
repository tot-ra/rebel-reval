extends "res://tests/godot/test_case.gd"

## R-725 Iron Skin: earth + metal self buff through reusable timed modifiers.

const CONTENT_DIRS: Array[String] = [
	"res://content/examples/valid",
	"res://content/examples/support",
]
const IRON_SKIN := &"spell.pagan.iron_skin"
const GRANT_IRON_SKIN := &"magic.grant.starter_iron_skin"
const MODIFIER := &"modifier.iron_skin"
const EARTH_METAL: Array[StringName] = [&"element.earth", &"element.metal"]
const CAST_EXECUTOR := preload("res://scripts/magic/magic_cast_executor_2d.gd")
const DUMMY_SCRIPT := preload("res://scripts/combat/combat_training_dummy.gd")
const MODEL_SCRIPT := preload("res://scripts/magic/spellforge_model.gd")
const COMBAT_SCRIPTS: Array[String] = [
	"res://scripts/player.gd",
	"res://scripts/combat/combat_vitals.gd",
	"res://scripts/combat/combat_timed_modifiers.gd",
	"res://scripts/combat/combat_room_enemy.gd",
	"res://scripts/magic/magic_cast_executor_2d.gd",
]


func _granted_state(db: ContentDB, willpower: int) -> GameState:
	var state := GameState.new()
	state.set_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER, willpower)
	assert_true(MagicResolver.apply_grant_operation(state, db, GRANT_IRON_SKIN))
	return state


func _make_db() -> ContentDB:
	var db := ContentDB.new()
	assert_true(db.load_from_directories(CONTENT_DIRS))
	return db


func _add_dummy(host: Node2D) -> CombatTestDummy:
	var dummy := DUMMY_SCRIPT.new() as CombatTestDummy
	host.add_child(dummy)
	dummy.configure_resources(100.0, 100.0, 100.0, 100.0)
	return dummy


func _cast_on(state: GameState, db: ContentDB, caster: Node2D, host: Node2D) -> void:
	var result := MagicResolver.cast(state, db, &"", EARTH_METAL)
	assert_true(CAST_EXECUTOR.execute(result, caster, Vector2.RIGHT, host) == caster)


func _make_host() -> Node2D:
	var host := Node2D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	return host


func test_earth_metal_resolves_to_self_modifier_and_spends_willpower() -> void:
	var db := _make_db()
	var state := _granted_state(db, 3)
	var result := MagicResolver.cast(state, db, &"", EARTH_METAL)
	assert_true(result["ok"])
	assert_eq(result["target_id"], IRON_SKIN)
	assert_eq(state.get_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER), 1)
	var effect: Dictionary = result["effect"]
	assert_eq(effect["delivery"]["kind"], "self")
	assert_eq(effect["modifier"]["kind"], "damage_reduction")
	assert_eq(effect["modifier"]["modifier_id"], "modifier.iron_skin")
	assert_eq(effect["modifier"]["stacking"], "replace")

	var poor := _granted_state(db, 1)
	var failed := MagicResolver.cast(poor, db, &"", EARTH_METAL)
	assert_false(failed["ok"])
	assert_eq(failed["reason"], MagicResolver.FAILURE_INSUFFICIENT_WILLPOWER)


func test_self_delivery_reduces_landed_damage_until_expiry() -> void:
	var db := _make_db()
	var state := _granted_state(db, 2)
	var host := _make_host()
	var caster := _add_dummy(host)

	var result := MagicResolver.cast(state, db, &"", EARTH_METAL)
	var delivered := CAST_EXECUTOR.execute(result, caster, Vector2.RIGHT, host)
	assert_true(delivered == caster, "self delivery must land on the caster")
	assert_eq(host.get_child_count(), 1, "self delivery must not spawn a world node")
	var modifiers := caster.combat_vitals.modifiers
	assert_true(modifiers.is_active(MODIFIER))
	assert_almost_eq(modifiers.remaining_sec(MODIFIER), 8.0, 0.001)
	assert_almost_eq(modifiers.damage_reduction(), 0.35, 0.0001)

	assert_almost_eq(caster.take_damage(10.0), 6.5, 0.0001)
	assert_eq(caster.last_result.requested_damage, 10.0, "requested damage stays unreduced")

	# Guarded hits cost stamina for the reduced amount only.
	caster.clear_hit_invulnerability()
	caster.set_guarding(true, 1.0)
	var stamina_before := caster.stamina
	caster.take_damage(20.0)
	assert_eq(caster.last_result.outcome, CombatHitResult.OUTCOME_GUARDED)
	assert_almost_eq(stamina_before - caster.stamina, 13.0, 0.0001)

	# Parry still negates entirely and is not "reduced" into a hit.
	caster.clear_hit_invulnerability()
	caster.set_guarding(true, 0.0)
	caster.take_damage(20.0)
	assert_eq(caster.last_result.outcome, CombatHitResult.OUTCOME_PARRIED)

	caster.set_guarding(false)
	caster._process(8.0)
	assert_false(modifiers.is_active(MODIFIER), "buff must expire after its authored duration")
	caster.clear_hit_invulnerability()
	assert_almost_eq(caster.take_damage(10.0), 10.0, 0.0001)
	host.free()


func test_recast_replaces_instead_of_stacking() -> void:
	var db := _make_db()
	var state := _granted_state(db, 4)
	var host := _make_host()
	var caster := _add_dummy(host)
	var modifiers := caster.combat_vitals.modifiers
	var expired_ids: Array[StringName] = []
	modifiers.expired.connect(
		func(modifier_id: StringName) -> void: expired_ids.append(modifier_id)
	)

	_cast_on(state, db, caster, host)
	caster._process(5.0)
	assert_almost_eq(modifiers.remaining_sec(MODIFIER), 3.0, 0.001)
	_cast_on(state, db, caster, host)
	assert_eq(modifiers.stack_count(MODIFIER), 1)
	assert_almost_eq(modifiers.remaining_sec(MODIFIER), 8.0, 0.001, "recast restarts the timer")
	assert_almost_eq(modifiers.damage_reduction(), 0.35, 0.0001, "recast must not stack")
	caster._process(8.0)
	assert_eq(expired_ids, [MODIFIER])
	host.free()


func test_stack_policy_multiplies_caps_and_refreshes_oldest() -> void:
	var modifiers := CombatTimedModifiers.new()
	var stat := CombatTimedModifiers.STAT_DAMAGE_REDUCTION
	var stack := CombatTimedModifiers.STACKING_STACK
	assert_true(modifiers.apply(&"modifier.test_stack", stat, 0.35, 4.0, stack, 2))
	modifiers.tick(1.0)
	assert_true(modifiers.apply(&"modifier.test_stack", stat, 0.35, 4.0, stack, 2))
	assert_eq(modifiers.stack_count(&"modifier.test_stack"), 2)
	assert_almost_eq(modifiers.damage_reduction(), 1.0 - 0.65 * 0.65, 0.0001)

	# At the cap the stack closest to expiry (3 s left) is refreshed, not added.
	assert_true(modifiers.apply(&"modifier.test_stack", stat, 0.35, 4.0, stack, 2))
	assert_eq(modifiers.stack_count(&"modifier.test_stack"), 2)
	modifiers.tick(3.5)
	assert_eq(modifiers.stack_count(&"modifier.test_stack"), 2, "both stacks now had 4 s")
	modifiers.tick(1.0)
	assert_false(modifiers.is_active(&"modifier.test_stack"))

	# Distinct modifiers combine multiplicatively and never pass the global cap.
	assert_true(modifiers.apply(&"modifier.a", stat, 0.8, 5.0))
	assert_true(modifiers.apply(&"modifier.b", stat, 0.8, 5.0))
	var cap := CombatTimedModifiers.MAX_TOTAL_DAMAGE_REDUCTION
	assert_almost_eq(modifiers.damage_reduction(), cap, 0.0001)


func test_malformed_modifiers_and_targets_fail_closed() -> void:
	var modifiers := CombatTimedModifiers.new()
	var stat := CombatTimedModifiers.STAT_DAMAGE_REDUCTION
	assert_false(modifiers.apply(&"", stat, 0.3, 5.0))
	assert_false(modifiers.apply(&"modifier.x", stat, 0.0, 5.0))
	assert_false(modifiers.apply(&"modifier.x", stat, 0.3, 0.0))
	assert_false(modifiers.apply(&"modifier.x", stat, 0.3, 5.0, &"merge"))
	assert_true(modifiers.active_ids().is_empty())

	var db := _make_db()
	var state := _granted_state(db, 2)
	var host := _make_host()
	var plain := Node2D.new()
	host.add_child(plain)
	var result := MagicResolver.cast(state, db, &"", EARTH_METAL)
	var no_vitals := CAST_EXECUTOR.execute(result, plain, Vector2.RIGHT, host)
	assert_true(no_vitals == null, "caster without vitals must fail")
	var bad := result.duplicate(true)
	bad["effect"]["modifier"]["kind"] = "damage_bonus"
	var caster := _add_dummy(host)
	var unknown := CAST_EXECUTOR.execute(bad, caster, Vector2.RIGHT, host)
	assert_true(unknown == null, "unknown modifier kind must fail")
	assert_false(caster.combat_vitals.modifiers.is_active(MODIFIER))
	host.free()


func test_spellforge_cast_applies_buff_and_save_boundary_drops_it() -> void:
	var db := _make_db()
	var state := _granted_state(db, 2)
	var host := _make_host()
	var caster := _add_dummy(host)
	var model := MODEL_SCRIPT.new() as SpellforgeModel
	model.configure(state, db)
	assert_true(model.select_element(&"element.earth"))
	assert_true(model.select_element(&"element.metal"))
	assert_true(model.cast(caster, Vector2.RIGHT, host)["ok"])
	assert_true(model.feedback_text().contains("Iron Skin"))
	assert_true(caster.combat_vitals.modifiers.is_active(MODIFIER))

	# Transient combat state: saves keep the grant and spent willpower only.
	var payload := state.save_payload()
	assert_false(JSON.stringify(payload).contains("modifier."), "timed modifiers must not be saved")
	var restored := GameState.new()
	assert_eq(restored.load_payload(payload).size(), 0)
	assert_true(restored.has_magic_grant(IRON_SKIN))
	assert_eq(restored.get_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER), 0)
	# Rebuilding an actor (load, respawn, scene transition) starts without buffs.
	caster.configure_resources(100.0, 100.0, 100.0, 100.0)
	assert_false(caster.combat_vitals.modifiers.is_active(MODIFIER))
	host.free()


func test_combat_code_does_not_hard_code_the_spell() -> void:
	for path in COMBAT_SCRIPTS:
		var source := FileAccess.get_file_as_string(path)
		assert_false(source.is_empty(), "missing %s" % path)
		assert_false(source.contains("iron_skin"), "%s must not hard-code Iron Skin" % path)
