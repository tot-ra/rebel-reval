extends "res://tests/godot/test_case.gd"

## P3-016: end-to-end slice contract must keep traversal, flow, save, release,
## and platform manifests aligned.

const E2EModel := preload("res://scripts/slice/vertical_slice_e2e_model.gd")
const TraversalModel := preload("res://scripts/slice/vertical_slice_traversal_model.gd")
const FlowModel := preload("res://scripts/slice/vertical_slice_flow_model.gd")
const SaveMatrix := preload("res://scripts/slice/vertical_slice_save_matrix.gd")
const PlatformModel := preload("res://scripts/slice/vertical_slice_platform_model.gd")
const ReleaseModel := preload("res://scripts/slice/vertical_slice_release_model.gd")


func test_manifest_matches_e2e_model() -> void:
	assert_true(
		E2EModel.manifest_matches_model(),
		"vertical_slice_e2e_model.gd must match slice_e2e_manifest.json"
	)


func test_traversal_contract_matches_flow_branches() -> void:
	assert_eq(
		TraversalModel.intended_ending_ids().size(),
		FlowModel.branch_ids().size(),
		"every flow branch must map to one intended traversal ending"
	)
	assert_eq(
		TraversalModel.invalid_transition_ids().size(),
		9,
		"slice e2e suite expects nine deliberate invalid transitions"
	)


func test_save_matrix_covers_full_slice_progression() -> void:
	assert_eq(
		SaveMatrix.checkpoint_ids().size(),
		10,
		"slice e2e suite expects ten save checkpoints"
	)


func test_declared_platform_and_published_fixtures_are_present() -> void:
	assert_false(PlatformModel.supported_platform_ids().is_empty())
	for entry: Dictionary in SaveEnvelope.list_released_fixture_entries():
		var relative_path := String(entry.get("path", ""))
		assert_false(relative_path.is_empty())
		var result := SaveEnvelope.parse_file(SaveEnvelope.released_fixture_path(relative_path))
		assert_true(
			result["ok"],
			"published fixture %s must load: %s" % [relative_path, ", ".join(result["errors"])]
		)
	assert_true(ReleaseModel.manifest_matches_model())


func test_maintainer_report_exists() -> void:
	var filesystem_path := ProjectSettings.globalize_path(E2EModel.MAINTAINER_REPORT_PATH)
	assert_true(FileAccess.file_exists(filesystem_path))
