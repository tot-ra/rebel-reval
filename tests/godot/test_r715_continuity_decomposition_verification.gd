extends "res://tests/godot/test_case.gd"

const REPORT_PATH := "res://docs/reports/r715_continuity_decomposition_verification.md"
const R814_REPORT_PATH := "res://docs/reports/r715_water_save_envelope.md"
const R814_TEST_PATH := "res://tests/godot/test_r715_water_save_envelope.gd"
const R815_REPORT_PATH := "res://docs/reports/r715_water_map_handoff.md"
const R815_TEST_PATH := "res://tests/godot/test_r715_water_map_handoff.gd"

const R814_REPORT_EVIDENCE: Array[String] = [
	"GameState.save_payload()",
	"GameStatePersistence.load_payload()",
	"JSON round-trip",
	"source/restored",
	"water uniforms",
	"Status: **STRUCTURAL PASS",
	"4 test(s), 0 failure(s), 0 error(s)",
]
const R814_TEST_EVIDENCE: Array[String] = [
	"source_presentation",
	"restored_presentation",
	"source_uniforms",
	"restored_uniforms",
	"JSON.stringify",
	"GameStatePersistenceScript.load_payload",
]
const R815_REPORT_EVIDENCE: Array[String] = [
	"reval_harbor_north",
	"reval_harbor_east",
	"before/after",
	"owner counts",
	"terrain_fingerprint",
	"walkability_sha256",
	"Status: **STRUCTURAL PASS",
	"2 test(s), 0 failure(s), 0 error(s)",
]
const R815_TEST_EVIDENCE: Array[String] = [
	"source_inputs",
	"destination_inputs",
	"source_uniforms",
	"destination_uniforms",
	"_active_environment_owner_count",
	"environment_binding_active",
	"bind_environment_runtime",
]
const R814_SCOPE_OVERLAP: Array[String] = [
	"before/after",
	"owner counts",
	"bind_environment_runtime",
	"reval_harbor_east",
]
const R815_SCOPE_OVERLAP: Array[String] = [
	"GameState.save_payload()",
	"JSON.stringify",
	"source/restored",
]


func test_child_artifacts_exist_and_reference_exact_outputs() -> void:
	for artifact_path: String in [
		R814_REPORT_PATH,
		R814_TEST_PATH,
		R815_REPORT_PATH,
		R815_TEST_PATH,
	]:
		assert_true(
			FileAccess.file_exists(artifact_path),
			"missing R-715 child artifact: %s" % artifact_path,
		)

	var r814_report := FileAccess.get_file_as_string(R814_REPORT_PATH)
	var r814_test := FileAccess.get_file_as_string(R814_TEST_PATH)
	var r815_report := FileAccess.get_file_as_string(R815_REPORT_PATH)
	var r815_test := FileAccess.get_file_as_string(R815_TEST_PATH)
	assert_true(
		r814_report.contains("test_r715_water_save_envelope.gd"),
		"R-814 report must link its focused test",
	)
	assert_true(
		r815_report.contains("test_r715_water_map_handoff.gd"),
		"R-815 report must link its focused test",
	)
	assert_true(
		r814_test.contains("test_report_records_required_evidence_boundary"),
		"R-814 focused test must contain its report contract",
	)
	assert_true(
		r815_test.contains("test_report_records_handoff_evidence_boundary"),
		"R-815 focused test must contain its report contract",
	)
	print("R-816 child artifacts: R-814 and R-815 present and linked: PASS")


func test_required_child_evidence_and_scope_separation() -> void:
	var r814_report := FileAccess.get_file_as_string(R814_REPORT_PATH)
	var r814_test := FileAccess.get_file_as_string(R814_TEST_PATH)
	var r815_report := FileAccess.get_file_as_string(R815_REPORT_PATH)
	var r815_test := FileAccess.get_file_as_string(R815_TEST_PATH)
	var r814_audit: Dictionary = _audit_child(
		r814_report,
		r814_test,
		R814_REPORT_EVIDENCE,
		R814_TEST_EVIDENCE,
		R814_SCOPE_OVERLAP,
	)
	var r815_audit: Dictionary = _audit_child(
		r815_report,
		r815_test,
		R815_REPORT_EVIDENCE,
		R815_TEST_EVIDENCE,
		R815_SCOPE_OVERLAP,
	)

	assert_true(
		r814_report.contains("Status: **STRUCTURAL PASS"),
		"R-814 report must explicitly record a structural pass",
	)
	assert_true(
		r815_report.contains("Status: **STRUCTURAL PASS"),
		"R-815 report must explicitly record a structural pass",
	)
	assert_true(
		"R-814" in r814_report and "PASS" in r814_report,
		"R-814 report must not imply completion without a PASS result",
	)
	assert_true(
		"R-815" in r815_report and "PASS" in r815_report,
		"R-815 report must not imply completion without a PASS result",
	)
	assert_true(
		"FAIL" not in r814_report,
		"R-814 report must not contain a failed child result",
	)
	assert_true(
		"FAIL" not in r815_report,
		"R-815 report must not contain a failed child result",
	)
	assert_true(
		bool(r814_audit["valid"]),
		"R-814 evidence must be complete and isolated",
	)
	assert_true(bool(r815_audit["valid"]), "R-815 evidence must be complete and isolated")
	print("R-816 evidence audit: R-814 source/restored: PASS; R-815 before/after: PASS")
	print("R-816 scope separation: PASS")


