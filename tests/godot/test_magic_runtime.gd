extends "res://tests/godot/test_case.gd"

const CONTENT_DIRS: Array[String] = [
	"res://content/examples/valid",
	"res://content/examples/support",
]
const SPELL_SPARK := &"spell.pagan.spark"
const RITE_BLESSING := &"rite.blessing"
const GRANT_SPARK := &"magic.grant.starter_spark"
const REVOKE_SPARK := &"magic.revoke.starter_spark"
const HAMMER := &"item.forge_hammer"


func _make_db() -> ContentDB:
	var db := ContentDB.new()
	assert_true(db.load_from_directories(CONTENT_DIRS), "magic example corpus should load")
	return db


func test_grant_and_revoke_are_explicit_and_persistable() -> void:
	var state := GameState.new()
	var db := _make_db()

	assert_false(state.has_magic_grant(SPELL_SPARK))
	assert_true(MagicResolver.apply_grant_operation(state, db, GRANT_SPARK))
	assert_true(state.has_magic_grant(SPELL_SPARK))
	assert_true(state.get_flag(&"flag.magic.taught_spark"))
	assert_true(MagicResolver.apply_grant_operation(state, db, REVOKE_SPARK))
	assert_false(state.has_magic_grant(SPELL_SPARK))
	assert_false(state.get_flag(&"flag.magic.taught_spark"))


func test_cast_fails_closed_for_unknown_and_locked_records() -> void:
	var state := GameState.new()
	var db := _make_db()
	state.set_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER, 2)

	var unknown := MagicResolver.cast(state, db, &"", [&"element.air"])
	assert_false(unknown["ok"])
	assert_eq(unknown["reason"], MagicResolver.FAILURE_UNKNOWN_SEQUENCE)

	var locked := MagicResolver.cast(state, db, SPELL_SPARK)
	assert_false(locked["ok"])
	assert_eq(locked["reason"], MagicResolver.FAILURE_LOCKED)


func test_pagan_cast_uses_authored_sequence_and_spends_willpower() -> void:
	var state := GameState.new()
	var db := _make_db()
	state.set_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER, 2)
	assert_true(MagicResolver.apply_grant_operation(state, db, GRANT_SPARK))

	var result := MagicResolver.cast(state, db, &"", [&"element.fire"])
	assert_true(result["ok"])
	assert_eq(result["target_id"], SPELL_SPARK)
	assert_eq(result["resource"], GameState.MAGIC_RESOURCE_WILLPOWER)
	assert_eq(state.get_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER), 1)

	var exhausted := MagicResolver.cast(state, db, SPELL_SPARK)
	assert_true(exhausted["ok"])
	assert_eq(state.get_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER), 0)
	var empty := MagicResolver.cast(state, db, SPELL_SPARK)
	assert_false(empty["ok"])
	assert_eq(empty["reason"], MagicResolver.FAILURE_INSUFFICIENT_WILLPOWER)


func test_divine_rite_uses_piety_and_school_guard() -> void:
	var state := GameState.new()
	var db := _make_db()
	state.grant_magic(RITE_BLESSING, &"flag.magic.taught_blessing")

	var wrong_school := MagicResolver.cast(state, db, RITE_BLESSING, [], MagicResolver.SCHOOL_PAGAN)
	assert_false(wrong_school["ok"])
	assert_eq(wrong_school["reason"], MagicResolver.FAILURE_WRONG_SCHOOL)

	var insufficient := MagicResolver.cast(state, db, RITE_BLESSING)
	assert_false(insufficient["ok"])
	assert_eq(insufficient["reason"], MagicResolver.FAILURE_INSUFFICIENT_PIETY)

	state.set_magic_resource(GameState.MAGIC_RESOURCE_PIETY, 1)
	var success := MagicResolver.cast(state, db, RITE_BLESSING)
	assert_true(success["ok"])
	assert_eq(state.get_magic_resource(GameState.MAGIC_RESOURCE_PIETY), 0)


func test_hammer_conduit_can_be_equipped_or_bound_at_smithy() -> void:
	var state := GameState.new()

	assert_false(state.is_forge_conduit_available())
	state.bag.try_add(HAMMER)
	assert_true(state.equip_from_bag(&"right_hand", HAMMER))
	assert_true(state.is_forge_conduit_available())

	var other := GameState.new()
	other.set_forge_conduit_bound(true)
	assert_true(other.is_forge_conduit_available())
	other.set_forge_conduit_bound(false)
	assert_false(other.is_forge_conduit_available())


func test_magic_fields_round_trip_with_legacy_defaults() -> void:
	var original := GameState.new()
	original.set_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER, 4)
	original.set_magic_resource(GameState.MAGIC_RESOURCE_PIETY, 3)
	original.set_magic_resource(GameState.MAGIC_RESOURCE_HEALTH, 77)
	original.grant_magic(SPELL_SPARK, &"flag.magic.taught_spark")
	original.set_forge_conduit_bound(true)

	var restored := GameState.new()
	var errors := restored.load_payload(original.save_payload())
	assert_eq(errors.size(), 0)
	assert_eq(restored.get_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER), 4)
	assert_eq(restored.get_magic_resource(GameState.MAGIC_RESOURCE_PIETY), 3)
	assert_eq(restored.get_magic_resource(GameState.MAGIC_RESOURCE_HEALTH), 77)
	assert_true(restored.has_magic_grant(SPELL_SPARK))
	assert_true(restored.get_flag(&"flag.magic.taught_spark"))
	assert_true(restored.is_forge_conduit_bound())

	var legacy := GameState.new()
	var legacy_payload := original.save_payload()
	legacy_payload.erase("magic_resources")
	legacy_payload.erase("magic_grants")
	legacy_payload.erase("forge_conduit_bound")
	assert_eq(legacy.load_payload(legacy_payload).size(), 0)
	assert_eq(legacy.get_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER), 0)
	assert_false(legacy.has_magic_grant(SPELL_SPARK))
	assert_false(legacy.is_forge_conduit_bound())
