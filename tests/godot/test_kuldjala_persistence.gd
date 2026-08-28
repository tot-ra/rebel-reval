extends "res://tests/godot/test_case.gd"

const KuldjalaState := preload("res://scripts/combat/kuldjala_state_model.gd")
const KuldjalaBossEncounter := preload("res://scripts/combat/kuldjala_boss_encounter.gd")
const QUEST_ID := &"quest.bitter_brew"

var _test_root := ""


func before_each() -> void:
	_test_root = "user://test_kuldjala_persistence/%d_%d" % [
		OS.get_process_id(), Time.get_ticks_usec()
	]


func after_each() -> void:
	_remove_tree(_test_root)


func test_state_round_trips_and_outcome_is_immutable() -> void:
	var state := GameState.new()
	assert_true(KuldjalaState.record_entry(state))
	assert_true(KuldjalaState.set_door_state(state, KuldjalaState.DOOR_CLOSED))
	assert_true(KuldjalaState.set_boss_outcome(state, KuldjalaState.OUTCOME_BYPASS))
	assert_true(KuldjalaState.mark_evidence_recorded(state))
	assert_false(KuldjalaState.set_boss_outcome(state, KuldjalaState.OUTCOME_KILL))
	assert_false(KuldjalaState.mark_evidence_recorded(state))
	var expected := KuldjalaState.snapshot(state)

	var service := SaveService.new()
	service.save_directory = "%s/save_service" % _test_root
	assert_true(service.save_game(state))
	var loaded := service.load_game()
	assert_true(loaded["ok"], ", ".join(loaded["errors"]))
	assert_eq(KuldjalaState.snapshot(loaded["state"]), expected)


func test_old_record_migrates_and_one_shot_loot_persists() -> void:
	var state := GameState.new()
	assert_true(state.map_world_state.record_object_delta(
		KuldjalaState.LOCATION_ID,
		KuldjalaState.OBJECT_ID,
		{"version": 0, "door": "closed", "boss": "kill", "entries": 2},
	))
	var migrated := KuldjalaState.ensure(state)
	assert_eq(migrated["state_version"], KuldjalaState.CURRENT_VERSION)
	assert_eq(migrated["door_state"], KuldjalaState.DOOR_CLOSED)
	assert_eq(migrated["boss_outcome"], KuldjalaState.OUTCOME_KILL)
	assert_eq(migrated["entry_count"], 2)
	assert_true(KuldjalaState.mark_loot_collected(state))
	assert_false(KuldjalaState.mark_loot_collected(state))


func test_failed_retry_restores_pre_fight_payload_without_nodes() -> void:
	var state := GameState.new()
	KuldjalaState.record_entry(state)
	state.set_quest_state(QUEST_ID, &"night_ready")
	state.set_flag(KuldjalaBossEncounter.RESOLVED_FLAG, false)
	var checkpoint := EncounterCheckpoint.new()
	assert_true(KuldjalaState.arm_retry(state, checkpoint))
	assert_eq(checkpoint.encounter_id, KuldjalaState.RETRY_ENCOUNTER_ID)
	state.set_quest_state(QUEST_ID, &"night_fought")
	state.set_flag(KuldjalaBossEncounter.RESOLVED_FLAG, true)
	assert_true(KuldjalaState.mark_retry_failed(state, checkpoint))
	assert_eq(KuldjalaState.snapshot(state)["retry_state"], KuldjalaState.RETRY_FAILED)
	assert_true(KuldjalaState.restore_retry(state, checkpoint))
	assert_eq(state.get_quest_state(QUEST_ID), &"night_ready")
	assert_false(state.get_flag(KuldjalaBossEncounter.RESOLVED_FLAG))
	assert_eq(KuldjalaState.snapshot(state)["retry_state"], KuldjalaState.RETRY_ARMED)
	var serialized := MapParitySnapshot.serialize_value(state.save_payload())
	assert_false(serialized.contains("Node"))
	assert_true(serialized.contains("retry_state"))
	assert_true(KuldjalaState.clear_retry(state, checkpoint))
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
