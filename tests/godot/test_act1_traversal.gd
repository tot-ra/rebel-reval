extends "res://tests/godot/test_case.gd"

## P4-011: Act 1 traversal report covering every act-boundary ending, deliberate
## invalid transitions, and published Act 1 save fixtures.

const TraversalModel := preload("res://scripts/quest/act1_traversal_model.gd")
const StGeorgesModel := preload("res://scripts/quest/st_georges_night_quest_model.gd")
const AftermathModelScript := preload(
	"res://scripts/investigation/st_georges_night_aftermath_model.gd"
)
const Act1AftermathModel := preload("res://scripts/quest/act1_aftermath_model.gd")


func before_each() -> void:
	var db := ContentDB.new()
	assert_true(db.load_from_directories(StGeorgesModel.CONTENT_DIRS))
	SessionState.content_db = db
	SessionState.state = GameState.new()
	SessionState.state.bag.set_content_db(db)


func test_manifest_matches_model() -> void:
	var report := TraversalModel.validate_manifest()
	assert_true(report["valid"], str(report["errors"]))


func test_traversal_report_lists_reachable_act_boundary_endings() -> void:
	var reachable: Array[String] = []
	for boundary in TraversalModel.INTENDED_BOUNDARY_ENDINGS:
		var branch := TraversalModel.boundary_branch_for_id(boundary)
		assert_false(branch.is_empty(), "missing branch for %s" % boundary)
		var state := _reach_boundary(branch)
		assert_eq(
			String(state.get_act1_transition().get("act_boundary", "")),
			boundary
		)
		reachable.append("act_boundary:%s" % boundary)

	var rejected := _collect_rejected_invalid_transitions()
	var report := TraversalModel.build_report(reachable, rejected)
	assert_true(
		report["all_intended_endings_reachable"],
		"missing endings: %s" % str(report["missing_endings"])
	)
	assert_true(
		report["all_invalid_transitions_rejected"],
		"accepted invalid transitions: %s" % str(report["accepted_invalid_transitions"])
	)


func test_climax_commit_before_approach_is_rejected() -> void:
	var state := GameState.new()
	var manager := QuestManager.new(SessionState.content_db, state, StateRuleEvaluator.new())
	assert_true(manager.start_quest(StGeorgesModel.QUEST_ID))
	state.set_phase(StGeorgesModel.PHASE_ACT1_CLIMAX)
	state.set_flag(StGeorgesModel.FLAG_SEAL_BIAS, true)
	assert_false(
		AftermathModelScript.commit_climax_choice(
			state,
			SessionState.content_db,
			StGeorgesModel.TRANSITION_COMMIT_SEAL
		)
	)
	assert_false(state.has_act1_transition())


func test_terminal_climax_recommit_is_rejected() -> void:
	var branch := TraversalModel.boundary_branch_for_id("seal")
	var state := _reach_boundary(branch)
	var manager := QuestManager.new(SessionState.content_db, state, StateRuleEvaluator.new())
	assert_false(
		manager.transition(StGeorgesModel.QUEST_ID, StGeorgesModel.TRANSITION_COMMIT_SEAL)
	)


func test_record_transition_without_recorded_flag_is_rejected() -> void:
	var state := GameState.new()
	state.set_flag(StGeorgesModel.FLAG_SEAL_BIAS, true)
	assert_false(Act1AftermathModel.record_transition(state))
	assert_false(state.has_act1_transition())


func test_unknown_climax_transition_is_rejected() -> void:
	var state := GameState.new()
	var manager := QuestManager.new(SessionState.content_db, state, StateRuleEvaluator.new())
	assert_true(manager.start_quest(StGeorgesModel.QUEST_ID))
	assert_true(manager.transition(StGeorgesModel.QUEST_ID, StGeorgesModel.TRANSITION_BEGIN_APPROACH))
	state.set_phase(StGeorgesModel.PHASE_ACT1_CLIMAX)
	assert_false(manager.transition(StGeorgesModel.QUEST_ID, &"commit_unknown_choice"))


func test_premature_act1_envelope_fails_validation() -> void:
	var state := GameState.new()
	state.set_flag(&"flag.act_transition.act1_recorded", true)
	var envelope := Act1AftermathModel.build_envelope(state)
	var validation := Act1AftermathModel.validate_envelope(envelope)
	assert_false(validation["valid"])


