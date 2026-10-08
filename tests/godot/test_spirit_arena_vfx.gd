extends "res://tests/godot/test_case.gd"

## R-1332: the spirit arena draws each exchange. Presentation only; the duel is unchanged.

const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const DUEL_ID := &"dialogue.test_duel"
const CONTENT_DIRS: Array[String] = [
	"res://content/examples/valid",
	"res://content/examples/support",
]

var _state: GameState
var _db: ContentDB
var _host: SpiritArenaHost


func before_each() -> void:
	super.before_each()
	_state = GameState.new()
	_state.set_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER, 12)
	_db = ContentDB.new()
	assert_true(_db.load_from_directories(CONTENT_DIRS))
	_host = SpiritArenaHost.new()
	_host.duel.hero_id = &"char.mart"
	_host.freeze_world = false
	(Engine.get_main_loop() as SceneTree).root.add_child(_host)
	assert_true(_host.open(_db, _state, DUEL_ID))
	_host.vfx().allow_shake = true
	_host.vfx().reduced_flashing = false


func after_each() -> void:
	if is_instance_valid(_host):
		_host.close()
		_host.free()
	super.after_each()


func _emit(result: Dictionary) -> Array[StringName]:
	var vfx := _host.vfx()
	vfx.spawned.clear()
	_host.duel.exchange_resolved.emit(result)
	return vfx.spawned.duplicate()


func _spell(arena_effect: String, pressure_left: float) -> Dictionary:
	return {
		"kind": "spell",
		"spell_id": "x",
		"arena_effect": arena_effect,
		"pressure_left": pressure_left,
	}


func test_each_spell_effect_has_its_own_look() -> void:
	var fireball := _emit(_spell("pressure", 40.0))
	assert_true(fireball.has(SpiritArenaVfx.EFFECT_FIREBALL), "fireball flies: %s" % [fireball])
	assert_true(_emit(_spell("stagger", 40.0)).has(SpiritArenaVfx.EFFECT_TREMOR))
	assert_true(_emit(_spell("buff", 40.0)).has(SpiritArenaVfx.EFFECT_SHIELD))
	assert_true(_emit(_spell("heal", 40.0)).has(SpiritArenaVfx.EFFECT_HEAL))
	assert_eq(_emit(_spell("none", 40.0)), [] as Array[StringName], "a summon draws nothing")


func test_reduced_motion_lands_the_fireball_at_once_with_a_number() -> void:
	_host.vfx().reduced_motion = true
	var shown := _emit(_spell("pressure", 45.0))
	assert_true(shown.has(SpiritArenaVfx.EFFECT_IMPACT))
	assert_true(shown.has(SpiritArenaVfx.EFFECT_NUMBER), "15 pressure shown")
	assert_true(shown.has(SpiritArenaVfx.EFFECT_BAR_FLASH))


func test_a_landed_blow_shakes_and_reddens_the_screen() -> void:
	var shown := _emit(
		{"kind": "incoming", "outcome": CombatHitResult.OUTCOME_HIT, "composure_lost": 20.0, "resolve_lost": 0.0, "pressure_left": 60.0}  # gdlint: ignore=max-line-length
	)
	for effect: StringName in [
		SpiritArenaVfx.EFFECT_HIT,
		SpiritArenaVfx.EFFECT_VIGNETTE,
		SpiritArenaVfx.EFFECT_SHAKE,
		SpiritArenaVfx.EFFECT_NUMBER,
		SpiritArenaVfx.EFFECT_BAR_FLASH,
	]:
		assert_true(shown.has(effect), "%s in %s" % [effect, shown])
	assert_true(_host.vfx().shake_trauma() > 0.0)


func test_screen_shake_off_keeps_the_vignette() -> void:
	_host.vfx().allow_shake = false
	var shown := _emit(
		{"kind": "incoming", "outcome": CombatHitResult.OUTCOME_HIT, "composure_lost": 20.0, "pressure_left": 60.0}  # gdlint: ignore=max-line-length
	)
	assert_false(shown.has(SpiritArenaVfx.EFFECT_SHAKE))
	assert_true(shown.has(SpiritArenaVfx.EFFECT_VIGNETTE))
	assert_eq(_host.vfx().shake_trauma(), 0.0)
	assert_eq(_host.offset, Vector2.ZERO)


func test_parry_guard_and_dodge_have_distinct_looks() -> void:
	var parry := _emit({"kind": "incoming", "outcome": CombatHitResult.OUTCOME_PARRIED, "pressure_left": 45.0})  # gdlint: ignore=max-line-length
	assert_true(parry.has(SpiritArenaVfx.EFFECT_PARRY))
	assert_true(parry.has(SpiritArenaVfx.EFFECT_NUMBER), "returned pressure is shown")
	assert_false(parry.has(SpiritArenaVfx.EFFECT_VIGNETTE))
	assert_true(_emit({"kind": "incoming", "outcome": CombatHitResult.OUTCOME_GUARDED, "pressure_left": 45.0}).has(SpiritArenaVfx.EFFECT_GUARD))  # gdlint: ignore=max-line-length
	assert_true(_emit({"kind": "incoming", "outcome": CombatHitResult.OUTCOME_INVULNERABLE, "pressure_left": 45.0}).has(SpiritArenaVfx.EFFECT_DODGE))  # gdlint: ignore=max-line-length


func test_a_landed_reply_strikes_the_opponent() -> void:
	var shown := _emit({"kind": "reply", "choice_id": "a", "damage": 12.0, "pressure_left": 48.0})
	assert_true(shown.has(SpiritArenaVfx.EFFECT_STRIKE))
	assert_true(shown.has(SpiritArenaVfx.EFFECT_NUMBER))
	assert_eq(_emit({"kind": "reply", "choice_id": "b", "damage": 0.0, "pressure_left": 48.0}), [] as Array[StringName])  # gdlint: ignore=max-line-length


func test_real_duel_exchanges_drive_the_effects() -> void:
	# The opening blow lands unguarded, then a fireball cast in the answer phase.
	_host.duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_true(_host.vfx().spawned.has(SpiritArenaVfx.EFFECT_HIT))
	assert_true(MagicResolver.apply_grant_operation(_state, _db, &"magic.grant.starter_fireball"))
	var cast := _host.duel.cast_spell(&"spell.pagan.fireball")
	assert_true(bool(cast.get("ok", false)), str(cast))
	assert_true(_host.vfx().spawned.has(SpiritArenaVfx.EFFECT_FIREBALL))


func test_closing_unbinds_and_settles_the_shake() -> void:
	_emit({"kind": "incoming", "outcome": CombatHitResult.OUTCOME_HIT, "composure_lost": 20.0, "pressure_left": 60.0})  # gdlint: ignore=max-line-length
	_host.close()
	assert_eq(_host.offset, Vector2.ZERO)
	assert_false(_host.duel.exchange_resolved.is_connected(_host.vfx()._on_exchange))
