extends "res://tests/godot/test_case.gd"

const CONTENT_DIRS: Array[String] = [
	"res://content/examples/valid",
	"res://content/examples/support",
]
const TREMOR := &"spell.pagan.earth_tremor"
const GRANT_TREMOR := &"magic.grant.starter_earth_tremor"
const EARTH: Array[StringName] = [&"element.earth"]
const CAST_EXECUTOR := preload("res://scripts/magic/magic_cast_executor_2d.gd")
const DUMMY_SCRIPT := preload("res://scripts/combat/combat_training_dummy.gd")


func test_earth_tremor_pulses_radius_filters_targets_and_spends_willpower() -> void:
	var db := ContentDB.new()
	assert_true(db.load_from_directories(CONTENT_DIRS))
	var state := GameState.new()
	state.set_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER, 1)
	assert_true(MagicResolver.apply_grant_operation(state, db, GRANT_TREMOR))

	var result := MagicResolver.cast(state, db, &"", EARTH)
	assert_true(result["ok"])
	assert_eq(result["target_id"], TREMOR)
	assert_eq(state.get_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER), 0)
	var effect: Dictionary = result["effect"]
	assert_eq(effect["delivery"]["kind"], "area_pulse")
	assert_eq(effect["delivery"]["radius"], 96.0)
	assert_eq(effect["impact"]["kind"], "stagger")
	assert_eq(effect["impact"]["duration_sec"], 1.5)

	var tree := Engine.get_main_loop() as SceneTree
	var host := Node2D.new()
	tree.root.add_child(host)
	var caster := _add_dummy(host, Vector2.ZERO)
	var inside := _add_dummy(host, Vector2(72.0, 0.0))
	var edge := _add_dummy(host, Vector2(96.0, 0.0))
	var outside := _add_dummy(host, Vector2(97.0, 0.0))
	var friendly := _add_dummy(host, Vector2(24.0, 0.0))
	friendly.hostile_to_source = false

	var pulse := CAST_EXECUTOR.execute(result, caster, Vector2.RIGHT, host)
	assert_true(pulse != null)
	assert_false(caster.is_staggered(), "caster must be excluded")
	assert_true(inside.is_staggered(), "target inside radius must stagger")
	assert_true(edge.is_staggered(), "radius boundary must be included")
	assert_false(outside.is_staggered(), "target outside radius must be ignored")
	assert_false(friendly.is_staggered(), "non-hostile target must be ignored")

	inside._process(0.5)
	assert_almost_eq(inside.stagger_remaining_sec(), 1.0, 0.01)
	inside._process(1.1)
	assert_false(inside.is_staggered(), "stagger must expire after its duration")
	host.free()


func _add_dummy(host: Node2D, position: Vector2) -> CombatTestDummy:
	var dummy := DUMMY_SCRIPT.new() as CombatTestDummy
	host.add_child(dummy)
	dummy.global_position = position
	return dummy
