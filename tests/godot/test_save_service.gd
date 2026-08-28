extends "res://tests/godot/test_case.gd"

const LOC_SMITHY := &"loc.kalev_smithy"
const OBJ_SPEAR := &"world.spearhead_anvil"
const ITEM_HAMMER := &"item.forge_hammer"
const ITEM_SPEARHEAD := &"item.seized_spearhead"
const PHASE_NIGHT := &"phase.investigation_night"
const RECORD_HONEST := &"forged.watch_buckle_repair.honest_work"
const COMMISSION := &"commission.watch_buckle_repair"
const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")

var _test_root := ""


func before_each() -> void:
	_test_root = "user://test_saves/%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]


func after_each() -> void:
	_cleanup_temp_dir()


func test_round_trip_preserves_full_game_state() -> void:
	var original := _rich_state()
	var service := _service()

	assert_true(service.save_game(original))
	var loaded := service.load_game()
	assert_true(loaded["ok"])
	_assert_states_equal(original, loaded["state"] as GameState)


func test_repeated_file_round_trip_is_stable() -> void:
	var service := _service()
	assert_true(service.save_game(_rich_state()))

	var first_load := service.load_game()
	assert_true(first_load["ok"])
	var first_state := first_load["state"] as GameState
	var first_snapshot := MapParitySnapshot.serialize_value(first_state.save_payload())

	assert_true(service.save_game(first_state))
	var second_load := service.load_game()
	assert_true(second_load["ok"])
	var second_snapshot := MapParitySnapshot.serialize_value(
		(second_load["state"] as GameState).save_payload()
	)
	assert_eq(second_snapshot, first_snapshot)


func test_empty_save_slot_reports_no_loadable_save() -> void:
	var service := _service()

	assert_false(service.has_save(7))
	var loaded := service.load_game(7)
	assert_false(loaded["ok"])
	assert_eq(loaded["state"], null)
	assert_true(_errors_contain(loaded, "no loadable save found for slot 7"))


func test_concurrent_save_attempts_are_serialized_and_loadable() -> void:
	var service := _service()
	var start_gate := Semaphore.new()
	var threads: Array[Thread] = []
	var expected_locations: Array[StringName] = []

	for index in 12:
		var state := GameState.new()
		state.player.health = 50.0 + index
		state.player.location_id = StringName("concurrent_%d" % index)
		state.set_flag(StringName("flag.concurrent_%d" % index), true)
		expected_locations.append(state.player.location_id)

		var thread := Thread.new()
		var start_error := thread.start(
			Callable(self, "_save_after_gate").bind(service, state, start_gate)
		)
		assert_eq(start_error, OK)
		threads.append(thread)

	for _index in threads.size():
		start_gate.post()
	for thread in threads:
		assert_true(bool(thread.wait_to_finish()), "every queued save must complete")

	assert_false(FileAccess.file_exists(service.temp_path(0)))
	var loaded := service.load_game()
	assert_true(loaded["ok"], ", ".join(loaded["errors"]))
	var loaded_state := loaded["state"] as GameState
	assert_true(expected_locations.has(loaded_state.player.location_id))
	var suffix := String(loaded_state.player.location_id).trim_prefix("concurrent_")
	assert_true(loaded_state.get_flag(StringName("flag.concurrent_%s" % suffix)))


func test_phase_autosave_writes_loadable_slot() -> void:
	var session_dir := _temp_dir("phase_autosave")
	var service := SaveService.new()
	service.save_directory = session_dir

	var state := GameState.new()
	state.bag.try_add(ITEM_HAMMER)
	state.set_phase(PHASE_NIGHT)

	var autosave := SaveService.new()
	autosave.save_directory = session_dir
	assert_true(autosave.save_game(state))

	var loaded := autosave.load_game()
	assert_true(loaded["ok"])
	assert_eq((loaded["state"] as GameState).get_phase(), PHASE_NIGHT)


func test_interrupted_primary_save_falls_back_to_backup() -> void:
	var service := _service()
	var original := _rich_state()
	assert_true(service.save_game(original))
	# A second save rotates the first primary into the rolling backup.
	assert_true(service.save_game(original))

	var primary := FileAccess.open(service.slot_path(0), FileAccess.READ_WRITE)
	assert_true(primary != null)
	primary.resize(12)
	primary.close()

	var loaded := service.load_game()
	assert_true(loaded["ok"], "backup must remain loadable after truncated primary")
	assert_eq(loaded["source"], service.backup_path(0))
	_assert_states_equal(original, loaded["state"] as GameState)


