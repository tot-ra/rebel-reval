extends "res://tests/godot/vertical_slice_flow_harness.gd"

## P2-016: save/reload round-trip at every vertical-slice phase and branch boundary.

const SaveMatrix := preload("res://scripts/slice/vertical_slice_save_matrix.gd")
const SaveAssertions := preload("res://tests/godot/save_state_assertions.gd")

var _save_directory := ""


func before_each() -> void:
	_cleanup_save_directory()


func after_each() -> void:
	_cleanup_save_directory()


func test_save_matrix_preserves_state_at_every_checkpoint_for_each_branch() -> void:
	for branch_id in FlowModel.branch_ids():
		var branch := FlowModel.branch_for_id(branch_id)
		await _run_branch_with_save_checkpoints(branch, String(branch_id))


func test_save_matrix_honest_branch_checkpoint_count() -> void:
	var branch := FlowModel.branch_for_id(&"honest")
	await _run_branch_with_save_checkpoints(branch, "honest")
	assert_true(FlowModel.validate_branch_terminal_state(SessionState.state, branch))


func _run_branch_with_save_checkpoints(branch: Dictionary, branch_label: String) -> void:
	var service := _save_service()
	_reset_fresh_session()

	await _complete_prologue()
	_checkpoint_save_reload(
		service,
		SaveMatrix.CHECKPOINT_PROLOGUE_COMPLETE,
		branch,
		branch_label
	)

	await _rest_in_forge(GameState.PHASE_INVESTIGATION_MORNING)
	_checkpoint_save_reload(
		service,
		SaveMatrix.CHECKPOINT_INVESTIGATION_MORNING,
		branch,
		branch_label
	)

	await _complete_investigation()
	_checkpoint_save_reload(
		service,
		SaveMatrix.CHECKPOINT_INVESTIGATION_READY,
		branch,
		branch_label
	)

	await _complete_bitter_brew_commission(String(branch["forge_option"]))
	_checkpoint_save_reload(
		service,
		SaveMatrix.CHECKPOINT_COMMISSION_RESOLVED,
		branch,
		branch_label
	)

	await _rest_in_forge(GameState.PHASE_INVESTIGATION_NIGHT)
	_checkpoint_save_reload(
		service,
		SaveMatrix.CHECKPOINT_INVESTIGATION_NIGHT,
		branch,
		branch_label
	)

	await _resolve_night_encounter(branch["night_route"] as StringName)
	_checkpoint_save_reload(
		service,
		SaveMatrix.CHECKPOINT_NIGHT_ROUTE_RESOLVED,
		branch,
		branch_label
	)

	await _rest_in_forge(GameState.PHASE_CONSEQUENCE_NIGHT)
	_checkpoint_save_reload(
		service,
		SaveMatrix.CHECKPOINT_CONSEQUENCE_NIGHT,
		branch,
		branch_label
	)

	assert_true(
		AftermathModel.commit_aftermath(SessionState.state, SessionState.content_db),
		"aftermath must commit for branch %s" % branch_label
	)
	assert_eq(
		AftermathModel.resolve_outcome(SessionState.state),
		branch["aftermath_outcome"] as StringName
	)
	_checkpoint_save_reload(
		service,
		SaveMatrix.CHECKPOINT_AFTERMATH_COMMITTED,
		branch,
		branch_label
	)

	await _rest_in_forge(GameState.PHASE_REFLECTION_MORNING)
	_checkpoint_save_reload(
		service,
		SaveMatrix.CHECKPOINT_REFLECTION_MORNING,
		branch,
		branch_label
	)

	_complete_reflection()
	_checkpoint_save_reload(
		service,
		SaveMatrix.CHECKPOINT_SLICE_COMPLETE,
		branch,
		branch_label
	)


func _checkpoint_save_reload(
	service: SaveService,
	checkpoint_id: StringName,
	branch: Dictionary,
	branch_label: String
) -> void:
	var label := "%s/%s" % [branch_label, String(checkpoint_id)]
	assert_true(
		SaveMatrix.validate_checkpoint(SessionState.state, checkpoint_id, branch),
		"checkpoint precondition failed for %s" % label
	)
	var before := SessionState.state
	assert_true(service.save_game(before), "save failed at %s" % label)
	var loaded := service.load_game()
	assert_true(loaded["ok"], "load failed at %s" % label)
	var restored := loaded["state"] as GameState
	restored.bag.set_content_db(SessionState.content_db)
	SaveAssertions.assert_game_states_equal(self, before, restored, label)
	assert_true(
		SessionState.replace_state(restored, SessionState.STATE_REPLACE_REASON_MANUAL_LOAD),
		"session replace failed at %s" % label
	)
	assert_true(
		SaveMatrix.validate_checkpoint(SessionState.state, checkpoint_id, branch),
		"checkpoint post-load validation failed for %s" % label
	)


func _save_service() -> SaveService:
	var service := SaveService.new()
	_save_directory = _temp_dir("vertical_slice_save_matrix")
	service.save_directory = _save_directory
	return service


func _temp_dir(label: String) -> String:
	var unique := "%s_%d" % [label, Time.get_ticks_usec()]
	return "user://test_saves/%s" % unique


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
