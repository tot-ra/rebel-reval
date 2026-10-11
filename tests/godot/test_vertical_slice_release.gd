extends "res://tests/godot/test_case.gd"

## P3-015: tagged slice release must keep manifest, schema versions, and the
## published save fixture aligned.

const ReleaseModel := preload("res://scripts/slice/vertical_slice_release_model.gd")
const SaveMatrix := preload("res://scripts/slice/vertical_slice_save_matrix.gd")
const FlowModel := preload("res://scripts/slice/vertical_slice_flow_model.gd")


func test_manifest_matches_release_model() -> void:
	assert_true(
		ReleaseModel.manifest_matches_model(),
		"vertical_slice_release_model.gd must match slice_release_manifest.json"
	)


func test_published_slice_fixture_loads_and_matches_checkpoint() -> void:
	var result := SaveEnvelope.parse_file(ReleaseModel.published_save_fixture_res_path())
	assert_true(
		result["ok"],
		"published slice fixture must load: %s" % ", ".join(result["errors"])
	)
	var state := result["state"] as GameState
	assert_eq(int(result["envelope"]["save_version"]), ReleaseModel.SAVE_ENVELOPE_VERSION)
	assert_eq(state.get_version(), ReleaseModel.GAME_STATE_VERSION)
	assert_eq(state.save_map_world_state()["save_version"], ReleaseModel.MAP_WORLD_STATE_VERSION)
	assert_true(
		SaveMatrix.validate_checkpoint(
			state,
			StringName(ReleaseModel.PUBLISHED_SAVE_CHECKPOINT_ID)
		),
		"published slice fixture must satisfy checkpoint.prologue_complete"
	)
	assert_eq(state.get_quest_state(FlowModel.QUEST_MAKERS_MARK), &"ledger_committed")


func test_maintainer_report_exists() -> void:
	var filesystem_path := ProjectSettings.globalize_path(ReleaseModel.MAINTAINER_REPORT_PATH)
	assert_true(FileAccess.file_exists(filesystem_path))
