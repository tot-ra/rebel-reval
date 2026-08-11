class_name VerticalSliceE2EModel
extends RefCounted

## Authored end-to-end vertical-slice validation contract for P3-016.
## WHY: slice release needs one matrix that traversal, flow, save-matrix,
## published fixtures, and declared platforms reference without drift.

const MANIFEST_PATH := "res://docs/data/slice_e2e_manifest.json"
const MAINTAINER_REPORT_PATH := "res://docs/reports/p3_016_slice_e2e.md"
const VERIFY_SCRIPT_PATH := "tools/verify_slice_e2e.sh"

const TRAVERSAL_MANIFEST_PATH := "res://docs/data/slice_traversal_manifest.json"
const RELEASE_MANIFEST_PATH := "res://docs/data/slice_release_manifest.json"
const PLATFORM_MANIFEST_PATH := "res://docs/data/slice_platform_manifest.json"
const RELEASED_SAVES_MANIFEST_PATH := "res://content/saves/released_manifest.json"

const TRAVERSAL_TEST_FILTER := "test_vertical_slice_traversal"
const FLOW_TEST_FILTER := "test_vertical_slice_flow"
const SAVE_MATRIX_TEST_FILTER := "test_vertical_slice_save_matrix"
const RELEASE_TEST_FILTER := "test_vertical_slice_release"
const RELEASED_FIXTURES_TEST_FILTER := "test_save_envelope"
const E2E_TEST_FILTER := "test_vertical_slice_e2e"

const TRAVERSAL_REPORT_SCRIPT := "tools/report_slice_traversal.py"
const RELEASE_REPORT_SCRIPT := "tools/report_slice_release.py"
const PLATFORM_REPORT_SCRIPT := "tools/report_slice_platform.py"


static func load_manifest() -> Dictionary:
	var source := FileAccess.get_file_as_string(MANIFEST_PATH)
	if source.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(source)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


static func godot_test_filters() -> Array[String]:
	return [
		TRAVERSAL_TEST_FILTER,
		FLOW_TEST_FILTER,
		SAVE_MATRIX_TEST_FILTER,
		RELEASE_TEST_FILTER,
		RELEASED_FIXTURES_TEST_FILTER,
		E2E_TEST_FILTER,
	]


static func python_report_scripts() -> Array[String]:
	return [
		TRAVERSAL_REPORT_SCRIPT,
		RELEASE_REPORT_SCRIPT,
		PLATFORM_REPORT_SCRIPT,
	]


static func manifest_matches_model() -> bool:
	var manifest := load_manifest()
	if manifest.is_empty():
		return false
	if String(manifest.get("task_id", "")) != "P3-016":
		return false
	if String(manifest.get("verify_script", "")) != VERIFY_SCRIPT_PATH:
		return false
	if (
		String(manifest.get("maintainer_report", ""))
		!= MAINTAINER_REPORT_PATH.trim_prefix("res://")
	):
		return false
	var traversal_manifest := String(manifest.get("traversal_manifest", ""))
	if traversal_manifest != TRAVERSAL_MANIFEST_PATH.trim_prefix("res://"):
		return false
	var release_manifest := String(manifest.get("release_manifest", ""))
	if release_manifest != RELEASE_MANIFEST_PATH.trim_prefix("res://"):
		return false
	var platform_manifest := String(manifest.get("platform_manifest", ""))
	if platform_manifest != PLATFORM_MANIFEST_PATH.trim_prefix("res://"):
		return false
	var released_saves_manifest := String(manifest.get("released_saves_manifest", ""))
	if released_saves_manifest != RELEASED_SAVES_MANIFEST_PATH.trim_prefix("res://"):
		return false
	var filters: Variant = manifest.get("godot_test_filters", [])
	if not filters is Array:
		return false
	var expected_filters := godot_test_filters()
	if (filters as Array).size() != expected_filters.size():
		return false
	for index in range(expected_filters.size()):
		if String((filters as Array)[index]) != expected_filters[index]:
			return false
	var scripts: Variant = manifest.get("python_report_scripts", [])
	if not scripts is Array:
		return false
	var expected_scripts := python_report_scripts()
	if (scripts as Array).size() != expected_scripts.size():
		return false
	for index in range(expected_scripts.size()):
		if String((scripts as Array)[index]) != expected_scripts[index]:
			return false
	return true


static func published_fixture_paths() -> Array[String]:
	var paths: Array[String] = []
	for entry: Dictionary in SaveEnvelope.list_released_fixture_entries():
		paths.append(String(entry.get("path", "")))
	return paths
