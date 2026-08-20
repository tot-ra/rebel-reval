extends "res://tests/godot/test_case.gd"

## R-627: Nunnatorn's durable state is map-ID data, while retry remains a
## transient checkpoint that restores a GameState payload without scene nodes.

const NunnatornState := preload("res://scripts/combat/nunnatorn_state_model.gd")
const NunnatornEvidence := preload("res://scripts/quest/nunnatorn_evidence_model.gd")
const ENCOUNTER_ID := &"encounter.nunnatorn_boss"
const QUEST_ID := &"quest.bitter_brew"

var _test_root := ""


func before_each() -> void:
	_test_root = "user://test_nunnatorn_persistence/%d_%d" % [
		OS.get_process_id(), Time.get_ticks_usec()
	]


func after_each() -> void:
	_cleanup_temp_dir()


func test_fresh_entry_creates_stable_state_and_round_trips_through_save_service() -> void:
	var state := GameState.new()
	assert_true(NunnatornState.record_entry(state))
	var fresh := NunnatornState.snapshot(state)
	assert_eq(fresh["door_state"], NunnatornState.DOOR_OPEN)
	assert_eq(fresh["boss_outcome"], NunnatornState.OUTCOME_PENDING)
	assert_eq(fresh["entry_count"], 1)

	var service := _service()
	assert_true(service.save_game(state))
	var loaded := service.load_game()
	assert_true(loaded["ok"], ", ".join(loaded["errors"]))
	var restored := loaded["state"] as GameState
	assert_eq(NunnatornState.snapshot(restored), fresh)


func test_older_nunnatorn_record_migrates_with_safe_defaults() -> void:
	var state := GameState.new()
	assert_true(state.map_world_state.record_object_delta(
		NunnatornState.LOCATION_ID,
		NunnatornState.OBJECT_ID,
		{"version": 0, "door": "closed", "boss": "", "entries": 2}
	))

	var migrated := NunnatornState.ensure(state)
	assert_eq(migrated["state_version"], NunnatornState.CURRENT_VERSION)
	assert_eq(migrated["door_state"], NunnatornState.DOOR_CLOSED)
	assert_eq(migrated["boss_outcome"], NunnatornState.OUTCOME_PENDING)
	assert_false(migrated["loot_collected"])
	assert_false(migrated["evidence_recorded"])
	assert_eq(migrated["retry_state"], NunnatornState.RETRY_CLEAR)
	assert_eq(migrated["entry_count"], 2)


func test_failed_encounter_retry_restores_pre_fight_state_and_keeps_checkpoint_transient() -> void:
	var state := GameState.new()
	NunnatornState.record_entry(state)
	state.set_quest_state(QUEST_ID, &"night_ready")
	state.set_flag(&"flag.nunnatorn_boss_resolved", false)
	var checkpoint := EncounterCheckpoint.new()

	assert_true(NunnatornState.arm_retry(state, checkpoint))
	assert_true(checkpoint.is_armed)
	assert_eq(checkpoint.encounter_id, ENCOUNTER_ID)
	state.set_quest_state(QUEST_ID, &"night_fought")
	state.set_flag(&"flag.nunnatorn_boss_resolved", true)
	assert_true(NunnatornState.mark_retry_failed(state, checkpoint))
	assert_eq(NunnatornState.snapshot(state)["retry_state"], NunnatornState.RETRY_FAILED)

	assert_true(NunnatornState.restore_retry(state, checkpoint))
	assert_eq(state.get_quest_state(QUEST_ID), &"night_ready")
	assert_false(state.get_flag(&"flag.nunnatorn_boss_resolved"))
	assert_eq(NunnatornState.snapshot(state)["retry_state"], NunnatornState.RETRY_ARMED)

	var payload := state.save_payload()
	var serialized := MapParitySnapshot.serialize_value(payload)
	assert_false(serialized.contains("Node"))
	assert_false(serialized.contains("checkpoint_object"))
	assert_true(serialized.contains("retry_state"))
	assert_true(NunnatornState.clear_retry(state, checkpoint))
	assert_false(checkpoint.is_armed)


func test_lethal_and_alternate_outcomes_persist_without_being_overwritten_on_reentry() -> void:
	var lethal := GameState.new()
	NunnatornState.record_entry(lethal)
	assert_true(NunnatornState.set_door_state(lethal, NunnatornState.DOOR_CLOSED))
	assert_true(NunnatornState.set_boss_outcome(lethal, NunnatornState.OUTCOME_KILL))
	assert_true(NunnatornState.mark_loot_collected(lethal))
	assert_true(NunnatornState.mark_evidence_recorded(lethal))
	assert_false(NunnatornState.mark_loot_collected(lethal))
	assert_false(NunnatornState.set_boss_outcome(lethal, NunnatornState.OUTCOME_BYPASS))
	assert_true(NunnatornState.record_entry(lethal))
	assert_eq(NunnatornState.snapshot(lethal)["door_state"], NunnatornState.DOOR_CLOSED)
	assert_eq(NunnatornState.snapshot(lethal)["boss_outcome"], NunnatornState.OUTCOME_KILL)
	assert_true(NunnatornState.snapshot(lethal)["loot_collected"])
	assert_eq(NunnatornState.snapshot(lethal)["entry_count"], 2)

	var alternate := GameState.new()
	NunnatornState.record_entry(alternate)
	assert_true(NunnatornState.set_boss_outcome(alternate, NunnatornState.OUTCOME_BYPASS))
	assert_true(NunnatornState.mark_evidence_recorded(alternate))
	assert_false(NunnatornState.snapshot(alternate)["loot_collected"])
	assert_false(NunnatornState.set_boss_outcome(alternate, NunnatornState.OUTCOME_KILL))
	assert_eq(NunnatornState.snapshot(alternate)["boss_outcome"], NunnatornState.OUTCOME_BYPASS)


func test_nunnatorn_evidence_flags_and_stable_state_survive_save_load() -> void:
	var state := GameState.new()
	NunnatornState.record_entry(state)
	state.set_flag(NunnatornEvidence.DEFEATED_FLAG, true)
	assert_true(NunnatornState.set_boss_outcome(state, NunnatornState.OUTCOME_KILL))
	assert_true(NunnatornState.mark_loot_collected(state))
	assert_true(state.get_flag(NunnatornEvidence.DEFEATED_FLAG))

	var restored := GameState.new()
	assert_eq(restored.load_payload(state.save_payload()), [])
	assert_true(restored.get_flag(NunnatornEvidence.DEFEATED_FLAG))
	assert_eq(NunnatornState.snapshot(restored), NunnatornState.snapshot(state))


func _service() -> SaveService:
	var service := SaveService.new()
	service.save_directory = "%s/save_service" % _test_root
	return service


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
