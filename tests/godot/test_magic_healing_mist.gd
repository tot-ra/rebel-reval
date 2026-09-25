extends "res://tests/godot/test_case.gd"

## R-721 Healing Mist: water + life persistent ally area with reusable healing over time.

const CONTENT_DIRS: Array[String] = [
	"res://content/examples/valid",
	"res://content/examples/support",
]
const HEALING_MIST := &"spell.pagan.healing_mist"
const GRANT_HEALING_MIST := &"magic.grant.starter_healing_mist"
const WATER_LIFE: Array[StringName] = [&"element.water", &"element.life"]
const CAST_EXECUTOR := preload("res://scripts/magic/magic_cast_executor_2d.gd")
const DUMMY_SCRIPT := preload("res://scripts/combat/combat_training_dummy.gd")
const PLAYER_SCRIPT := preload("res://scripts/player.gd")
const COMBAT_SCRIPTS: Array[String] = [
	"res://scripts/player.gd",
	"res://scripts/combat/combat_vitals.gd",
	"res://scripts/combat/combat_training_dummy.gd",
	"res://scripts/combat/combat_room_enemy.gd",
	"res://scripts/magic/magic_cast_executor_2d.gd",
	"res://scripts/magic/magic_persistent_area_2d.gd",
	"res://scripts/magic/magic_healing_over_time.gd",
]
## Authored values from spell.pagan.healing_mist.json.
const HEAL_PER_TICK := 4.0
const AREA_SEC := 6.0
const RADIUS := 80.0


func _make_db() -> ContentDB:
	var db := ContentDB.new()
	assert_true(db.load_from_directories(CONTENT_DIRS))
	return db


func _granted_state(db: ContentDB, willpower: int) -> GameState:
	var state := GameState.new()
	state.set_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER, willpower)
	assert_true(MagicResolver.apply_grant_operation(state, db, GRANT_HEALING_MIST))
	return state


func _make_host() -> Node2D:
	var host := Node2D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	return host


func _add_dummy(
	host: Node2D, position: Vector2, health: float, hostile: bool = true
) -> CombatTestDummy:
	var dummy := DUMMY_SCRIPT.new() as CombatTestDummy
	host.add_child(dummy)
	dummy.configure_resources(health, 100.0, 100.0, 100.0)
	dummy.hostile_to_source = hostile
	dummy.global_position = position
	return dummy


func _cast_mist(host: Node2D, caster: Node2D) -> MagicPersistentArea2D:
	var db := _make_db()
	var state := _granted_state(db, 3)
	var result := MagicResolver.cast(state, db, &"", WATER_LIFE)
	assert_true(result["ok"])
	var area := CAST_EXECUTOR.execute(result, caster, Vector2.RIGHT, host) as MagicPersistentArea2D
	assert_true(area != null, "water + life must spawn a persistent area")
	# Tests drive the area deterministically; the scene tree must not also tick it.
	area.set_process(false)
	return area


func _area_config() -> Dictionary:
	return {
		"delivery":
		{
			"kind": "persistent_area",
			"radius": RADIUS,
			"duration_sec": AREA_SEC,
			"target_policy": "ally",
		},
		"impact":
		{
			"kind": "heal_over_time",
			"amount": HEAL_PER_TICK,
			"tick_interval_sec": 1.0,
			"duration_sec": AREA_SEC,
		},
	}


func _make_area(caster: Node2D, host: Node2D, policy: String = "ally") -> MagicPersistentArea2D:
	var config := _area_config()
	config["delivery"]["target_policy"] = policy
	var area := MagicPersistentArea2D.new()
	assert_true(area.configure(caster, HEALING_MIST, RADIUS, config["delivery"], config["impact"]))
	host.add_child(area)
	area.global_position = caster.global_position
	area.set_process(false)
	return area


func test_water_life_resolves_to_persistent_ally_area_and_spends_willpower() -> void:
	var db := _make_db()
	var state := _granted_state(db, 3)
	var result := MagicResolver.cast(state, db, &"", WATER_LIFE)
	assert_true(result["ok"])
	assert_eq(result["target_id"], HEALING_MIST)
	assert_eq(state.get_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER), 0)
	var effect: Dictionary = result["effect"]
	assert_eq(effect["delivery"]["kind"], "persistent_area")
	assert_eq(effect["delivery"]["target_policy"], "ally")
	assert_eq(effect["impact"]["kind"], "heal_over_time")

	var poor := _granted_state(db, 2)
	var failed := MagicResolver.cast(poor, db, &"", WATER_LIFE)
	assert_false(failed["ok"])
	assert_eq(failed["reason"], MagicResolver.FAILURE_INSUFFICIENT_WILLPOWER)
	var locked := MagicResolver.cast(GameState.new(), db, &"", WATER_LIFE)
	assert_eq(locked["reason"], MagicResolver.FAILURE_LOCKED)


