extends "res://tests/godot/test_case.gd"

## P4-042: Act 1 standalone-candidate preflight.
## WHY: P4-012 needs independent QA evidence that every accepted boundary starts
## from a clean save, rejects invalid transitions, migrates legacy envelopes, and
## reloads without state loss - without repairing runtime or inventing branches.

const TraversalModel := preload("res://scripts/quest/act1_traversal_model.gd")
const StGeorgesModel := preload("res://scripts/quest/st_georges_night_quest_model.gd")
const AftermathModelScript := preload(
	"res://scripts/investigation/st_georges_night_aftermath_model.gd"
)
const Act1AftermathModel := preload("res://scripts/quest/act1_aftermath_model.gd")

const CLEAN_START_PATH := "res://tests/fixtures/act1_candidate/clean_start.json"
const LEGACY_SEAL_PATH := "res://tests/fixtures/act1_candidate/game_state_v1_boundary_seal.json"
const BUDGET_MANIFEST_PATH := "res://docs/data/act1_content_budget_manifest.json"

const EXPECTED_SUBSTANTIAL_QUEST_BUDGET := 8
const EXPECTED_CLIMAX_QUEST_COUNT := 1

var _save_directory := ""


func before_each() -> void:
	var db := ContentDB.new()
	assert_true(db.load_from_directories(StGeorgesModel.CONTENT_DIRS))
	SessionState.content_db = db
	SessionState.state = GameState.new()
	SessionState.state.bag.set_content_db(db)
	_cleanup_save_directory()


func after_each() -> void:
	_cleanup_save_directory()


func test_candidate_budget_stays_eight_quests_and_one_climax() -> void:
	var budget := _load_json_dictionary(BUDGET_MANIFEST_PATH)
	assert_false(budget.is_empty(), "Act 1 content-budget manifest must load")
	assert_eq(
		int(budget.get("substantial_quest_budget", -1)),
		EXPECTED_SUBSTANTIAL_QUEST_BUDGET,
		"candidate must keep the accepted eight-quest budget"
	)
	var substantial: Variant = budget.get("substantial_quest_ids", [])
	assert_true(substantial is Array)
	assert_eq(
		(substantial as Array).size(),
		EXPECTED_SUBSTANTIAL_QUEST_BUDGET,
		"substantial_quest_ids must list exactly eight quests"
	)
	var climax: Variant = budget.get("climax_quest_ids", [])
	assert_true(climax is Array)
	assert_eq(
		(climax as Array).size(),
		EXPECTED_CLIMAX_QUEST_COUNT,
		"candidate must keep exactly one climax quest"
	)
	assert_eq(
		TraversalModel.INTENDED_BOUNDARY_ENDINGS.size(),
		3,
		"candidate must not invent a fourth act-boundary branch"
	)


func test_clean_start_fixture_has_no_act1_transition() -> void:
	var result := SaveEnvelope.parse_file(CLEAN_START_PATH)
	assert_true(result["ok"], "clean_start must load: %s" % ", ".join(result["errors"]))
	var state := result["state"] as GameState
	assert_false(state.has_act1_transition())
	assert_eq(state.get_phase(), GameState.PHASE_PROLOGUE_DAY)
	assert_eq(state.get_quest_state(StGeorgesModel.QUEST_ID), &"")


func test_clean_save_reaches_each_boundary_and_reloads_without_loss() -> void:
	var service := _save_service()
	for boundary in TraversalModel.INTENDED_BOUNDARY_ENDINGS:
		var branch := TraversalModel.boundary_branch_for_id(boundary)
		assert_false(branch.is_empty(), "missing branch for %s" % boundary)

		var clean := SaveEnvelope.parse_file(CLEAN_START_PATH)
		assert_true(clean["ok"], "clean_start load failed for %s" % boundary)
		var state := clean["state"] as GameState
		state.bag.set_content_db(SessionState.content_db)
		assert_false(state.has_act1_transition(), "clean save leaked transition before %s" % boundary)

		state = _drive_clean_save_to_boundary(state, branch)
		assert_eq(
			String(state.get_act1_transition().get("act_boundary", "")),
			boundary,
			"boundary mismatch for %s" % boundary
		)

		var before_quest := state.get_quest_state(StGeorgesModel.QUEST_ID)
		var before_flag := state.get_flag(branch["boundary_flag"] as StringName)
		var before_phase := state.get_phase()
		assert_true(service.save_game(state), "save failed at boundary %s" % boundary)

		var loaded := service.load_game()
		assert_true(loaded["ok"], "reload failed at boundary %s" % boundary)
		var restored := loaded["state"] as GameState
		restored.bag.set_content_db(SessionState.content_db)
		# SaveService JSON round-trip can widen ints to floats; compare remembered
		# Act 1 identity fields rather than raw Dictionary equality.
		assert_eq(
			String(restored.get_act1_transition().get("act_boundary", "")),
			boundary,
			"act_boundary lost on %s" % boundary
		)
		var restored_validation := Act1AftermathModel.validate_envelope(
			restored.get_act1_transition()
		)
		assert_true(
			restored_validation["valid"],
			"reloaded envelope invalid for %s: %s" % [boundary, str(restored_validation["errors"])]
		)
		assert_eq(restored.get_quest_state(StGeorgesModel.QUEST_ID), before_quest)
		assert_eq(restored.get_flag(branch["boundary_flag"] as StringName), before_flag)
		assert_eq(restored.get_phase(), before_phase)