func test_every_act1_fixture_loads_and_round_trips() -> void:
	for relative_path in TraversalModel.fixture_paths():
		var full_path := "res://content/saves/%s" % relative_path
		var result := SaveEnvelope.parse_file(full_path)
		assert_true(result["ok"], "%s must load: %s" % [relative_path, ", ".join(result["errors"])])
		var state := result["state"] as GameState
		assert_true(state.has_act1_transition())
		var validation := Act1AftermathModel.validate_envelope(state.get_act1_transition())
		assert_true(validation["valid"], "%s envelope invalid: %s" % [relative_path, str(validation["errors"])])

		var payload := state.save_payload()
		var restored := GameState.new()
		var errors := restored.load_payload(payload)
		assert_eq(errors.size(), 0, "%s round-trip errors: %s" % [relative_path, str(errors)])
		assert_eq(restored.get_act1_transition(), state.get_act1_transition())


func _reach_boundary(branch: Dictionary) -> GameState:
	var state := GameState.new()
	state.bag.set_content_db(SessionState.content_db)
	state.set_phase(StGeorgesModel.PHASE_ACT1_CLIMAX)
	var manager := QuestManager.new(SessionState.content_db, state, StateRuleEvaluator.new())
	assert_true(manager.start_quest(StGeorgesModel.QUEST_ID))
	assert_true(manager.transition(StGeorgesModel.QUEST_ID, StGeorgesModel.TRANSITION_BEGIN_APPROACH))
	state.set_flag(branch["bias"] as StringName, true)
	assert_true(
		AftermathModelScript.commit_climax_choice(
			state,
			SessionState.content_db,
			branch["transition"] as StringName
		)
	)
	assert_eq(state.get_quest_state(StGeorgesModel.QUEST_ID), branch["terminal_state"])
	assert_true(state.get_flag(branch["boundary_flag"] as StringName))
	return state


func _collect_rejected_invalid_transitions() -> Array[String]:
	var rejected: Array[String] = []

	var latent := GameState.new()
	var manager := QuestManager.new(SessionState.content_db, latent, StateRuleEvaluator.new())
	assert_true(manager.start_quest(StGeorgesModel.QUEST_ID))
	latent.set_phase(StGeorgesModel.PHASE_ACT1_CLIMAX)
	latent.set_flag(StGeorgesModel.FLAG_SEAL_BIAS, true)
	if not AftermathModelScript.commit_climax_choice(
		latent,
		SessionState.content_db,
		StGeorgesModel.TRANSITION_COMMIT_SEAL
	):
		rejected.append("invalid.climax.before_approach")

	var terminal := _reach_boundary(TraversalModel.boundary_branch_for_id("seal"))
	manager = QuestManager.new(SessionState.content_db, terminal, StateRuleEvaluator.new())
	if not manager.transition(StGeorgesModel.QUEST_ID, StGeorgesModel.TRANSITION_COMMIT_SEAL):
		rejected.append("invalid.climax.terminal_recommit")

	var unknown := GameState.new()
	manager = QuestManager.new(SessionState.content_db, unknown, StateRuleEvaluator.new())
	assert_true(manager.start_quest(StGeorgesModel.QUEST_ID))
	assert_true(manager.transition(StGeorgesModel.QUEST_ID, StGeorgesModel.TRANSITION_BEGIN_APPROACH))
	unknown.set_phase(StGeorgesModel.PHASE_ACT1_CLIMAX)
	if not manager.transition(StGeorgesModel.QUEST_ID, &"commit_unknown_choice"):
		rejected.append("invalid.climax.unknown_transition")

	var premature := GameState.new()
	premature.set_flag(&"flag.act_transition.act1_recorded", true)
	var envelope := Act1AftermathModel.build_envelope(premature)
	if not Act1AftermathModel.validate_envelope(envelope)["valid"]:
		rejected.append("invalid.act1.premature_envelope")

	var branch := TraversalModel.boundary_branch_for_id("seal")
	var recorded := _reach_boundary(branch)
	if recorded.has_act1_transition():
		recorded.set_flag(&"flag.act_transition.act1_recorded", false)
		if not Act1AftermathModel.record_transition(recorded):
			rejected.append("invalid.act1.record_without_flag")

	return rejected