func test_area_heals_caster_and_allies_but_not_hostiles_or_outsiders() -> void:
	var host := _make_host()
	var caster := _add_dummy(host, Vector2(100, 100), 50.0)
	var ally := _add_dummy(host, Vector2(140, 100), 50.0, false)
	var hostile := _add_dummy(host, Vector2(100, 140), 50.0, true)
	var far_ally := _add_dummy(host, Vector2(100 + RADIUS + 20.0, 100), 50.0, false)
	var area := _cast_mist(host, caster)
	assert_eq(area.global_position, caster.global_position, "mist settles at the cast point")

	var ticked := area.advance(1.0)
	assert_eq(ticked.size(), 2)
	assert_true(ticked.has(caster) and ticked.has(ally))
	assert_almost_eq(caster.health, 54.0, 0.0001)
	assert_almost_eq(caster.combat_vitals.health, 54.0, 0.0001)
	assert_almost_eq(ally.health, 54.0, 0.0001)
	assert_almost_eq(hostile.health, 50.0, 0.0001, "hostiles gain nothing from an ally mist")
	assert_almost_eq(far_ally.health, 50.0, 0.0001, "allies outside the radius are not healed")
	host.free()


func test_hostile_policy_filters_the_other_way() -> void:
	var host := _make_host()
	var caster := _add_dummy(host, Vector2.ZERO, 50.0)
	var ally := _add_dummy(host, Vector2(20, 0), 50.0, false)
	var hostile := _add_dummy(host, Vector2(0, 20), 50.0, true)
	var area := _make_area(caster, host, "hostile")
	area.advance(1.0)
	assert_almost_eq(caster.health, 50.0, 0.0001, "the caster is never hostile to itself")
	assert_almost_eq(ally.health, 50.0, 0.0001)
	assert_almost_eq(hostile.health, 54.0, 0.0001)
	host.free()


func test_ticks_are_frame_rate_independent_and_expire_with_the_area() -> void:
	var host := _make_host()
	var coarse_caster := _add_dummy(host, Vector2.ZERO, 10.0)
	var fine_caster := _add_dummy(host, Vector2(1000, 0), 10.0)
	var coarse := _make_area(coarse_caster, host)
	var fine := _make_area(fine_caster, host)
	var expired_count := [0]
	coarse.expired.connect(func() -> void: expired_count[0] += 1)

	coarse.advance(AREA_SEC)
	for _step in range(48):
		fine.advance(AREA_SEC / 48.0)
	var expected := 10.0 + HEAL_PER_TICK * AREA_SEC
	assert_almost_eq(coarse_caster.health, expected, 0.0001, "one 6 s step applies six ticks")
	assert_almost_eq(fine_caster.health, expected, 0.0001, "small steps match one large step")
	assert_false(coarse.is_active())
	assert_false(fine.is_active())
	assert_eq(expired_count[0], 1)
	assert_true(coarse.is_queued_for_deletion(), "expired areas leave the world")

	# Further steps after expiry are inert.
	coarse.advance(1.0)
	assert_almost_eq(coarse_caster.health, expected, 0.0001)
	host.free()


func test_heal_is_capped_and_never_revives() -> void:
	var host := _make_host()
	var caster := _add_dummy(host, Vector2.ZERO, 98.0)
	var fallen := _add_dummy(host, Vector2(10, 0), 5.0, false)
	fallen.take_damage(20.0)
	assert_true(fallen.combat_vitals.is_dead())
	var area := _make_area(caster, host)
	var ticked := area.advance(2.0)
	assert_almost_eq(caster.health, 100.0, 0.0001, "healing stops at max health")
	assert_eq(caster.combat_vitals.health, 100.0)
	assert_almost_eq(fallen.health, 0.0, 0.0001, "the dead are not raised by mist")
	assert_false(ticked.has(fallen))
	# A full-health ally is not reported as healed.
	assert_true(area.advance(1.0).is_empty())
	host.free()


func test_per_target_budget_pauses_outside_and_resumes_inside() -> void:
	var host := _make_host()
	var caster := _add_dummy(host, Vector2.ZERO, 50.0)
	var ally := _add_dummy(host, Vector2(10, 0), 50.0, false)
	var area := _make_area(caster, host)
	area.advance(0.5)
	ally.global_position = Vector2(RADIUS * 3.0, 0)
	area.advance(1.0)
	assert_almost_eq(ally.health, 50.0, 0.0001, "half a tick inside heals nothing yet")
	ally.global_position = Vector2(10, 0)
	area.advance(0.5)
	assert_almost_eq(ally.health, 54.0, 0.0001, "time inside accumulates across visits")
	assert_almost_eq(caster.health, 58.0, 0.0001, "the caster stayed inside for 2 s")
	host.free()