func test_published_act1_fixtures_load_and_round_trip() -> void:
	for relative_path in TraversalModel.fixture_paths():
		var full_path := "res://content/saves/%s" % relative_path
		var result := SaveEnvelope.parse_file(full_path)
		assert_true(result["ok"], "%s must load: %s" % [relative_path, ", ".join(result["errors"])])
		var state := result["state"] as GameState
		assert_true(state.has_act1_transition())
		var validation := Act1AftermathModel.validate_envelope(state.get_act1_transition())
		assert_true(
			validation["valid"],
			"%s envelope invalid: %s" % [relative_path, str(validation["errors"])]
		)
		var payload := state.save_payload()
		var restored := GameState.new()
		var errors := restored.load_payload(payload)
		assert_eq(errors.size(), 0, "%s round-trip errors: %s" % [relative_path, str(errors)])
		assert_eq(restored.get_act1_transition(), state.get_act1_transition())


func test_invalid_candidate_transitions_are_rejected() -> void:
	var rejected := _collect_rejected_invalid_transitions()
	for invalid_id in TraversalModel.invalid_transition_ids():
		assert_array_contains(
			rejected,
			invalid_id,
			"candidate preflight must reject %s" % invalid_id
		)


func test_legacy_game_state_v1_boundary_fixture_migrates() -> void:
	var result := SaveEnvelope.parse_file(LEGACY_SEAL_PATH)
	assert_true(
		result["ok"],
		"v1 boundary seal must migrate: %s" % ", ".join(result["errors"])
	)
	var state := result["state"] as GameState
	assert_eq(state.get_version(), GameState.CURRENT_VERSION)
	assert_true(state.has_act1_transition())
	assert_eq(String(state.get_act1_transition().get("act_boundary", "")), "seal")
	assert_eq(
		state.save_map_world_state()["save_version"],
		MapStableStateStore.CURRENT_SAVE_VERSION
	)
	var validation := Act1AftermathModel.validate_envelope(state.get_act1_transition())
	assert_true(validation["valid"], str(validation["errors"]))


func test_traversal_manifest_contract_still_holds() -> void:
	var report := TraversalModel.validate_manifest()
	assert_true(report["valid"], str(report["errors"]))


func _drive_clean_save_to_boundary(state: GameState, branch: Dictionary) -> GameState:
	## Candidate preflight starts from an empty clean save, then applies only the
	## climax approach/commit path already owned by P4-011. No new branch is authored.
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

	var terminal := _drive_clean_save_to_boundary(
		GameState.new(),
		TraversalModel.boundary_branch_for_id("seal")
	)
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

	var recorded := _drive_clean_save_to_boundary(
		GameState.new(),
		TraversalModel.boundary_branch_for_id("seal")
	)
	if recorded.has_act1_transition():
		recorded.set_flag(&"flag.act_transition.act1_recorded", false)
		if not Act1AftermathModel.record_transition(recorded):
			rejected.append("invalid.act1.record_without_flag")

	return rejected


func _save_service() -> SaveService:
	var service := SaveService.new()
	_save_directory = "user://test_saves/act1_candidate_%d" % Time.get_ticks_usec()
	service.save_directory = _save_directory
	return service


func _cleanup_save_directory() -> void:
	if _save_directory.is_empty():
		return
	_remove_tree(_save_directory)
	_save_directory = ""


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


func _load_json_dictionary(path: String) -> Dictionary:
	var source := FileAccess.get_file_as_string(path)
	if source.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(source)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}
