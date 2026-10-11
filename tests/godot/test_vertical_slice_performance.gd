extends "res://tests/godot/test_case.gd"

## P3-011: vertical-slice performance budgets must stay aligned across the
## Godot model, benchmark config, and Python manifest.

const PerfModel := preload("res://scripts/slice/vertical_slice_performance_model.gd")


func test_busiest_scene_profile_is_lower_town() -> void:
	assert_eq(
		String(PerfModel.BUSIEST_SCENE_PROFILE_ID),
		"lower_town_scene"
	)
	assert_true(ResourceLoader.exists(PerfModel.BUSIEST_SCENE_PATH))


func test_budgets_match_benchmark_config() -> void:
	assert_true(
		PerfModel.budgets_match_config(),
		"vertical_slice_performance_model.gd must match large_map_benchmark_config.json"
	)


func test_minimum_hardware_profile_is_declared() -> void:
	var source := FileAccess.get_file_as_string(PerfModel.MINIMUM_HARDWARE_PROFILE)
	assert_false(source.is_empty())
	var parsed: Variant = JSON.parse_string(source)
	assert_true(parsed is Dictionary)
	var profile := parsed as Dictionary
	assert_eq(profile.get("status"), "declared_minimum_target")
	assert_eq(profile.get("profile_id"), "minimum-hardware-intel-uhd-620")


func test_slice_gate_metrics_have_authored_limits() -> void:
	var budgets := PerfModel.budget_dictionary()
	for metric in PerfModel.SLICE_GATE_METRICS:
		match metric:
			"frame_time_ms_p95":
				assert_eq(budgets["steady_frame_time_ms_p95"], PerfModel.STEADY_FRAME_TIME_MS_P95)
			"memory_delta_mib":
				assert_eq(budgets["resident_memory_delta_mib"], PerfModel.RESIDENT_MEMORY_DELTA_MIB)
			"node_count":
				assert_eq(budgets["resident_node_count"], PerfModel.RESIDENT_NODE_COUNT)
			"collision_count":
				assert_eq(budgets["resident_collision_count"], PerfModel.RESIDENT_COLLISION_COUNT)
			"bird_audio_peak":
				assert_eq(budgets["bird_audio_peak"], PerfModel.BIRD_AUDIO_PEAK)
			"bird_flight_peak":
				assert_eq(budgets["bird_flight_peak"], PerfModel.BIRD_FLIGHT_PEAK)
			_:
				fail("unexpected slice gate metric: %s" % metric)
