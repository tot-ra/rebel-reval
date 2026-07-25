extends "res://tests/godot/test_case.gd"

## P3-005: every retained major slice choice must carry a unique consequence
## signature within its decision group.

const ConsequenceModel := preload(
	"res://scripts/slice/vertical_slice_branch_consequence_model.gd"
)

const VALID_DIR := "res://content/examples/valid"
const SUPPORT_DIR := "res://content/examples/support"
const QUEST_ID := &"quest.makers_mark"
const TRANSITION_DISCOVER := &"discover_incident"
const FLAG_MART_MISSING := &"flag.mart_missing"


func test_choice_groups_have_unique_consequence_signatures() -> void:
	var report := ConsequenceModel.build_report()
	assert_true(
		report["all_choices_distinct"],
		"duplicate consequence signatures: %s" % str(report["errors"])
	)
	assert_eq(report["choice_count"], 12)
	assert_eq(report["choice_groups"].size(), 4)


func test_makers_mark_ledger_choices_apply_distinct_state_deltas() -> void:
	var db := ContentDB.new()
	assert_true(db.load_from_directories([VALID_DIR, SUPPORT_DIR]))
	var branches := [
		{
			"transition": &"preserve_ledger",
			"flag": &"flag.forge_ledger_preserved",
			"henning": 1,
			"mart": 0,
			"suspicion": 0,
		},
		{
			"transition": &"alter_ledger",
			"flag": &"flag.forge_ledger_altered",
			"henning": 0,
			"mart": 1,
			"suspicion": 0,
		},
		{
			"transition": &"destroy_ledger",
			"flag": &"flag.forge_ledger_destroyed",
			"henning": 0,
			"mart": 0,
			"suspicion": 1,
		},
	]
	for branch: Dictionary in branches:
		var state := GameState.new()
		var manager := QuestManager.new(db, state, StateRuleEvaluator.new())
		assert_true(manager.start_quest(QUEST_ID))
		assert_true(manager.transition(QUEST_ID, TRANSITION_DISCOVER))
		if branch["transition"] == &"destroy_ledger":
			state.set_flag(FLAG_MART_MISSING, true)
		assert_true(manager.transition(QUEST_ID, branch["transition"] as StringName))
		assert_true(state.get_flag(branch["flag"] as StringName))
		assert_eq(state.get_relationship(&"rel.henning_trust"), branch["henning"])
		assert_eq(state.get_relationship(&"rel.mart_trust"), branch["mart"])
		assert_eq(state.get_pressure(&"pressure.suspicion"), branch["suspicion"])