func test_corrupt_primary_and_backup_reports_failure() -> void:
	var service := _service()
	var original := _rich_state()
	assert_true(service.save_game(original))

	for path in [service.slot_path(0), service.backup_path(0)]:
		var file := FileAccess.open(path, FileAccess.WRITE)
		assert_true(file != null)
		file.store_string("{not valid json")
		file.close()

	var loaded := service.load_game()
	assert_false(loaded["ok"])
	assert_true((loaded["errors"] as PackedStringArray).size() > 0)


func test_list_saves_returns_sorted_metadata() -> void:
	var service := _service()
	var older := _rich_state()
	older.set_phase(&"phase.prologue_day")
	older.player.location_id = &"forge"
	assert_true(service.save_game(older, 1))

	var newer := _rich_state()
	newer.set_phase(PHASE_NIGHT)
	newer.player.location_id = &"reval_east"
	assert_true(service.save_game(newer, 0))

	var listed := service.list_saves()
	assert_eq(listed.size(), 2)
	assert_eq(listed[0]["slot"], 0)
	assert_eq(listed[0]["phase"], String(PHASE_NIGHT))
	assert_eq(listed[0]["location_id"], "reval_east")
	assert_eq(listed[1]["slot"], 1)
	assert_eq(listed[1]["phase"], "phase.prologue_day")
	assert_true(listed[0]["saved_at_unix"] >= listed[1]["saved_at_unix"])


func test_list_saves_skips_corrupt_slots() -> void:
	var service := _service()
	assert_true(service.save_game(_rich_state(), 2))
	var corrupt := FileAccess.open(service.slot_path(3), FileAccess.WRITE)
	assert_true(corrupt != null)
	corrupt.store_string("{not valid")
	corrupt.close()

	var listed := service.list_saves()
	assert_eq(listed.size(), 1)
	assert_eq(listed[0]["slot"], 2)


func test_game_state_payload_round_trip_without_files() -> void:
	var original := _rich_state()
	var payload := original.save_payload()
	var restored := GameState.new()
	var errors := restored.load_payload(payload)
	assert_eq(errors.size(), 0)
	_assert_states_equal(original, restored)


func test_environment_state_survives_save_service_json_round_trip() -> void:
	var original := _rich_state()
	var weather := SkyWeather.new()
	weather.auto_weather = false
	weather.set_calendar_date({"day": 23, "month": 4, "year": 1343})
	weather.set_weather(SkyWeather.WEATHER_RAIN)
	weather.advance(SkyWeather.TRANSITION_SECONDS * 0.4)
	var expected: Dictionary = weather.snapshot_state(0.75, 3).to_dict()
	assert_true(original.set_environment_state(expected))
	var payload := original.save_payload()
	assert_true(payload.has("environment"))
	assert_true(JSON.parse_string(JSON.stringify(payload)) is Dictionary)

	var service := _service()
	assert_true(service.save_game(original))
	var loaded := service.load_game()
	assert_true(loaded["ok"], ", ".join(loaded["errors"]))
	var loaded_environment := (loaded["state"] as GameState).get_environment_state()
	assert_eq(
		MapParitySnapshot.serialize_value(loaded_environment),
		MapParitySnapshot.serialize_value(expected)
	)

	var restored_weather := SkyWeather.new()
	assert_true(restored_weather.restore_state(loaded_environment))
	weather.advance(0.25)
	restored_weather.advance(0.25)
	assert_eq(
		restored_weather.snapshot_state(0.75, 3).to_dict(),
		weather.snapshot_state(0.75, 3).to_dict()
	)
	weather.free()
	restored_weather.free()


func test_legacy_save_without_environment_uses_empty_default() -> void:
	var legacy := _rich_state().save_payload()
	legacy.erase("environment")
	var restored := GameState.new()
	assert_eq(restored.load_payload(legacy), [])
	assert_true(restored.get_environment_state().is_empty())


func test_malformed_environment_is_reported_without_dropping_game_state() -> void:
	var payload := _rich_state().save_payload()
	payload["environment"] = {"schema_version": 99, "weather": "rain"}
	var restored := GameState.new()
	var errors := restored.load_payload(payload)
	assert_true(errors.size() > 0)
	assert_true("environment" in ", ".join(errors))
	assert_eq(restored.get_phase(), PHASE_NIGHT)
	assert_true(restored.get_environment_state().is_empty())


func test_environment_rejects_non_json_values() -> void:
	var state := GameState.new()
	assert_false(state.set_environment_state({"schema_version": 1, "offset": Vector2.ONE}))
	assert_true(state.get_environment_state().is_empty())

