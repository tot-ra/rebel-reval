extends "res://tests/godot/test_case.gd"

const LOC_SMITHY := &"loc.kalev_smithy"
const OBJ_SPEAR := &"world.spearhead_anvil"
const ITEM_HAMMER := &"item.forge_hammer"
const ITEM_SPEARHEAD := &"item.seized_spearhead"
const FLAG_MART_SPOKEN := &"flag.demo_mart_spoken"


func test_truncated_json_is_rejected() -> void:
	var result := SaveEnvelope.parse_file("res://tests/fixtures/saves/invalid/truncated.json")
	assert_false(result["ok"])
	assert_true(_errors_contain(result, "invalid JSON") or _errors_contain(result, "truncated"))


func test_empty_text_is_rejected_as_truncated() -> void:
	var result := SaveEnvelope.parse_text("")
	assert_false(result["ok"])
	assert_true(_errors_contain(result, "empty") or _errors_contain(result, "truncated"))


func test_wrong_root_type_is_rejected() -> void:
	var result := SaveEnvelope.parse_file("res://tests/fixtures/saves/invalid/wrong_root_type.json")
	assert_false(result["ok"])
	assert_true(_errors_contain(result, "object"))


func test_unknown_envelope_version_is_rejected() -> void:
	var result := SaveEnvelope.parse_file("res://tests/fixtures/saves/invalid/unknown_envelope_version.json")
	assert_false(result["ok"])
	assert_true(_errors_contain(result, "unsupported save envelope version"))


func test_wrong_game_state_type_is_rejected() -> void:
	var result := SaveEnvelope.parse_file("res://tests/fixtures/saves/invalid/wrong_game_state_type.json")
	assert_false(result["ok"])
	assert_true(_errors_contain(result, "game_state must be a dictionary"))


func test_v0_envelope_migrates_and_loads() -> void:
	var result := SaveEnvelope.parse_file("res://tests/fixtures/saves/envelope_v0_legacy.json")
	assert_true(result["ok"], "v0 envelope must migrate to current schema")
	assert_eq(result["migrated_from"], 0)
	var state := result["state"] as GameState
	assert_eq(state.get_phase(), &"phase.prologue_day")
	assert_true(state.get_flag(FLAG_MART_SPOKEN))
	assert_eq(state.player.location_id, &"reval_east")
	assert_true(is_equal_approx(state.player.health, 88.0))


func test_every_released_fixture_loads() -> void:
	var entries := SaveEnvelope.list_released_fixture_entries()
	assert_true(entries.size() >= 3, "released manifest must list demo fixtures")
	for entry in entries:
		var relative_path := String(entry.get("path", ""))
		assert_false(relative_path.is_empty(), "fixture row must include path")
		var fixture_id := String(entry.get("id", relative_path))
		var result := SaveEnvelope.parse_file(SaveEnvelope.released_fixture_path(relative_path))
		assert_true(result["ok"], "released fixture %s must load: %s" % [fixture_id, ", ".join(result["errors"])])


func test_released_demo_fresh_start_matches_demo_seed_shape() -> void:
	var result := SaveEnvelope.parse_file(
		SaveEnvelope.released_fixture_path("released/save.demo_fresh_start.json")
	)
	assert_true(result["ok"])
	var state := result["state"] as GameState
	assert_eq(state.equipped_item(&"right_hand"), ITEM_HAMMER)
	assert_true(state.is_world_item_placed(LOC_SMITHY, OBJ_SPEAR))
	assert_true(state.are_world_defaults_seeded(LOC_SMITHY))


func test_released_post_pickup_fixture_matches_demo_outcome() -> void:
	var result := SaveEnvelope.parse_file(
		SaveEnvelope.released_fixture_path("released/save.demo_post_pickup.json")
	)
	assert_true(result["ok"])
	var state := result["state"] as GameState
	assert_true(state.get_flag(FLAG_MART_SPOKEN))
	assert_true(state.has_item(ITEM_SPEARHEAD))
	assert_false(state.is_world_item_placed(LOC_SMITHY, OBJ_SPEAR))
	assert_eq(state.bag.find_placement(ITEM_SPEARHEAD).item_id, ITEM_SPEARHEAD)


func test_game_state_v1_legacy_fixture_migrates_map_world_state() -> void:
	var result := SaveEnvelope.parse_file(
		SaveEnvelope.released_fixture_path("released/save.game_state_v1_legacy.json")
	)
	assert_true(result["ok"])
	var state := result["state"] as GameState
	assert_eq(state.get_version(), 1)
	assert_eq(state.save_map_world_state()["save_version"], MapStableStateStore.CURRENT_SAVE_VERSION)


func test_unsupported_game_state_version_is_rejected() -> void:
	var envelope := {
		"save_version": SaveEnvelope.CURRENT_ENVELOPE_VERSION,
		"saved_at_unix": 1,
		"game_state": {
			"version": 99,
			"phase": "phase.prologue_day",
			"player": {},
			"bag": {"placements": []},
			"equipped": {},
			"facts": {},
			"flags": {},
			"relationships": {},
			"pressures": {},
			"quest_states": {},
			"location_states": {},
			"items": {},
			"forged_records": [],
			"world_items": {},
			"world_defaults_seeded": {},
			"map_world_state": {"save_version": 2, "world_state": {}},
		},
	}
	var migrated := SaveEnvelope.migrate_envelope(envelope)
	assert_true(migrated["ok"])
	var loaded := SaveEnvelope.load_game_state_from_envelope(migrated["envelope"])
	assert_false(loaded["ok"])
	assert_true(_errors_contain(loaded, "unsupported game-state version"))


func _errors_contain(result: Dictionary, needle: String) -> bool:
	var errors: Variant = result.get("errors", PackedStringArray())
	if errors is PackedStringArray:
		for entry in errors as PackedStringArray:
			if needle in entry:
				return true
	elif errors is Array:
		for entry in errors as Array:
			if needle in String(entry):
				return true
	return false
