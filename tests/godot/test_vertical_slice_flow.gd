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
