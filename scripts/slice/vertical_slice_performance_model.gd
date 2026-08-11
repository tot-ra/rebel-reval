class_name VerticalSlicePerformanceModel
extends RefCounted

## Authored performance contract for the vertical-slice release (P3-011).
## WHY: slice validation needs one matrix that Godot tests, the benchmark
## runner, and the Python report tool can reference without duplicating budgets.

const BUSIEST_SCENE_PROFILE_ID := &"lower_town_scene"
const BUSIEST_SCENE_PATH := "res://scenes/reval_east/reval_east.tscn"
const MINIMUM_HARDWARE_PROFILE := "res://tools/benchmarks/minimum-hardware.json"
const BENCHMARK_CONFIG_PATH := "res://tools/benchmarks/large_map_benchmark_config.json"

# Headless CI budgets for the shipped slice busiest scene. Limits include
# headroom above the 2026-07-25 development-baseline capture on M5 Pro.
const STEADY_FRAME_TIME_MS_P95 := 16.67
const RESIDENT_MEMORY_DELTA_MIB := 280.0
const RESIDENT_NODE_COUNT := 7500
const RESIDENT_COLLISION_COUNT := 900
const BIRD_AUDIO_PEAK := 3
const BIRD_FLIGHT_PEAK := 4

const SLICE_GATE_METRICS: Array[String] = [
	"frame_time_ms_p95",
	"memory_delta_mib",
	"node_count",
	"collision_count",
	"bird_audio_peak",
	"bird_flight_peak",
]


static func budget_dictionary() -> Dictionary:
	return {
		"steady_frame_time_ms_p95": STEADY_FRAME_TIME_MS_P95,
		"resident_memory_delta_mib": RESIDENT_MEMORY_DELTA_MIB,
		"resident_node_count": RESIDENT_NODE_COUNT,
		"resident_collision_count": RESIDENT_COLLISION_COUNT,
		"bird_audio_peak": BIRD_AUDIO_PEAK,
		"bird_flight_peak": BIRD_FLIGHT_PEAK,
	}


static func load_benchmark_config_budgets() -> Dictionary:
	var source := FileAccess.get_file_as_string(BENCHMARK_CONFIG_PATH)
	if source.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(source)
	if not parsed is Dictionary:
		return {}
	return (parsed as Dictionary).get("budgets", {}) as Dictionary


static func budgets_match_config() -> bool:
	var config := load_benchmark_config_budgets()
	if config.is_empty():
		return false
	var authored := budget_dictionary()
	return (
		float(config.get("steady_frame_time_ms_p95", -1.0)) == authored["steady_frame_time_ms_p95"]
		and (
			float(config.get("resident_memory_delta_mib", -1.0))
			== authored["resident_memory_delta_mib"]
		)
		and float(config.get("resident_node_count", -1.0)) == authored["resident_node_count"]
		and (
			float(config.get("resident_collision_count", -1.0))
			== authored["resident_collision_count"]
		)
		and int(config.get("bird_audio_peak", -1)) == authored["bird_audio_peak"]
		and int(config.get("bird_flight_peak", -1)) == authored["bird_flight_peak"]
	)