func _save_after_gate(
	service: SaveService,
	state: GameState,
	start_gate: Semaphore
) -> bool:
	start_gate.wait()
	return service.save_game(state)


func _errors_contain(result: Dictionary, needle: String) -> bool:
	var errors: Variant = result.get("errors", PackedStringArray())
	for entry in errors:
		if needle in String(entry):
			return true
	return false


func _service() -> SaveService:
	var service := SaveService.new()
	service.save_directory = _temp_dir("save_service")
	return service


func _temp_dir(label: String) -> String:
	var unique := "%s_%d" % [label, Time.get_ticks_usec()]
	return "%s/%s" % [_test_root, unique]


func _cleanup_temp_dir() -> void:
	if _test_root.is_empty():
		return
	_remove_tree(_test_root)


func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		DirAccess.remove_absolute(path)
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var child := "%s/%s" % [path, entry]
			if DirAccess.dir_exists_absolute(child):
				_remove_tree(child)
			else:
				DirAccess.remove_absolute(child)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)


func _rich_state() -> GameState:
	var state := GameState.new()
	state.set_phase(PHASE_NIGHT)
	state.player.health = 72.5
	state.player.stamina = 41.0
	state.player.location_id = &"reval_east"
	state.player.spawn_id = &"courtyard"
	state.set_fact(&"fact.seized_spearhead_seen", true)
	state.set_flag(&"flag.demo_talked_to_mart", true)
	state.set_relationship(&"rel.henning_trust", 2)
	state.adjust_pressure(GameState.PRESSURE_SUSPICION, 1)
	state.set_quest_state(&"quest.demo", &"active")
	state.set_location_state(LOC_SMITHY, &"night")
	state.bag.try_add(ITEM_HAMMER)
	state.bag.try_add(ITEM_SPEARHEAD)
	state.equip_from_bag(&"right_hand", ITEM_HAMMER)
	state.set_equipped_forge_technique(ForgeTechnique.ID_IRON)
	state.add_item(ITEM_SPEARHEAD)
	state.place_world_item(LOC_SMITHY, OBJ_SPEAR, ITEM_SPEARHEAD, Vector2(120, 80))
	state.mark_world_defaults_seeded(LOC_SMITHY)
	state.add_forged_record(
		ForgedRecord.new(RECORD_HONEST, COMMISSION, &"item.watch_buckle", &"honest_work")
	)
	return state


func _assert_states_equal(expected: GameState, actual: GameState) -> void:
	assert_eq(actual.get_version(), expected.get_version())
	assert_eq(actual.get_phase(), expected.get_phase())
	assert_true(is_equal_approx(actual.player.health, expected.player.health))
	assert_true(is_equal_approx(actual.player.stamina, expected.player.stamina))
	assert_eq(actual.player.location_id, expected.player.location_id)
	assert_eq(actual.player.spawn_id, expected.player.spawn_id)
	assert_eq(
		actual.get_fact(&"fact.seized_spearhead_seen"),
		expected.get_fact(&"fact.seized_spearhead_seen")
	)
	assert_eq(
		actual.get_flag(&"flag.demo_talked_to_mart"),
		expected.get_flag(&"flag.demo_talked_to_mart")
	)
	assert_eq(
		actual.get_relationship(&"rel.henning_trust"),
		expected.get_relationship(&"rel.henning_trust")
	)
	assert_eq(
		actual.get_pressure(GameState.PRESSURE_SUSPICION),
		expected.get_pressure(GameState.PRESSURE_SUSPICION)
	)
	assert_eq(actual.get_quest_state(&"quest.demo"), expected.get_quest_state(&"quest.demo"))
	assert_eq(actual.get_location_state(LOC_SMITHY), expected.get_location_state(LOC_SMITHY))
	assert_eq(actual.equipped_item(&"right_hand"), expected.equipped_item(&"right_hand"))
	assert_eq(actual.equipped_forge_technique(), expected.equipped_forge_technique())
	assert_eq(actual.bag.placements.size(), expected.bag.placements.size())
	assert_true(actual.has_item(ITEM_SPEARHEAD))
	assert_true(actual.is_world_item_placed(LOC_SMITHY, OBJ_SPEAR))
	assert_eq(
		actual.get_world_items(LOC_SMITHY)[0]["position"],
		expected.get_world_items(LOC_SMITHY)[0]["position"]
	)
	assert_true(actual.are_world_defaults_seeded(LOC_SMITHY))
	assert_eq(actual.get_forged_records().size(), expected.get_forged_records().size())
	assert_eq(
		MapParitySnapshot.serialize_value(actual.save_map_world_state()),
		MapParitySnapshot.serialize_value(expected.save_map_world_state())
	)
