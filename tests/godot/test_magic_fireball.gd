extends "res://tests/godot/test_case.gd"

const CONTENT_DIRS: Array[String] = [
	"res://content/examples/valid",
	"res://content/examples/support",
]
const FIREBALL := &"spell.pagan.fireball"
const GRANT_FIREBALL := &"magic.grant.starter_fireball"
const CAST_EXECUTOR := preload("res://scripts/magic/magic_cast_executor_2d.gd")
const FIRE_AIR: Array[StringName] = [&"element.fire", &"element.air"]
const DUMMY_SCRIPT := preload("res://scripts/combat/combat_training_dummy.gd")


func test_fire_plus_air_resolves_to_authored_modular_fireball() -> void:
	var db := ContentDB.new()
	assert_true(db.load_from_directories(CONTENT_DIRS))
	var state := GameState.new()
	state.set_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER, 2)
	assert_true(MagicResolver.apply_grant_operation(state, db, GRANT_FIREBALL))

	var result := MagicResolver.cast(state, db, &"", FIRE_AIR)
	assert_true(result["ok"])
	assert_eq(result["target_id"], FIREBALL)
	assert_eq(state.get_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER), 0)
	var effect: Dictionary = result["effect"]
	assert_eq(effect["delivery"]["kind"], "projectile")
	assert_eq(effect["impact"]["damage_type"], "fire")
	assert_eq(effect["area"]["radius"], 72.0)


func test_fireball_projectile_damages_primary_and_nearby_targets_only() -> void:
	var db := ContentDB.new()
	assert_true(db.load_from_directories(CONTENT_DIRS))
	var state := GameState.new()
	state.set_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER, 2)
	assert_true(MagicResolver.apply_grant_operation(state, db, GRANT_FIREBALL))
	var result := MagicResolver.cast(state, db, &"", FIRE_AIR)

	var tree := Engine.get_main_loop() as SceneTree
	var host := Node2D.new()
	tree.root.add_child(host)
	var caster := Node2D.new()
	host.add_child(caster)
	var primary := _add_dummy(host, Vector2(84.0, 0.0))
	var splash := _add_dummy(host, Vector2(132.0, 0.0))
	var distant := _add_dummy(host, Vector2(250.0, 0.0))
	var projectile := CAST_EXECUTOR.execute(result, caster, Vector2.RIGHT, host) as Node2D
	assert_true(projectile != null)

	projectile.advance(0.2)
	assert_eq(primary.health, 8.0, "direct impact should apply authored 12 damage")
	assert_eq(splash.health, 13.0, "Air area module should apply authored 7 splash damage")
	assert_eq(distant.health, 20.0, "targets outside the authored radius stay untouched")
	host.free()


func _add_dummy(host: Node2D, position: Vector2) -> CombatTestDummy:
	var dummy := DUMMY_SCRIPT.new() as CombatTestDummy
	host.add_child(dummy)
	dummy.global_position = position
	return dummy
