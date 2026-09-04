extends "res://tests/godot/test_case.gd"

const WaterBenchmark := preload("res://tools/benchmarks/r715_water_benchmark.gd")
const CONFIG_PATH := "res://tools/benchmarks/r715_water_benchmark_config.json"
const LAUNCHER_PATH := "res://tools/benchmarks/r715_water_benchmark.sh"


func _config() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	return parsed as Dictionary if parsed is Dictionary else {}


func test_protocol_declares_two_water_only_tiers_and_full_matrix() -> void:
	var config := _config()
	assert_true(FileAccess.file_exists(LAUNCHER_PATH))
	assert_eq(config["budget_scope"], "water_only")
	assert_true(int(config["minimum_samples"]) >= 120)
	assert_eq((config["tiers"] as Dictionary).keys().size(), 2)
	assert_true((config["tiers"] as Dictionary).has("minimum"))
	assert_true((config["tiers"] as Dictionary).has("recommended"))
	assert_eq((config["map_matrix"] as Array).size(), 13)
	assert_true((config["external_boundaries"] as Dictionary).has("R-529"))
	assert_true((config["external_boundaries"] as Dictionary).has("R-713"))
	assert_true(WaterBenchmark.validate_config(config).is_empty())


func test_each_tier_emits_r795_compatible_water_metric_shape() -> void:
	var tiers: Dictionary = _config()["tiers"]
	for tier_id: String in ["minimum", "recommended"]:
		var tier: Dictionary = tiers[tier_id]
		var thresholds := WaterBenchmark.merged_thresholds(tier)
		for key: String in [
			"detail_layers",
			"reflection_samples",
			"refraction_samples",
			"foam_shore_detail",
			"frame_time_ms_p95",
			"draw_calls_peak",
			"resource_count_peak",
			"memory_delta_mib",
		]:
			assert_true(thresholds.has(key), "%s missing %s" % [tier_id, key])
	assert_eq(_config()["fallback"]["id"], "compatibility_water_surface")


func test_generic_scene_metrics_cannot_substitute_for_water_metrics() -> void:
	var invalid := _config().duplicate(true)
	var recommended: Dictionary = invalid["tiers"]["recommended"]
	recommended["thresholds"].erase("frame_time_ms_p95")
	recommended["thresholds"]["steady_frame_time_ms_p95"] = 16.67
	var errors := WaterBenchmark.validate_config(invalid)
	assert_true(_contains_fragment(errors, "missing water metric frame_time_ms_p95"))
	assert_true(_contains_fragment(errors, "generic scene metric cannot substitute"))


func test_missing_tier_and_short_sample_count_fail_closed() -> void:
	var invalid := _config().duplicate(true)
	invalid["minimum_samples"] = 119
	invalid["tiers"].erase("minimum")
	var errors := WaterBenchmark.validate_config(invalid)
	assert_true(_contains_fragment(errors, "at least 120 samples"))
	assert_true(_contains_fragment(errors, "missing tier: minimum"))


func test_headless_or_mismatched_host_cannot_be_acceptance() -> void:
	var target := {
		"profile_id": "minimum-hardware-intel-uhd-620",
		"architecture": "x86_64",
		"gpu": "Intel UHD Graphics 620",
	}
	var wrong_host := {
		"profile_id": "development-baseline-m5-pro",
		"architecture": "arm64",
		"gpu": "Apple M5 Pro",
	}
	assert_false(WaterBenchmark.host_matches_target(wrong_host, target))
	assert_true("Headless" in WaterBenchmark.acceptance_reason(true, true))
	assert_true("does not match" in WaterBenchmark.acceptance_reason(false, false))


func test_water_metrics_are_non_negative_phase_deltas() -> void:
	var baseline := {
		"frame_time_ms_p95": 4.0,
		"draw_calls_peak": 10,
		"resource_count_peak": 2,
		"memory_mib": 100.0,
	}
	var water := {
		"frame_time_ms_p95": 5.25,
		"draw_calls_peak": 14,
		"resource_count_peak": 10,
		"memory_mib": 112.5,
	}
	var metrics := WaterBenchmark.water_only_metrics(baseline, water)
	assert_eq(metrics["frame_time_ms_p95"], 1.25)
	assert_eq(metrics["draw_calls_peak"], 4)
	assert_eq(metrics["resource_count_peak"], 8)
	assert_eq(metrics["memory_delta_mib"], 12.5)
	var clamped := WaterBenchmark.water_only_metrics(water, baseline)
	for key: String in WaterBenchmark.required_metric_keys():
		assert_eq(clamped[key], 0 if key != "frame_time_ms_p95" and key != "memory_delta_mib" else 0.0)


func test_percentile_uses_nearest_rank() -> void:
	var samples: Array[float] = [5.0, 1.0, 3.0, 4.0, 2.0]
	assert_eq(WaterBenchmark.percentile(samples, 0.95), 5.0)
	assert_eq(WaterBenchmark.percentile(samples, 0.5), 3.0)
	assert_eq(WaterBenchmark.percentile([], 0.95), 0.0)


func _contains_fragment(values: Array[String], fragment: String) -> bool:
	for value: String in values:
		if fragment in value:
			return true
	return false