func test_healing_over_time_module_is_reusable_and_fails_closed() -> void:
	var effect := MagicHealingOverTime.new()
	var impact: Dictionary = _area_config()["impact"]
	var wrong_kind := impact.duplicate()
	wrong_kind["kind"] = "heal"
	assert_false(effect.configure(wrong_kind))
	var no_amount := impact.duplicate()
	no_amount["amount"] = 0.0
	assert_false(effect.configure(no_amount))
	var no_cadence := impact.duplicate()
	no_cadence.erase("tick_interval_sec")
	assert_false(effect.configure(no_cadence))
	assert_true(effect.configure(impact))

	var vitals := CombatVitals.new()
	vitals.configure(40.0, 100.0, 10.0, 10.0)
	assert_almost_eq(vitals.heal(15.0), 15.0, 0.0001)
	assert_almost_eq(vitals.heal(80.0), 45.0, 0.0001, "heal reports only restored health")
	assert_eq(vitals.heal(-3.0), 0.0)
	vitals.configure(0.0, 100.0, 10.0, 10.0)
	assert_eq(vitals.heal(10.0), 0.0, "vitals heal never revives")

	var host := _make_host()
	var plain := Node2D.new()
	host.add_child(plain)
	assert_false(MagicHealingOverTime.can_receive(plain))
	assert_eq(effect.tick(1.0, plain), 0.0)
	assert_almost_eq(effect.remaining_duration_sec(), AREA_SEC, 0.0001, "no target, no progress")
	host.free()


func test_malformed_area_plans_spawn_nothing() -> void:
	var host := _make_host()
	var caster := _add_dummy(host, Vector2.ZERO, 50.0)
	var db := _make_db()
	var state := _granted_state(db, 3)
	var result := MagicResolver.cast(state, db, &"", WATER_LIFE)
	var cases: Array[Dictionary] = []
	var no_policy := result.duplicate(true)
	no_policy["effect"]["delivery"].erase("target_policy")
	cases.append(no_policy)
	var bad_policy := result.duplicate(true)
	bad_policy["effect"]["delivery"]["target_policy"] = "everyone"
	cases.append(bad_policy)
	var no_duration := result.duplicate(true)
	no_duration["effect"]["delivery"]["duration_sec"] = 0.0
	cases.append(no_duration)
	var stagger := result.duplicate(true)
	stagger["effect"]["impact"] = {"kind": "stagger", "duration_sec": 1.0}
	cases.append(stagger)
	var no_impact := result.duplicate(true)
	no_impact["effect"].erase("impact")
	cases.append(no_impact)
	var children_before := host.get_child_count()
	for bad in cases:
		assert_true(CAST_EXECUTOR.execute(bad, caster, Vector2.RIGHT, host) == null)
	assert_eq(host.get_child_count(), children_before, "failed plans must not enter the world")
	host.free()


func test_natural_scales_heal_amount_and_duration_but_not_cadence_or_area() -> void:
	var db := _make_db()
	var state := _granted_state(db, 3)
	state.set_flag(&"flag.natural.system_enabled", true)
	state.set_natural_initial_allocation_complete(true)
	var result := MagicResolver.cast(state, db, &"", WATER_LIFE)
	assert_true(result["ok"])
	var multiplier := float(result["natural_multiplier"])
	var effect: Dictionary = result["effect"]
	assert_almost_eq(float(effect["impact"]["amount"]), HEAL_PER_TICK * multiplier, 0.0001)
	assert_almost_eq(float(effect["impact"]["duration_sec"]), AREA_SEC * multiplier, 0.0001)
	assert_eq(effect["impact"]["tick_interval_sec"], 1.0)
	assert_eq(effect["delivery"]["duration_sec"], AREA_SEC)
	assert_eq(effect["delivery"]["radius"], RADIUS)
	assert_eq(db.get_spell(HEALING_MIST)["effect"]["impact"]["amount"], HEAL_PER_TICK)


func test_player_heal_hook_keeps_fields_and_vitals_in_step() -> void:
	var player := PLAYER_SCRIPT.new()
	player.health = 30.0
	player.max_health = 100.0
	var signalled := [0.0]
	player.health_changed.connect(
		func(current: float, _maximum: float) -> void: signalled[0] = current
	)
	assert_true(MagicHealingOverTime.can_receive(player))
	assert_almost_eq(MagicHealingOverTime.apply_to(player, 4.0), 4.0, 0.0001)
	assert_almost_eq(player.health, 34.0, 0.0001)
	assert_almost_eq(player.combat_vitals.health, 34.0, 0.0001)
	assert_almost_eq(signalled[0], 34.0, 0.0001)
	player.free()


func test_area_is_transient_and_combat_code_does_not_name_the_spell() -> void:
	var db := _make_db()
	var state := _granted_state(db, 3)
	assert_true(MagicResolver.cast(state, db, &"", WATER_LIFE)["ok"])
	var payload := JSON.stringify(state.save_payload())
	assert_false(payload.contains("persistent_area"), "areas are not saved")
	assert_false(payload.contains("heal_over_time"), "timed heals are not saved")
	for path in COMBAT_SCRIPTS:
		var source := FileAccess.get_file_as_string(path)
		assert_false(source.is_empty(), "missing %s" % path)
		assert_false(source.contains("healing_mist"), "%s must not hard-code Healing Mist" % path)
