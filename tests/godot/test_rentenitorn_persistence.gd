extends "res://tests/godot/test_case.gd"

const RentenitornState := preload("res://scripts/combat/rentenitorn_state_model.gd")
const RentenitornBossEncounter := preload("res://scripts/combat/rentenitorn_boss_encounter.gd")
const QUEST_ID := &"quest.bitter_brew"

var _test_root := ""


func before_each() -> void:
	_test_root = "user://test_rentenitorn_persistence/%d_%d" % [
		OS.get_process_id(), Time.get_ticks_usec()
	]


func after_each() -> void:
	_remove_tree(_test_root)


func test_state_round_trips_and_outcome_is_immutable() -> void:
	var state := GameState.new()
	assert_true(RentenitornState.record_entry(state))
	assert_true(RentenitornState.set_door_state(state, RentenitornState.DOOR_CLOSED))
	assert_true(RentenitornState.set_boss_outcome(state, RentenitornState.OUTCOME_BYPASS))
	assert_true(RentenitornState.mark_evidence_recorded(state))
	assert_false(RentenitornState.set_boss_outcome(state, RentenitornState.OUTCOME_KILL))
	assert_false(RentenitornState.mark_evidence_recorded(state))
	var expected := RentenitornState.snapshot(state)

	var service := SaveService.new()
	service.save_directory = "%s/save_service" % _test_root
	assert_true(service.save_game(state))
	var loaded := service.load_game()
	assert_true(loaded["ok"], ", ".join(loaded["errors"]))
	assert_eq(RentenitornState.snapshot(loaded["state"]), expected)


func test_strongroom_stays_sealed_until_the_watcher_is_resolved() -> void:
	var state := GameState.new()
	RentenitornState.record_entry(state)
	assert_eq(RentenitornState.snapshot(state)["strongroom_state"], RentenitornState.STRONGROOM_SEALED)
	assert_false(RentenitornState.open_strongroom(state), "sealed until an outcome exists")
	assert_true(RentenitornState.set_boss_outcome(state, RentenitornState.OUTCOME_KILL))
	assert_true(RentenitornState.open_strongroom(state))
	assert_false(RentenitornState.open_strongroom(state), "the strongroom opens once")
	assert_eq(RentenitornState.snapshot(state)["strongroom_state"], RentenitornState.STRONGROOM_OPEN)


func test_old_record_migrates_and_one_shot_loot_persists() -> void:
	var state := GameState.new()
	assert_true(state.map_world_state.record_object_delta(
		RentenitornState.LOCATION_ID,
		RentenitornState.OBJECT_ID,
		{"version": 0, "door": "closed", "boss": "kill", "strongroom": "open", "entries": 3},
	))
	var migrated := RentenitornState.ensure(state)
	assert_eq(migrated["state_version"], RentenitornState.CURRENT_VERSION)
	assert_eq(migrated["door_state"], RentenitornState.DOOR_CLOSED)
	assert_eq(migrated["boss_outcome"], RentenitornState.OUTCOME_KILL)
	assert_eq(migrated["strongroom_state"], RentenitornState.STRONGROOM_OPEN)
	assert_eq(migrated["entry_count"], 3)
	assert_true(RentenitornState.mark_loot_collected(state))
	assert_false(RentenitornState.mark_loot_collected(state))


func test_failed_retry_restores_pre_fight_payload_without_nodes() -> void:
	var state := GameState.new()
	RentenitornState.record_entry(state)
	state.set_quest_state(QUEST_ID, &"night_ready")
	state.set_flag(RentenitornBossEncounter.RESOLVED_FLAG, false)
	var checkpoint := EncounterCheckpoint.new()
	assert_true(RentenitornState.arm_retry(state, checkpoint))
	assert_eq(checkpoint.encounter_id, RentenitornState.RETRY_ENCOUNTER_ID)
	state.set_quest_state(QUEST_ID, &"night_fought")
	state.set_flag(RentenitornBossEncounter.RESOLVED_FLAG, true)
	assert_true(RentenitornState.mark_retry_failed(state, checkpoint))
	assert_eq(RentenitornState.snapshot(state)["retry_state"], RentenitornState.RETRY_FAILED)
	assert_true(RentenitornState.restore_retry(state, checkpoint))
	assert_eq(state.get_quest_state(QUEST_ID), &"night_ready")
	assert_false(state.get_flag(RentenitornBossEncounter.RESOLVED_FLAG))
	assert_eq(RentenitornState.snapshot(state)["retry_state"], RentenitornState.RETRY_ARMED)
	var serialized := MapParitySnapshot.serialize_value(state.save_payload())
	assert_false(serialized.contains("Node"))
	assert_true(serialized.contains("retry_state"))
	assert_true(RentenitornState.clear_retry(state, checkpoint))
	assert_false(checkpoint.is_armed)


func _remove_tree(path: String) -> void:
	if path.is_empty():
		return
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
