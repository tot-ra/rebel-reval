extends "res://tests/godot/test_case.gd"

const ModelScript := preload("res://scripts/quest/investigative_quest_model.gd")
const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const PresenterScript := preload("res://tests/godot/dialogue_test_presenter.gd")

const VALID_DIR := "res://content/examples/valid"
const SUPPORT_DIR := "res://content/examples/support"

const QUEST_ID := &"quest.stolen_iron"
const DIALOGUE_ID := &"dialogue.investigation.stolen_iron_confront"
const CULPRIT := &"suspect.neighbor_apprentice"
const FACT_HARBOR := &"fact.stolen_iron.harbor_road_dry"
const FACT_COOPER := &"fact.stolen_iron.cooper_gauge_marks"
const FACT_SAWDUST := &"fact.stolen_iron.apprentice_sawdust"
const FACT_LEDGER := &"fact.stolen_iron.ledger_gap"

var db: ContentDB
var state: GameState
var evaluator: StateRuleEvaluator
var manager: QuestManager
var quest: Dictionary
var presenter: DialogueTestPresenter
var runner: DialogueRunner


func before_each() -> void:
	db = ContentDB.new()
	assert_true(db.load_from_directories([VALID_DIR, SUPPORT_DIR]))
	quest = db.get_quest(QUEST_ID)
	assert_false(quest.is_empty())
	state = GameState.new()
	state.set_phase(&"phase.investigation_morning")
	evaluator = StateRuleEvaluator.new()
	manager = QuestManager.new(db, state, evaluator)
	presenter = PresenterScript.new()
	runner = RunnerScript.new()
	runner.configure(db, state, presenter, evaluator)
	assert_true(manager.start_quest(QUEST_ID))


func _apply_clues(fact_ids: Array) -> void:
	for fact_id in fact_ids:
		state.set_fact(fact_id, true)


func _confrontation_node_for_clues(fact_ids: Array) -> String:
	_apply_clues(fact_ids)
	assert_true(runner.start(DIALOGUE_ID))
	return presenter.last_node_id


func test_clues_narrow_suspect_pool_in_different_orders() -> void:
	var order_a := [FACT_HARBOR, FACT_COOPER, FACT_SAWDUST]
	var order_b := [FACT_SAWDUST, FACT_HARBOR, FACT_COOPER]
	for fact_id in order_a:
		state.set_fact(fact_id, true)
	assert_eq(ModelScript.remaining_suspects(state, quest), [CULPRIT])
	for fact_id in order_b:
		state.set_fact(fact_id, false)
	for fact_id in order_b:
		state.set_fact(fact_id, true)
	assert_eq(ModelScript.remaining_suspects(state, quest), [CULPRIT])


func test_partial_clues_leave_multiple_suspects() -> void:
	_apply_clues([FACT_HARBOR])
	var remaining := ModelScript.remaining_suspects(state, quest)
	assert_eq(remaining.size(), 2)
	assert_true(CULPRIT in remaining)
	assert_true(&"suspect.lane_cooper" in remaining)


func test_confrontation_dialogue_varies_by_collected_clues() -> void:
	assert_eq(_confrontation_node_for_clues([]), "confront_blind")
	state = GameState.new()
	state.set_phase(&"phase.investigation_morning")
	runner.configure(db, state, presenter, evaluator)
	assert_eq(_confrontation_node_for_clues([FACT_HARBOR]), "confront_partial_harbor")
	state = GameState.new()
	runner.configure(db, state, presenter, evaluator)
	assert_eq(_confrontation_node_for_clues([FACT_SAWDUST]), "confront_partial_sawdust")
	state = GameState.new()
	runner.configure(db, state, presenter, evaluator)
	assert_eq(
		_confrontation_node_for_clues([FACT_HARBOR, FACT_COOPER]),
		"confront_narrow"
	)
	state = GameState.new()
	runner.configure(db, state, presenter, evaluator)
	assert_eq(
		_confrontation_node_for_clues([FACT_HARBOR, FACT_COOPER, FACT_SAWDUST]),
		"confront_resolved"
	)


func test_journal_lists_only_discovered_clues() -> void:
	_apply_clues([FACT_HARBOR, FACT_LEDGER])
	var snapshot := JournalModel.build_snapshot(state, db)
	var evidence: Array = snapshot.get("evidence", [])
	var fact_ids: Array[String] = []
	for entry in evidence:
		if String(entry.get("quest_id", "")) == String(QUEST_ID):
			fact_ids.append(String(entry.get("fact_id", "")))
	assert_eq(fact_ids.size(), 2)
	assert_true(String(FACT_HARBOR) in fact_ids)
	assert_true(String(FACT_LEDGER) in fact_ids)


func test_clue_traversal_reaches_distinct_outcomes() -> void:
	var branches := [
		{
			"clues": [FACT_HARBOR, FACT_COOPER, FACT_SAWDUST],
			"accused": CULPRIT,
			"transition": &"confront_correct",
			"state": &"resolved_correct",
		},
		{
			"clues": [FACT_HARBOR],
			"accused": CULPRIT,
			"transition": &"confront_uncertain",
			"state": &"resolved_uncertain",
		},
		{
			"clues": [],
			"accused": &"suspect.harbor_courier",
			"transition": &"confront_misaccused",
			"state": &"resolved_misaccused",
		},
	]
	for branch in branches:
		var branch_state := GameState.new()
		branch_state.set_phase(&"phase.investigation_morning")
		var branch_manager := QuestManager.new(db, branch_state, StateRuleEvaluator.new())
		assert_true(branch_manager.start_quest(QUEST_ID))
		for fact_id in branch["clues"]:
			branch_state.set_fact(fact_id, true)
		var outcome := ModelScript.resolve_outcome_id(
			branch_state,
			quest,
			branch["accused"]
		)
		assert_eq(
			ModelScript.transition_id_for_outcome(outcome),
			branch["transition"],
			"branch transition mismatch for clues %s" % str(branch["clues"])
		)
		assert_true(branch_manager.transition(QUEST_ID, branch["transition"]))
		assert_eq(branch_state.get_quest_state(QUEST_ID), branch["state"])


func test_discovered_clues_survive_save_round_trip() -> void:
	_apply_clues([FACT_HARBOR, FACT_SAWDUST])
	var payload := state.save_payload()
	var restored := GameState.new()
	assert_eq(restored.load_payload(payload).size(), 0)
	assert_true(restored.get_fact(FACT_HARBOR))
	assert_true(restored.get_fact(FACT_SAWDUST))
	var entries := ModelScript.journal_clue_entries(restored, quest)
	assert_eq(entries.size(), 2)
