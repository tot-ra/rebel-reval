extends "res://tests/godot/test_case.gd"

const REPORT_PATH := "res://docs/reports/r715_water_performance.md"
const VERIFIER_PATH := "res://tools/verify_r715_water_performance.py"


func _read_report() -> String:
	return FileAccess.get_file_as_string(REPORT_PATH)


func test_report_declares_exact_water_tiers_and_budget_scope() -> void:
	var report := _read_report()
	assert_true(FileAccess.file_exists(REPORT_PATH))
	assert_true(FileAccess.file_exists(VERIFIER_PATH))
	assert_true("r715-water-performance-v1" in report)
	assert_true('"budget_scope": "water_only"' in report)
	assert_true('"id": "minimum"' in report)
	assert_true('"id": "recommended"' in report)
	for threshold: String in [
		"detail_layers",
		"reflection_samples",
		"refraction_samples",
		"foam_shore_detail",
		"frame_time_ms_p95",
		"draw_calls_peak",
		"resource_count_peak",
		"memory_delta_mib",
	]:
		assert_true(threshold in report, "water threshold missing: %s" % threshold)


func test_report_keeps_target_host_and_renderer_identity_separate() -> void:
	var report := _read_report()
	assert_true('"target_hardware"' in report)
	assert_true('"measurement_host"' in report)
	assert_true('"renderer"' in report)
	assert_true('"profile_id": "minimum-hardware-intel-uhd-620"' in report)
	assert_true('"profile_id": "development-baseline-m5-pro"' in report)
	assert_true('"status": "not_measured"' in report)
	assert_true('"headless": null' in report)
	assert_true('"recommendation": "BLOCKED"' in report)


func test_every_tier_declares_a_water_like_fallback() -> void:
	var report := _read_report()
	var fallback_count := report.count('"id": "compatibility_water_surface"')
	assert_eq(fallback_count, 2, "each water tier needs its own fallback declaration")
	assert_true("water-like base" in report)
	assert_true("bounded refraction" in report)
	assert_true("does not mutate terrain, collision, navigation" in report)


func test_verifier_exposes_fail_closed_negative_paths() -> void:
	var verifier := FileAccess.get_file_as_string(VERIFIER_PATH)
	for contract: String in [
		"missing water tier(s)",
		"measurement host does not match target hardware",
		"unmeasured minimum row is not acceptable",
		"stale report link",
		"generic scene budgets with water budgets",
		"--strict",
		"at least 120 frame samples",
	]:
		assert_true(contract in verifier, "verifier contract missing: %s" % contract)
	assert_true("recommendation" in verifier)
	assert_true("BLOCKED" in verifier)
	assert_true("FAIL" in verifier)