func test_missing_evidence_and_scope_overlap_fail_closed() -> void:
	var r814_report := FileAccess.get_file_as_string(R814_REPORT_PATH)
	var r814_test := FileAccess.get_file_as_string(R814_TEST_PATH)
	var r815_report := FileAccess.get_file_as_string(R815_REPORT_PATH)
	var r815_test := FileAccess.get_file_as_string(R815_TEST_PATH)

	var missing_r814: Dictionary = _audit_child(
		r814_report.replace("source/restored", ""),
		r814_test,
		R814_REPORT_EVIDENCE,
		R814_TEST_EVIDENCE,
		R814_SCOPE_OVERLAP,
	)
	assert_false(bool(missing_r814["valid"]), "missing R-814 evidence must be rejected")
	var missing_fields: Array = missing_r814["missing"]
	assert_true(
		missing_fields.has("report:source/restored"),
		"the missing R-814 source/restored field must be identified",
	)

	var overlap_r814: Dictionary = _audit_child(
		r814_report + "\nowner counts",
		r814_test,
		R814_REPORT_EVIDENCE,
		R814_TEST_EVIDENCE,
		R814_SCOPE_OVERLAP,
	)
	assert_false(bool(overlap_r814["valid"]), "R-814/R-815 scope overlap must be rejected")
	var overlap_fields: Array = overlap_r814["overlap"]
	assert_true(overlap_fields.has("owner counts"), "the overlapping owner scope must be identified")

	var overlap_r815: Dictionary = _audit_child(
		r815_report + "\nGameState.save_payload()",
		r815_test,
		R815_REPORT_EVIDENCE,
		R815_TEST_EVIDENCE,
		R815_SCOPE_OVERLAP,
	)
	assert_false(bool(overlap_r815["valid"]), "R-815/R-814 scope overlap must be rejected")
	print("R-816 fail-closed fixtures: missing evidence: PASS; scope overlap: PASS")


func test_report_maps_r715_clauses_and_preserves_blockers() -> void:
	var report := FileAccess.get_file_as_string(REPORT_PATH)
	assert_true(FileAccess.file_exists(REPORT_PATH), "R-816 verification report must exist")
	for required_anchor: String in [
		"Save/load persistence",
		"Map-transition continuity",
		"Single environment ownership",
		"R-814",
		"R-815",
		"R-757",
		"READY_FOR_R757",
		"READY_FOR_R757 only when both children pass",
		"Real-renderer visual evidence",
		"Target-hardware performance evidence",
		"BLOCKED",
		"test_r715_continuity_decomposition_verification.gd",
	]:
		assert_true(
			report.contains(required_anchor),
			"R-816 report must preserve clause or boundary: %s" % required_anchor,
		)
	assert_true(
		report.contains("Exact evidence paths"),
		"R-816 report must expose the child evidence paths",
	)
	assert_true(
		report.contains("Godot headless tests: 1 file(s), 4 test(s), 0 failure(s), 0 error(s)."),
		"R-814 fresh summary must be recorded",
	)
	assert_true(
		report.contains("Godot headless tests: 1 file(s), 2 test(s), 0 failure(s), 0 error(s)."),
		"R-815 fresh summary must be recorded",
	)


func _audit_child(
	report: String,
	test_source: String,
	required_report: Array[String],
	required_test: Array[String],
	forbidden_scope: Array[String],
) -> Dictionary:
	var missing: Array[String] = []
	for marker: String in required_report:
		if not report.contains(marker):
			missing.append("report:%s" % marker)
	for marker: String in required_test:
		if not test_source.contains(marker):
			missing.append("test:%s" % marker)

	var overlap: Array[String] = []
	for marker: String in forbidden_scope:
		if report.contains(marker) or test_source.contains(marker):
			overlap.append(marker)
	return {
		"valid": missing.is_empty() and overlap.is_empty(),
		"missing": missing,
		"overlap": overlap,
	}
