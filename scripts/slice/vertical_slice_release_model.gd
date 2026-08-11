class_name VerticalSliceReleaseModel
extends RefCounted

## Authored vertical-slice release contract for P3-015.
## WHY: slice tagging needs one matrix that save/content schema versions,
## published fixtures, and the Python report tool can reference without drift.

const MANIFEST_PATH := "res://docs/data/slice_release_manifest.json"
const RELEASE_TAG := "v0.1.0-slice"
const SAVE_ENVELOPE_VERSION := 1
const GAME_STATE_VERSION := 2
const MAP_WORLD_STATE_VERSION := 2
const CONTENT_SCHEMA_VERSION := 1
# gdlint: ignore=max-line-length
const CONTENT_SCHEMA_FINGERPRINT := "e49a36e051256a899b7f7935fe4479bf2b977d4582b80341aebb147a63266ff6"
# gdlint: ignore=max-line-length
const CONTENT_CORPUS_FINGERPRINT := "ce6129b14a7872662b40ecfec75aa69500f4231a1b60d31d2de5d8aaa35ace25"
const PUBLISHED_SAVE_FIXTURE_ID := "save.slice_prologue_complete"
const PUBLISHED_SAVE_FIXTURE_PATH := "released/save.slice_prologue_complete.json"
const PUBLISHED_SAVE_CHECKPOINT_ID := "checkpoint.prologue_complete"
const MAINTAINER_REPORT_PATH := "res://docs/reports/p3_015_slice_release.md"
const VERIFY_SCRIPT_PATH := "tools/verify_slice_release.sh"
const BUILD_FIXTURE_SCRIPT_PATH := "tools/build_slice_release_fixture.py"

const CONTENT_DIRECTORIES: Array[String] = [
	"content/demo",
	"content/examples/support",
	"content/examples/valid",
]


static func load_manifest() -> Dictionary:
	var source := FileAccess.get_file_as_string(MANIFEST_PATH)
	if source.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(source)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


static func manifest_matches_model() -> bool:
	var manifest := load_manifest()
	if manifest.is_empty():
		return false
	if String(manifest.get("release_tag", "")) != RELEASE_TAG:
		return false
	if int(manifest.get("save_envelope_version", 0)) != SAVE_ENVELOPE_VERSION:
		return false
	if int(manifest.get("game_state_version", 0)) != GAME_STATE_VERSION:
		return false
	if int(manifest.get("map_world_state_version", 0)) != MAP_WORLD_STATE_VERSION:
		return false
	if int(manifest.get("content_schema_version", 0)) != CONTENT_SCHEMA_VERSION:
		return false
	if String(manifest.get("content_schema_fingerprint", "")) != CONTENT_SCHEMA_FINGERPRINT:
		return false
	if String(manifest.get("content_corpus_fingerprint", "")) != CONTENT_CORPUS_FINGERPRINT:
		return false
	var fixture: Variant = manifest.get("published_save_fixture", {})
	if not fixture is Dictionary:
		return false
	if String((fixture as Dictionary).get("id", "")) != PUBLISHED_SAVE_FIXTURE_ID:
		return false
	if String((fixture as Dictionary).get("path", "")) != PUBLISHED_SAVE_FIXTURE_PATH:
		return false
	return true


static func published_save_fixture_res_path() -> String:
	return SaveEnvelope.released_fixture_path(PUBLISHED_SAVE_FIXTURE_PATH)
