extends "res://tests/godot/test_case.gd"

const BenchmarkRunner := preload("res://tools/benchmarks/run_large_map_benchmark.gd")
const SceneBaseline := preload("res://tools/benchmarks/lower_town_scene_baseline.gd")
const TARGET_HARDWARE_PATH := "res://tools/benchmarks/target_hardware.json"


func test_target_hardware_profile_has_report_identity() -> void:
	var runner := BenchmarkRunner.new()
	var profile: Dictionary = runner._load_target_hardware(TARGET_HARDWARE_PATH)

	assert_false(profile.is_empty())
	assert_eq(profile["profile_id"], "development-baseline-m5-pro")
	assert_eq(profile["status"], "development_baseline_not_minimum")
	assert_true(float(profile["memory_gib"]) > 0.0)


func test_scene_actor_count_uses_direct_authoritative_actor_bodies() -> void:
	var recorder := SceneBaseline.new()
	var actors := Node2D.new()
	actors.add_child(CharacterBody2D.new())
	actors.add_child(CharacterBody2D.new())
	actors.add_child(Node2D.new())
	var nested := Node2D.new()
	nested.add_child(CharacterBody2D.new())
	actors.add_child(nested)

	assert_eq(recorder._count_actors(actors), 3)
	assert_eq(recorder._count_actors(null), 0)

	actors.free()
	recorder.free()


func test_headline_exposes_required_performance_metrics() -> void:
	var runner := BenchmarkRunner.new()
	var profiles := [{
		"id": "lower_town_scene",
		"metrics": {
			"frame_time_ms_p95": {"median": 12.5},
			"memory_static_bytes": {"median": 134217728.0},
			"memory_delta_mib": {"median": 64.0},
			"actor_count": {"median": 3.0},
		},
	}]

	var headline: Dictionary = runner._headline_metrics(profiles)
	assert_eq(headline["profile_id"], "lower_town_scene")
	assert_eq(headline["frame_time_ms_p95"], 12.5)
	assert_eq(headline["memory_static_bytes"], 134217728)
	assert_eq(headline["memory_delta_mib"], 64.0)
	assert_eq(headline["actor_count"], 3)

	runner.free()
