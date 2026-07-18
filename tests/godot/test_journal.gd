extends "res://tests/godot/test_case.gd"

const VALID_DIR := "res://content/examples/valid"
const SUPPORT_DIR := "res://content/examples/support"

const QUEST_ID := &"quest.makers_mark"
const STATE_NOT_STARTED := &"not_started"
const STATE_INCIDENT_KNOWN := &"incident_known"
const STATE_LEDGER_COMMITTED := &"ledger_committed"
const FACT_SPEARHEAD := &"fact.seized_spearhead_seen"


var db: ContentDB
var state: GameState


func before_each() -> void:
	db = ContentDB.new()
	assert_true(db.load_from_directories([VALID_DIR, SUPPORT_DIR]))
	state = GameState.new()


func test_empty_snapshot_when_no_active_quests() -> void:
	var snapshot := JournalModel.build_snapshot(state, db)
	assert_eq((snapshot.get("objectives", []) as Array).size(), 0)
	assert_eq((snapshot.get("evidence", []) as Array).size(), 0)


func test_current_objective_follows_quest_state() -> void:
	state.set_quest_state(QUEST_ID, STATE_NOT_STARTED)
	var snapshot := JournalModel.build_snapshot(state, db)
	var objectives: Array = snapshot.get("objectives", [])
	assert_eq(objectives.size(), 1)
	assert_eq(String(objectives[0].get("objective_id", "")), "inspect_spearhead")
	assert_eq(String(objectives[0].get("text", "")), "Inspect the seized spearhead.")

	state.set_quest_state(QUEST_ID, STATE_INCIDENT_KNOWN)
	snapshot = JournalModel.build_snapshot(state, db)
	objectives = snapshot.get("objectives", [])
	assert_eq(objectives.size(), 1)
	assert_eq(String(objectives[0].get("objective_id", "")), "commit_ledger")


func test_terminal_quest_hides_objective() -> void:
	state.set_quest_state(QUEST_ID, STATE_LEDGER_COMMITTED)
	var snapshot := JournalModel.build_snapshot(state, db)
	assert_eq((snapshot.get("objectives", []) as Array).size(), 0)


func test_discovered_evidence_uses_authored_journal_entries() -> void:
	state.set_quest_state(QUEST_ID, STATE_NOT_STARTED)
	state.set_fact(FACT_SPEARHEAD, true)

	var snapshot := JournalModel.build_snapshot(state, db)
	var evidence: Array = snapshot.get("evidence", [])
	assert_eq(evidence.size(), 1)
	assert_eq(evidence[0].get("fact_id", &""), FACT_SPEARHEAD)
	assert_true(String(evidence[0].get("text", "")).contains("spearhead"))


func test_hidden_outcomes_and_unknown_facts_stay_out_of_journal() -> void:
	state.set_quest_state(QUEST_ID, STATE_INCIDENT_KNOWN)
	state.set_flag(&"flag.forge_ledger_preserved", true)

	var snapshot := JournalModel.build_snapshot(state, db)
	for entry in snapshot.get("evidence", []) as Array:
		var text := String((entry as Dictionary).get("text", "")).to_lower()
		assert_false(text.contains("preserved"))
		assert_false(text.contains("altered"))
		assert_false(text.contains("destroyed"))


func test_journal_state_survives_save_round_trip() -> void:
	state.set_quest_state(QUEST_ID, STATE_INCIDENT_KNOWN)
	state.set_fact(FACT_SPEARHEAD, true)

	var before := JournalModel.build_snapshot(state, db)
	var payload := state.save_payload()
	var restored := GameState.new()
	assert_eq(restored.load_payload(payload).size(), 0)

	var after := JournalModel.build_snapshot(restored, db)
	assert_eq(after, before)
