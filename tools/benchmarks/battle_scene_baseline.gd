extends SceneTree

## Standalone Tier-2 crowd benchmark for P0-154.
##
## WHY: the ordinary map benchmark is dominated by map assembly and cannot
## isolate the shared MultiMesh crowd path. This probe keeps the production
## renderer while creating a deterministic battle formation at the authored
## density, then records steady frame time, draw calls, and memory.

const CrowdRenderer := preload("res://scripts/map/view3d/map_view_crowd_renderer.gd")
const CONFIG_PATH := "res://tools/benchmarks/large_map_benchmark_config.json"
const DEFAULT_OUTPUT := "user://battle_scene_baseline.json"
const MIB := 1024.0 * 1024.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var config := _load_config()
	if config.is_empty():
		quit(1)
		return
	var crowd_config := config.get("crowd_benchmark", {}) as Dictionary
	var cap := int(crowd_config.get("concurrent_character_cap", 0))
	var target_count := _argument_int("--crowd-count=", int(crowd_config.get("target_count", 0)))
	var contract_error := validate_contract(crowd_config, target_count)
	if not contract_error.is_empty():
		push_error(contract_error)
		quit(1)
		return

	var memory_before := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var host := Node3D.new()
	host.name = "BattleBenchmark"
	root.add_child(host)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 14.0, 24.0)
	camera.look_at_from_position(camera.position, Vector3.ZERO, Vector3.UP)
	host.add_child(camera)
	camera.current = true

	var renderer := CrowdRenderer.new()
	renderer.name = "Tier2Crowd"
	host.add_child(renderer)
	renderer.configure(cap, int(crowd_config.get("seed", 154)))
	if renderer.capacity() != cap:
		push_error(
			"Crowd renderer capacity %d does not match authored cap %d" % [renderer.capacity(), cap]
		)
		host.queue_free()
		quit(1)
		return

	var spacing := float(crowd_config.get("spacing_m", 1.35))
	var columns := int(crowd_config.get("formation_columns", 20))
	for actor_index in target_count:
		var row := actor_index / columns
		var column := actor_index % columns
		var position := Vector3(
			(float(column) - float(columns - 1) * 0.5) * spacing,
			0.0,
			(float(row) - float(ceili(float(target_count) / float(columns)) - 1) * 0.5) * spacing
		)
		renderer.set_actor_position(actor_index + 1, position)

	var warmup_frames := int(crowd_config.get("warmup_frames", 30))
	var sample_frames := int(crowd_config.get("sample_frames", 120))
	if _has_flag("--quick"):
		warmup_frames = mini(warmup_frames, 5)
		sample_frames = mini(sample_frames, 20)
	for ignored in warmup_frames:
		await process_frame

	var frame_times: Array[float] = []
	var draw_calls_peak := 0
	var previous := Time.get_ticks_usec()
	for ignored in sample_frames:
		await process_frame
		var current := Time.get_ticks_usec()
		frame_times.append(float(current - previous) / 1000.0)
		previous = current
		draw_calls_peak = maxi(
			draw_calls_peak,
			int(
				RenderingServer.get_rendering_info(
					RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
				)
			)
		)

	var memory_after := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var report := {
		"id": "crowd_character_peak",
		"kind": "tier2_multimesh_battle_scene",
		"target_count": target_count,
		"active_count": renderer.active_count(),
		"concurrent_character_cap": cap,
		"capacity": renderer.capacity(),
		"density_characters_per_square_metre": _formation_density(target_count, columns, spacing),
		"draw_calls_peak": draw_calls_peak,
		"memory_static_bytes": memory_after,
		"memory_delta_mib": maxf(0.0, float(memory_after - memory_before) / MIB),
		"frame_time_ms": _distribution(frame_times),
	}
	var output_path := _argument_value("--output=", DEFAULT_OUTPUT)
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write battle benchmark: %s" % output_path)
		host.queue_free()
		quit(1)
		return
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("BENCHMARK crowd_character_peak: %s" % JSON.stringify(report))
	host.queue_free()
	quit(0)


static func validate_contract(crowd_config: Dictionary, requested_count: int) -> String:
	var cap := int(crowd_config.get("concurrent_character_cap", 0))
	var target := int(crowd_config.get("target_count", 0))
	if cap <= 0:
		return "crowd_benchmark.concurrent_character_cap must be positive"
	if target <= 0:
		return "crowd_benchmark.target_count must be positive"
	if target > cap:
		return "Authored crowd target %d exceeds concurrent-character cap %d" % [target, cap]
	if requested_count <= 0:
		return "Requested crowd count must be positive"
	if requested_count > cap:
		return (
			"Requested crowd count %d exceeds concurrent-character cap %d" % [requested_count, cap]
		)
	return ""


static func _formation_density(count: int, columns: int, spacing: float) -> float:
	if count <= 0 or columns <= 0 or spacing <= 0.0:
		return 0.0
	var used_columns := mini(count, columns)
	var rows := ceili(float(count) / float(columns))
	var width := maxf(spacing, float(used_columns) * spacing)
	var depth := maxf(spacing, float(rows) * spacing)
	return float(count) / (width * depth)


static func _distribution(input_values: Array[float]) -> Dictionary:
	if input_values.is_empty():
		return {"samples": 0, "median": 0.0, "p95": 0.0, "p99": 0.0, "max": 0.0}
	var values := input_values.duplicate()
	values.sort()
	return {
		"samples": values.size(),
		"median": values[values.size() / 2],
		"p95": _percentile(values, 0.95),
		"p99": _percentile(values, 0.99),
		"max": values[-1],
	}


static func _percentile(sorted_values: Array[float], fraction: float) -> float:
	return sorted_values[clampi(
		ceili(float(sorted_values.size()) * fraction) - 1, 0, sorted_values.size() - 1
	)]


func _load_config() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if not parsed is Dictionary:
		push_error("Could not parse crowd benchmark config: %s" % CONFIG_PATH)
		return {}
	return parsed as Dictionary


func _argument_value(prefix: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return fallback


func _argument_int(prefix: String, fallback: int) -> int:
	return int(_argument_value(prefix, str(fallback)))


func _has_flag(flag: String) -> bool:
	return OS.get_cmdline_user_args().has(flag)
