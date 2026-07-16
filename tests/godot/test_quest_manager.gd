extends "res://tests/godot/test_case.gd"

const VALID_DIR := "res://content/examples/valid"
const SUPPORT_DIR := "res://content/examples/support"

const QUEST_ID := &"quest.makers_mark"
const STATE_NOT_STARTED := &"not_started"
const STATE_INCIDENT_KNOWN := &"incident_known"
const STATE_LEDGER_COMMITTED := &"ledger_committed"

const TRANSITION_DISCOVER := &"discover_incident"
const FLAG_INCIDENT := &"flag.prologue_maker_mark_incident"
const FLAG_MART_MISSING := &"flag.mart_missing"
const FLAG_PRESERVED := &"flag.forge_ledger_preserved"
const FLAG_ALTERED := &"flag.forge_ledger_altered"
const PRESSURE_SUSPICION := &"pressure.suspicion"

var db: ContentDB
var state: GameState
var evaluator: StateRuleEvaluator
var manager: QuestManager


func before_each() -> void:
	db = ContentDB.new()
	assert_true(db.load_from_directories([VALID_DIR, SUPPORT_DIR]), "validated quest corpus should load")
	state = GameState.new()
	evaluator = StateRuleEvaluator.new()
	manager = QuestManager.new(db, state, evaluator)


func test_start_quest_uses_declared_initial_state_and_entry_conditions() -> void:
	assert_true(manager.start_quest(QUEST_ID))
	assert_eq(state.get_quest_state(QUEST_ID), STATE_NOT_STARTED)
	assert_eq(manager.get_last_result(), QuestManager.Result.OK)

	assert_false(manager.start_quest(QUEST_ID))
	assert_eq(manager.get_last_result(), QuestManager.Result.ALREADY_STARTED)
	assert_eq(state.get_quest_state(QUEST_ID), STATE_NOT_STARTED)


func test_every_declared_slice_transition_is_traversable() -> void:
	var branches := [
		{
			"id": &"preserve_ledger",
			"flag": FLAG_PRESERVED,
			"pressure": 0,
		},
		{
			"id": &"alter_ledger",
			"flag": FLAG_ALTERED,
			"pressure": 0,
		},
		{
			"id": &"destroy_ledger",
			"flag": &"",
			"pressure": 1,
		},
	]

	for branch in branches:
		var branch_state := GameState.new()
		var branch_manager := QuestManager.new(db, branch_state, StateRuleEvaluator.new())
		assert_true(branch_manager.start_quest(QUEST_ID), "start should succeed for %s" % branch["id"])
		assert_true(branch_manager.transition(QUEST_ID, TRANSITION_DISCOVER))
		assert_eq(branch_state.get_quest_state(QUEST_ID), STATE_INCIDENT_KNOWN)
		assert_true(branch_state.get_flag(FLAG_INCIDENT))

		if branch["id"] == &"destroy_ledger":
			branch_state.set_flag(FLAG_MART_MISSING, true)
		assert_true(branch_manager.transition(QUEST_ID, branch["id"]), "branch should succeed: %s" % branch["id"])
		assert_eq(branch_state.get_quest_state(QUEST_ID), STATE_LEDGER_COMMITTED)
		assert_eq(branch_state.get_pressure(PRESSURE_SUSPICION), branch["pressure"])
		if not (branch["flag"] as StringName).is_empty():
			assert_true(branch_state.get_flag(branch["flag"]))


func test_transition_rejects_wrong_source_state_without_partial_mutation() -> void:
	assert_true(manager.start_quest(QUEST_ID))

	assert_false(manager.transition(QUEST_ID, &"preserve_ledger"))
	assert_eq(manager.get_last_result(), QuestManager.Result.INVALID_CURRENT_STATE)
	assert_eq(state.get_quest_state(QUEST_ID), STATE_NOT_STARTED)
	assert_false(state.get_flag(FLAG_PRESERVED))


func test_transition_rejects_unmet_conditions_without_partial_mutation() -> void:
	assert_true(manager.start_quest(QUEST_ID))
	assert_true(manager.transition(QUEST_ID, TRANSITION_DISCOVER))

	assert_false(manager.transition(QUEST_ID, &"destroy_ledger"))
	assert_eq(manager.get_last_result(), QuestManager.Result.CONDITIONS_NOT_MET)
	assert_eq(state.get_quest_state(QUEST_ID), STATE_INCIDENT_KNOWN)
	assert_eq(state.get_pressure(PRESSURE_SUSPICION), 0)


