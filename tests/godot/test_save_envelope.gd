extends "res://tests/godot/test_case.gd"

const LOC_SMITHY := &"loc.kalev_smithy"
const OBJ_SPEAR := &"world.spearhead_anvil"
const ITEM_HAMMER := &"item.forge_hammer"
const ITEM_SPEARHEAD := &"item.seized_spearhead"
const FLAG_MART_SPOKEN := &"flag.demo_mart_spoken"
const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")


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
	var result := SaveEnvelope.parse_file(
		"res://tests/fixtures/saves/invalid/unknown_envelope_version.json"
	)
	assert_false(result["ok"])
	assert_true(_errors_contain(result, "unsupported save envelope version"))


func test_wrong_game_state_type_is_rejected() -> void:
	var result := SaveEnvelope.parse_file(
		"res://tests/fixtures/saves/invalid/wrong_game_state_type.json"
	)
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
		var result := SaveEnvelope.parse_file(
			SaveEnvelope.released_fixture_path(relative_path)
		)
		assert_true(
			result["ok"],
			"released fixture %s must load: %s" % [fixture_id, ", ".join(result["errors"])]
		)


func test_every_campaign_fixture_loads_and_preserves_identity() -> void:
	var manifest := _load_json_dictionary(
		"res://content/saves/campaign_fixtures_manifest.json"
	)
	var fixtures: Variant = manifest.get("fixtures", [])
	assert_true(fixtures is Array, "campaign fixture manifest must list fixtures")
	assert_true((fixtures as Array).size() >= 7)
	for fixture_entry: Variant in fixtures as Array:
		assert_true(fixture_entry is Dictionary)
		var row := fixture_entry as Dictionary
		var fixture_id := String(row.get("id", ""))
		var relative_path := String(row.get("path", ""))
		assert_false(fixture_id.is_empty(), "campaign fixture id is required")
		assert_false(relative_path.is_empty(), "campaign fixture path is required")
		var result := SaveEnvelope.parse_file(
			SaveEnvelope.released_fixture_path(relative_path)
		)
		assert_true(
			result["ok"],
			"campaign fixture %s must load: %s" % [fixture_id, ", ".join(result["errors"])]
		)
		var state := result["state"] as GameState
		assert_eq(
			String(state.get_phase()),
			String(row.get("expected_phase", "")),
			"phase drift for %s" % fixture_id
		)
		assert_eq(
			state.get_version(),
			int(row.get("expected_game_state_version", -1)),
			"game-state migration drift for %s" % fixture_id
		)
		var expected_boundary := String(row.get("expected_act_boundary", ""))
		if not expected_boundary.is_empty():
			assert_true(state.has_act1_transition())
			assert_eq(
				String(state.get_act1_transition().get("act_boundary", "")),
				expected_boundary,
				"branch identity drift for %s" % fixture_id
			)
		var quest_id := String(row.get("expected_quest_id", ""))
		if not quest_id.is_empty():
			assert_eq(
				String(state.get_quest_state(StringName(quest_id))),
				String(row.get("expected_quest_state", "")),
				"quest outcome drift for %s" % fixture_id
			)


func _load_json_dictionary(path: String) -> Dictionary:
	var source := FileAccess.get_file_as_string(path)
	if source.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(source)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


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
	assert_eq(state.get_version(), GameState.CURRENT_VERSION)
	assert_eq(state.save_map_world_state()["save_version"], MapStableStateStore.CURRENT_SAVE_VERSION)


func test_game_state_v1_to_v2_migration_preserves_data_and_adds_defaults() -> void:
	var legacy := {
		"version": 1,
		"phase": "phase.investigation_night",
		"player": {"health": 63.0, "location_id": "forge"},
		"flags": {"flag.legacy": true},
		"legacy_extension": {"keep": "future-compatible"},
	}
	var migrated := GameState._migrate_v1_to_v2(legacy)

	assert_eq(legacy["version"], 1, "migration must not mutate the source payload")
	assert_eq(migrated["version"], GameState.CURRENT_VERSION)
	assert_eq(migrated["player"], legacy["player"])
	assert_eq(migrated["flags"], legacy["flags"])
	assert_eq(migrated["legacy_extension"], legacy["legacy_extension"])
	assert_eq(migrated["world_items"], {})
	assert_eq(migrated["world_defaults_seeded"], {})
	assert_eq(
		migrated["map_world_state"],
		{"save_version": MapStableStateStore.CURRENT_SAVE_VERSION, "world_state": {}}
	)


func test_partial_v1_payload_loads_with_current_defaults() -> void:
	var envelope := {
		"save_version": SaveEnvelope.CURRENT_ENVELOPE_VERSION,
		"saved_at_unix": 1,
		"game_state": {
			"version": 1,
			"player": {"health": 55.0},
			"flags": {"flag.partial_migration": true},
		},
	}
	var result := SaveEnvelope.parse_text(JSON.stringify(envelope))

	assert_true(result["ok"], ", ".join(result["errors"]))
	var state := result["state"] as GameState
	assert_eq(state.get_version(), GameState.CURRENT_VERSION)
	assert_eq(state.get_phase(), GameState.PHASE_PROLOGUE_DAY)
	assert_true(is_equal_approx(state.player.health, 55.0))
	assert_true(state.get_flag(&"flag.partial_migration"))
	assert_true(state.bag.is_empty())
	assert_eq(state.save_map_world_state()["world_state"], {})


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


func test_environment_survives_envelope_parse_and_rng_continuation() -> void:
	var weather := SkyWeather.new()
	weather.auto_weather = false
	weather.set_calendar_date({"day": 23, "month": 4, "year": 1343})
	weather.set_weather(SkyWeather.WEATHER_RAIN)
	weather.advance(SkyWeather.TRANSITION_SECONDS * 0.4)
	var expected: Dictionary = weather.snapshot_state(0.75, 3).to_dict()

	var state := GameState.new()
	assert_true(state.set_environment_state(expected))
	var envelope := {
		"save_version": SaveEnvelope.CURRENT_ENVELOPE_VERSION,
		"saved_at_unix": 1,
		"game_state": state.save_payload(),
	}
	var result := SaveEnvelope.parse_text(JSON.stringify(envelope))
	assert_true(result["ok"], ", ".join(result["errors"]))

	var restored_state := result["state"] as GameState
	var restored_environment := restored_state.get_environment_state()
	assert_eq(
		MapParitySnapshot.serialize_value(restored_environment),
		MapParitySnapshot.serialize_value(expected)
	)
	assert_eq(typeof(restored_environment["schema_version"]), TYPE_INT)
	assert_eq(typeof(restored_environment["elapsed_days"]), TYPE_INT)

	var restored_weather := SkyWeather.new()
	assert_true(restored_weather.restore_state(restored_environment))
	weather.advance(0.25)
	restored_weather.advance(0.25)
	assert_eq(
		restored_weather.snapshot_state(0.75, 3).to_dict(),
		weather.snapshot_state(0.75, 3).to_dict(),
		"envelope hydration must preserve deterministic RNG continuation"
	)
	weather.free()
	restored_weather.free()


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
