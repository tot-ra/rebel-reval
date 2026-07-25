extends "res://tests/godot/vertical_slice_flow_harness.gd"

## P2-012: headless proof that a fresh session can traverse the full slice
## (prologue, investigation, forge commission, night consequence, aftermath,
## reflection) for every Bitter Brew aftermath family without debug presets.


func test_vertical_slice_reaches_distinct_aftermath_outcomes_for_all_branches() -> void:
	var outcomes: Array[StringName] = []
	for branch_id in FlowModel.branch_ids():
		var branch := FlowModel.branch_for_id(branch_id)
		await _run_full_slice_branch(branch)
		assert_true(
			FlowModel.validate_branch_terminal_state(SessionState.state, branch),
			"branch %s must finish with a valid terminal slice state" % String(branch_id)
		)
		var outcome := AftermathModel.resolve_outcome(SessionState.state)
		assert_false(outcomes.has(outcome), "each branch must produce a distinct aftermath")
		outcomes.append(outcome)


func test_honest_branch_completes_without_debug_presets() -> void:
	var branch := FlowModel.branch_for_id(&"honest")
	await _run_full_slice_branch(branch)
	assert_true(FlowModel.validate_branch_terminal_state(SessionState.state, branch))
	assert_eq(AftermathModel.resolve_outcome(SessionState.state), AftermathModel.OUTCOME_EXONERATED)


func _run_full_slice_branch(branch: Dictionary) -> void:
	_reset_fresh_session()
	await _complete_prologue()
	await _rest_in_forge(GameState.PHASE_INVESTIGATION_MORNING)
	await _complete_investigation()
	await _complete_bitter_brew_commission(String(branch["forge_option"]))
	await _rest_in_forge(GameState.PHASE_INVESTIGATION_NIGHT)
	await _resolve_night_encounter(branch["night_route"] as StringName)
	await _rest_in_forge(GameState.PHASE_CONSEQUENCE_NIGHT)
	assert_true(
		AftermathModel.commit_aftermath(SessionState.state, SessionState.content_db),
		"aftermath must commit once the night route resolves"
	)
	assert_eq(
		AftermathModel.resolve_outcome(SessionState.state),
		branch["aftermath_outcome"] as StringName
	)
	await _rest_in_forge(GameState.PHASE_REFLECTION_MORNING)
	_complete_reflection()