func test_unknown_transition_and_quest_are_rejected_without_mutation() -> void:
	assert_true(manager.start_quest(QUEST_ID))
	var before := state.get_quest_state(QUEST_ID)

	assert_false(manager.transition(QUEST_ID, &"teleport_to_ending"))
	assert_eq(manager.get_last_result(), QuestManager.Result.UNKNOWN_TRANSITION)
	assert_eq(state.get_quest_state(QUEST_ID), before)
	assert_false(state.get_flag(FLAG_INCIDENT))

	assert_false(manager.transition(&"quest.unknown", TRANSITION_DISCOVER))
	assert_eq(manager.get_last_result(), QuestManager.Result.UNKNOWN_QUEST)
	assert_eq(state.get_quest_state(QUEST_ID), before)


func test_invalid_effect_batch_is_rejected_before_any_mutation() -> void:
	var fixture_dir := "user://quest_manager_invalid_effect_%d" % Time.get_ticks_msec()
	_write_json(fixture_dir.path_join("quest.json"), _quest_fixture([
		{"op": "set_flag", "key": "flag.should_not_change", "value": true},
		{"op": "script", "key": "flag.injected", "value": true},
	]))
	var fixture_db := ContentDB.new()
	assert_true(fixture_db.load_from_directories([fixture_dir]))
	var fixture_state := GameState.new()
	fixture_state.set_quest_state(&"quest.atomic_fixture", &"open")
	var fixture_manager := QuestManager.new(fixture_db, fixture_state, StateRuleEvaluator.new())

	assert_false(fixture_manager.transition(&"quest.atomic_fixture", &"complete"))
	assert_eq(fixture_manager.get_last_result(), QuestManager.Result.INVALID_QUEST_RECORD)
	assert_eq(fixture_state.get_quest_state(&"quest.atomic_fixture"), &"open")
	assert_false(fixture_state.get_flag(&"flag.should_not_change"))
	assert_false(fixture_state.get_flag(&"flag.injected"))
	_remove_tree(fixture_dir)


func test_transition_applies_effects_in_authored_order_before_target_state() -> void:
	var fixture_dir := "user://quest_manager_effect_order_%d" % Time.get_ticks_msec()
	_write_json(fixture_dir.path_join("quest.json"), _quest_fixture([
		{"op": "adjust_pressure", "key": "pressure.suspicion", "amount": -1},
		{"op": "adjust_pressure", "key": "pressure.suspicion", "amount": 1},
	]))
	var fixture_db := ContentDB.new()
	assert_true(fixture_db.load_from_directories([fixture_dir]))
	var fixture_state := GameState.new()
	fixture_state.set_quest_state(&"quest.atomic_fixture", &"open")
	var fixture_manager := QuestManager.new(fixture_db, fixture_state, StateRuleEvaluator.new())

	assert_true(fixture_manager.transition(&"quest.atomic_fixture", &"complete"))
	assert_eq(fixture_state.get_pressure(PRESSURE_SUSPICION), 1)
	assert_eq(fixture_state.get_quest_state(&"quest.atomic_fixture"), &"done")
	_remove_tree(fixture_dir)


func test_invalid_declared_destination_is_rejected_without_mutation() -> void:
	var fixture_dir := "user://quest_manager_invalid_destination_%d" % Time.get_ticks_msec()
	var fixture := _quest_fixture([])
	(fixture["transitions"] as Array)[0]["to_state"] = "missing"
	_write_json(fixture_dir.path_join("quest.json"), fixture)
	var fixture_db := ContentDB.new()
	assert_true(fixture_db.load_from_directories([fixture_dir]))
	var fixture_state := GameState.new()
	fixture_state.set_quest_state(&"quest.atomic_fixture", &"open")
	var fixture_manager := QuestManager.new(fixture_db, fixture_state, StateRuleEvaluator.new())

	assert_false(fixture_manager.transition(&"quest.atomic_fixture", &"complete"))
	assert_eq(fixture_manager.get_last_result(), QuestManager.Result.INVALID_QUEST_RECORD)
	assert_eq(fixture_state.get_quest_state(&"quest.atomic_fixture"), &"open")
	_remove_tree(fixture_dir)


func _quest_fixture(effects: Array) -> Dictionary:
	return {
		"type": "quest",
		"id": "quest.atomic_fixture",
		"entry_conditions": [],
		"initial_state": "open",
		"states": [
			{"id": "open"},
			{"id": "done"},
		],
		"transitions": [
			{
				"id": "complete",
				"from_state": "open",
				"to_state": "done",
				"effects": effects,
			},
		],
	}


func _write_json(path: String, body: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_true(file != null, "fixture file should be writable: %s" % path)
	file.store_string(JSON.stringify(body))


func _remove_tree(path: String) -> void:
	_remove_absolute_tree(ProjectSettings.globalize_path(path))


func _remove_absolute_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var child := path.path_join(entry)
			if dir.current_is_dir():
				_remove_absolute_tree(child)
			else:
				DirAccess.remove_absolute(child)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)
