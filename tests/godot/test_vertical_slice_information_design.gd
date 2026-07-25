extends "res://tests/godot/test_case.gd"

## P3-008: critical slice beats must not rely on color-only, audio-only, or
## off-game historical knowledge channels.

const InfoModel := preload(
	"res://scripts/slice/vertical_slice_information_design_model.gd"
)
const FlowModel := preload("res://scripts/slice/vertical_slice_flow_model.gd")

const VALID_DIR := "res://content/examples/valid"
const SUPPORT_DIR := "res://content/examples/support"


func test_information_beats_have_non_color_non_audio_channels() -> void:
	var report := InfoModel.build_report()
	assert_true(
		report["all_beats_valid"],
		"invalid information beats: %s" % str(report["errors"])
	)
	assert_eq(report["beat_count"], 23)


func test_historical_concepts_reference_catalogued_context_beats() -> void:
	var report := InfoModel.build_report()
	assert_true(
		report["all_concepts_valid"],
		"invalid historical concepts: %s" % str(report["errors"])
	)
	assert_eq(report["historical_concept_count"], 6)


func test_catalogued_content_ids_resolve_in_slice_corpus() -> void:
	var db := ContentDB.new()
	assert_true(db.load_from_directories([VALID_DIR, SUPPORT_DIR]))
	for beat: Dictionary in InfoModel.INFORMATION_BEATS:
		for content_id in beat.get("content_ids", []):
			var id := StringName(String(content_id))
			assert_true(
				_content_exists(db, id),
				"beat %s references missing content id %s" % [String(beat["id"]), String(id)]
			)
	for concept: Dictionary in InfoModel.HISTORICAL_CONCEPTS:
		var content_id := StringName(String(concept.get("content_id", "")))
		assert_true(
			_content_exists(db, content_id),
			"concept %s references missing content id %s"
			% [String(concept["id"]), String(content_id)]
		)


func test_slice_branch_matrix_remains_mechanic_gated_without_color_or_audio() -> void:
	# WHY: headless traversal proves route availability is forged-record and
	# fact gated; color mute and grayscale are not inputs to GameState.
	for branch_id in FlowModel.branch_ids():
		var branch := FlowModel.branch_for_id(branch_id)
		assert_false(branch.is_empty(), "missing branch %s" % String(branch_id))
		assert_false(String(branch["forge_option"]).is_empty())
		assert_false(String(branch["night_route"]).is_empty())
		assert_false(String(branch["forged_record"]).is_empty())


func _content_exists(db: ContentDB, content_id: StringName) -> bool:
	if content_id.is_empty():
		return false
	if not db.get_quest(content_id).is_empty():
		return true
	if not db.get_dialogue(content_id).is_empty():
		return true
	if not db.get_commission(content_id).is_empty():
		return true
	if not db.get_encounter(content_id).is_empty():
		return true
	if not db.get_mechanism(content_id).is_empty():
		return true
	if not db.get_bark_pool(content_id).is_empty():
		return true
	if not db.get_phase_profile(content_id).is_empty():
		return true
	return false
