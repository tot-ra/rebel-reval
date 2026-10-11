extends "res://tests/godot/test_case.gd"

const CONTENT_DIRS: Array[String] = [
	"res://content/examples/valid",
	"res://content/examples/support",
]
const FIREBALL := &"spell.pagan.fireball"
const GRANT_FIREBALL := &"magic.grant.starter_fireball"
const FIRE_AIR: Array[StringName] = [&"element.fire", &"element.air"]


func _make_db() -> ContentDB:
	var db := ContentDB.new()
	assert_true(db.load_from_directories(CONTENT_DIRS), "magic example corpus should load")
	return db


func _prepare_fireball(state: GameState, db: ContentDB) -> void:
	state.set_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER, 2)
	assert_true(MagicResolver.apply_grant_operation(state, db, GRANT_FIREBALL))


func test_natural_scales_each_element_and_preserves_authored_content() -> void:
	var db := _make_db()
	var state := GameState.new()
	state.set_flag(&"flag.natural.system_enabled", true)
	state.set_natural_initial_allocation_complete(true)
	_prepare_fireball(state, db)

	var result := MagicResolver.cast(state, db, &"", FIRE_AIR)
	assert_true(result["ok"])
	assert_true(absf(float(result["natural_multiplier"]) - 1.10) < 0.001)
	var effect: Dictionary = result["effect"]
	assert_true(absf(float(effect["impact"]["amount"]) - 13.2) < 0.001)
	assert_true(absf(float(effect["area"]["effect"]["amount"]) - 7.7) < 0.001)
	assert_eq(effect["delivery"]["speed"], 420.0)
	assert_eq(effect["area"]["radius"], 72.0)

	var authored := db.get_spell(FIREBALL)
	assert_eq(authored["effect"]["impact"]["amount"], 12.0)
	assert_eq(authored["effect"]["area"]["effect"]["amount"], 7.0)


func test_natural_baseline_and_missing_element_are_neutral() -> void:
	var state := GameState.new()
	assert_eq(
		MagicResolver.natural_effectiveness_multiplier(state, FIRE_AIR),
		1.0,
		"disabled NATURAL keeps the baseline multiplier"
	)

	state.set_flag(&"flag.natural.system_enabled", true)
	state.set_natural_initial_allocation_complete(true)
	var unknown: Array[StringName] = [&"element.not_mapped"]
	assert_eq(
		MagicResolver.natural_effectiveness_multiplier(state, unknown),
		1.0,
		"an element without an owning aspect must remain neutral"
	)


func test_natural_ranks_and_psyche_deltas_round_trip_into_magic_scale() -> void:
	var original := GameState.new()
	assert_true(original.grant_natural_points(3))
	assert_eq(original.spend_natural_point(&"aspect.nature"), &"")
	assert_eq(original.spend_natural_point(&"aspect.nature"), &"")
	assert_eq(original.spend_natural_point(&"aspect.nature"), &"")
	assert_eq(original.get_natural_aspect_rank(&"aspect.nature"), 8)
	assert_eq(original.apply_psyche_state(&"psyche.state.exalted", 1, &"beat.test"), &"")
	original.set_flag(&"flag.natural.system_enabled", true)
	original.set_natural_initial_allocation_complete(true)

	var restored := GameState.new()
	assert_eq(restored.load_payload(original.save_payload()), [])
	assert_eq(restored.get_natural_aspect_rank(&"aspect.nature"), 8)
	assert_eq(restored.get_natural_effective_aspect_rank(&"aspect.nature"), 7)
	var earth: Array[StringName] = [&"element.earth"]
	assert_true(
		absf(MagicResolver.natural_effectiveness_multiplier(restored, earth) - 1.14) < 0.001,
		"round-tripped effective rank must drive the multiplier"
	)
