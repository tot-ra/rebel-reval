extends "res://tests/godot/test_case.gd"

const LOC_SMITHY := &"loc.kalev_smithy"
const OBJ_SPEAR := &"world.spearhead_anvil"
const ITEM_HAMMER := &"item.forge_hammer"
const ITEM_SPEARHEAD := &"item.seized_spearhead"
const PHASE_NIGHT := &"phase.investigation_night"
const RECORD_HONEST := &"forged.watch_buckle_repair.honest_work"
const COMMISSION := &"commission.watch_buckle_repair"


func before_each() -> void:
	_cleanup_temp_dir()


func after_each() -> void:
	_cleanup_temp_dir()


func test_round_trip_preserves_full_game_state() -> void:
	var original := _rich_state()
	var service := _service()

	assert_true(service.save_game(original))
	var loaded := service.load_game()
	assert_true(loaded["ok"])
	_assert_states_equal(original, loaded["state"] as GameState)


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


func test_game_state_payload_round_trip_without_files() -> void:
	var original := _rich_state()
	var payload := original.save_payload()
	var restored := GameState.new()
	var errors := restored.load_payload(payload)
	assert_eq(errors.size(), 0)
	_assert_states_equal(original, restored)


func _service() -> SaveService:
	var service := SaveService.new()
	service.save_directory = _temp_dir("save_service")
	return service


func _temp_dir(label: String) -> String:
	var unique := "%s_%d" % [label, Time.get_ticks_usec()]
	return "user://test_saves/%s" % unique


func _cleanup_temp_dir() -> void:
	var root := DirAccess.open("user://test_saves")
	if root == null:
		return
	root.list_dir_begin()
	var entry := root.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			_remove_tree("user://test_saves/%s" % entry)
		entry = root.get_next()
	root.list_dir_end()


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
	assert_eq(actual.get_fact(&"fact.seized_spearhead_seen"), expected.get_fact(&"fact.seized_spearhead_seen"))
	assert_eq(actual.get_flag(&"flag.demo_talked_to_mart"), expected.get_flag(&"flag.demo_talked_to_mart"))
	assert_eq(actual.get_relationship(&"rel.henning_trust"), expected.get_relationship(&"rel.henning_trust"))
	assert_eq(actual.get_pressure(GameState.PRESSURE_SUSPICION), expected.get_pressure(GameState.PRESSURE_SUSPICION))
	assert_eq(actual.get_quest_state(&"quest.demo"), expected.get_quest_state(&"quest.demo"))
	assert_eq(actual.get_location_state(LOC_SMITHY), expected.get_location_state(LOC_SMITHY))
	assert_eq(actual.equipped_item(&"right_hand"), expected.equipped_item(&"right_hand"))
	assert_eq(actual.equipped_forge_technique(), expected.equipped_forge_technique())
	assert_eq(actual.bag.placements.size(), expected.bag.placements.size())
	assert_true(actual.has_item(ITEM_SPEARHEAD))
	assert_true(actual.is_world_item_placed(LOC_SMITHY, OBJ_SPEAR))
	assert_true(actual.are_world_defaults_seeded(LOC_SMITHY))
	assert_eq(actual.get_forged_records().size(), expected.get_forged_records().size())
	assert_eq(
		MapParitySnapshot.serialize_value(actual.save_map_world_state()),
		MapParitySnapshot.serialize_value(expected.save_map_world_state())
	)
