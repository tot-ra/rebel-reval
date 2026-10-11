extends "res://tests/godot/test_case.gd"

## R-626: loot is lethal-only, while both boss outcomes leave a visible journal fact.
## Collection is deliberately one-shot so re-entering Nunnatorn cannot duplicate loot.

const NunnatornEvidenceModelScript := preload("res://scripts/quest/nunnatorn_evidence_model.gd")
const ITEM_ID := &"item.nunnatorn_evidence"
const QUEST_ID := &"quest.nunnatorn_evidence"
const LEDGER_FACT_ID := &"fact.nunnatorn.evidence.ledger"
const WITNESS_FACT_ID := &"fact.nunnatorn.evidence.witness_account"


func test_content_exposes_loot_and_two_journal_records() -> void:
	var db := _content_db()
	var item := db.get_item(ITEM_ID)
	var quest := db.get_quest(QUEST_ID)
	assert_eq(item.get("category", ""), "evidence")
	assert_eq(quest.get("content_links", {}).get("item_ids", [])[0], ITEM_ID)
	assert_eq(quest.get("journal_evidence", []).size(), 2)


func test_lethal_resolution_collects_item_and_ledger_fact_once() -> void:
	var db := _content_db()
	var state := _state_with_outcome(NunnatornEvidenceModelScript.DEFEATED_FLAG)

	assert_true(NunnatornEvidenceModelScript.collect(state, db))
	assert_eq(state.get_quest_state(QUEST_ID), NunnatornEvidenceModelScript.LETHAL_STATE)
	assert_true(state.has_item(ITEM_ID))
	assert_true(state.get_fact(LEDGER_FACT_ID))
	assert_false(state.get_fact(WITNESS_FACT_ID))
	assert_true(state.get_flag(NunnatornEvidenceModelScript.LOOT_COLLECTED_FLAG))
	assert_false(
		NunnatornEvidenceModelScript.collect(state, db),
		"re-entry must not duplicate lethal loot"
	)
	assert_eq(state.get_owned_item_ids_in_order().count(ITEM_ID), 1)
	assert_eq(JournalModel.build_snapshot(state, db)["evidence"].size(), 1)


func test_alternate_resolution_records_witness_without_lethal_loot() -> void:
	var db := _content_db()
	var state := _state_with_outcome(NunnatornEvidenceModelScript.ALTERNATE_FLAG)

	assert_true(NunnatornEvidenceModelScript.collect(state, db))
	assert_eq(state.get_quest_state(QUEST_ID), NunnatornEvidenceModelScript.ALTERNATE_STATE)
	assert_false(state.has_item(ITEM_ID))
	assert_false(state.get_fact(LEDGER_FACT_ID))
	assert_true(state.get_fact(WITNESS_FACT_ID))
	assert_true(state.get_flag(NunnatornEvidenceModelScript.EVIDENCE_RECORDED_FLAG))
	assert_false(
		NunnatornEvidenceModelScript.collect(state, db),
		"re-entry must not duplicate alternate evidence"
	)
	assert_eq(JournalModel.build_snapshot(state, db)["evidence"].size(), 1)


func test_mixed_outcome_flags_fail_closed_without_starting_collection() -> void:
	var db := _content_db()
	var state := GameState.new()
	state.set_flag(NunnatornEvidenceModelScript.DEFEATED_FLAG, true)
	state.set_flag(NunnatornEvidenceModelScript.ALTERNATE_FLAG, true)

	assert_false(NunnatornEvidenceModelScript.collect(state, db))
	assert_eq(state.get_quest_state(QUEST_ID), &"")
	assert_false(state.has_item(ITEM_ID))


func _content_db() -> ContentDB:
	var db := ContentDB.new()
	assert_true(db.load_from_directories(SessionState.DEMO_CONTENT_DIRS))
	return db


func _state_with_outcome(outcome_flag: StringName) -> GameState:
	var state := GameState.new()
	state.set_flag(outcome_flag, true)
	return state
