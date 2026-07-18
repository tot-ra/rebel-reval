extends Node

## Opt-in headless instrumentation for ADR 0010. This exercises the current
## production builders without adding streaming behavior to production scenes.

const LowerTownDefinitionFactory := preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")
const MapAssemblerScript := preload("res://scripts/map/map_assembler.gd")
const MapBuilderScript := preload("res://scripts/map/map_builder.gd")
const MapNavBuilderScript := preload("res://scripts/map/map_nav_builder.gd")
const MapSceneBootstrapScript := preload("res://scripts/map/map_scene_bootstrap.gd")
const ChunkPrototype := preload("res://tools/benchmarks/large_map_chunk_prototype.gd")

const DEFAULT_OUTPUT := "user://large_map_benchmark.json"
const MIB := 1024.0 * 1024.0

var _config: Dictionary = {}
var _timed_runs := 3
var _warmup_runs := 1
var _frame_samples := 120


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_config = ChunkPrototype.load_config()
	if _config.is_empty():
		get_tree().quit(1)
		return
	var benchmark_config := _config.get("benchmark", {}) as Dictionary
	_timed_runs = int(benchmark_config.get("timed_runs", 3))
	_warmup_runs = int(benchmark_config.get("warmup_runs", 1))
	_frame_samples = int(benchmark_config.get("frame_samples", 120))
	if _has_flag("--quick"):
		_timed_runs = 1
		_warmup_runs = 0
		_frame_samples = mini(_frame_samples, 20)

	var report := {
		"schema_version": 1,
		"recorded_utc": Time.get_datetime_string_from_system(true),
		"engine": Engine.get_version_info(),
		"environment": {
			"os": OS.get_name(),
			"distribution": OS.get_distribution_name(),
			"processor_count": OS.get_processor_count(),
			"processor_name": OS.get_processor_name(),
			"video_adapter": RenderingServer.get_video_adapter_name(),
			"headless": DisplayServer.get_name() == "headless",
		},
		"git_commit": _git_commit(),
		"config": _config,
		"methodology": {
			"warmup_runs": _warmup_runs,
			"timed_runs": _timed_runs,
			"frame_samples": _frame_samples,
			"memory_monitor": "Performance.MEMORY_STATIC",
			"frame_time_clock": "wall time between SceneTree.process_frame signals",
		},
		"profiles": [],
	}

	print("BENCHMARK Lower Town production pipeline")
	report["profiles"].append(await _benchmark_lower_town_pipeline())
	print("BENCHMARK Lower Town production scene")
	var scene_baseline_path := _argument_value("--scene-baseline=", "")
	if scene_baseline_path.is_empty():
		report["profiles"].append({
			"id": "lower_town_scene",
			"kind": "production_scene_with_3d_view",
			"available": false,
			"reason": "Run tools/benchmarks/run_large_map_benchmark.sh to capture the scene with project autoloads.",
			"metrics": {},
		})
	else:
		report["profiles"].append(_load_scene_baseline(scene_baseline_path))
	for profile_config in benchmark_config.get("synthetic_profiles", []):
		var size_cells := int(profile_config.get("size_cells", 0))
		print("BENCHMARK synthetic %dx%d" % [size_cells, size_cells])
		report["profiles"].append(await _benchmark_synthetic(String(profile_config.get("id", "synthetic")), size_cells))

	report["budget_summary"] = _budget_summary(report["profiles"])
	var output_path := _argument_value("--output=", DEFAULT_OUTPUT)
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write benchmark report: %s" % output_path)
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("BENCHMARK report: %s" % output_path)
	print(JSON.stringify(report["budget_summary"], "  "))
	get_tree().quit(0)


func _benchmark_lower_town_pipeline() -> Dictionary:
	for ignored in _warmup_runs:
		await _run_lower_town_pipeline_once(false)
	var runs: Array[Dictionary] = []
	for ignored in _timed_runs:
		runs.append(await _run_lower_town_pipeline_once(true))
	return _summarize_runs("lower_town_pipeline", "production_pipeline", LowerTownDefinitionFactory.create().size_cells, runs)


func _run_lower_town_pipeline_once(sample_frames: bool) -> Dictionary:
	var memory_before := _memory_bytes()
	var started := Time.get_ticks_usec()
	var definition: MapDefinition = LowerTownDefinitionFactory.create()
	var compile_ms := _elapsed_ms(started)

	started = Time.get_ticks_usec()
	var grid: MapTerrainGrid = MapBuilderScript.build(definition)
	var terrain_build_ms := _elapsed_ms(started)

	var host := Node2D.new()
	host.name = "BenchmarkHost"
	get_tree().root.add_child(host)
	started = Time.get_ticks_usec()
	MapAssemblerScript.assemble(host, definition, grid)
	var visual_assembly_ms := _elapsed_ms(started)

	started = Time.get_ticks_usec()
	var navigation := MapNavBuilderScript.create_navigation_region(definition, grid)
	host.add_child(navigation)
	var navigation_bake_ms := _elapsed_ms(started)
	await get_tree().process_frame

	var frame_times: Array[float] = []
	if sample_frames:
		frame_times = await _sample_frame_times()
	var result := _capture_tree_metrics(host, memory_before)
	result.merge({
		"compile_ms": compile_ms,
		"terrain_build_ms": terrain_build_ms,
		"visual_assembly_ms": visual_assembly_ms,
		"navigation_bake_ms": navigation_bake_ms,
		"pipeline_cpu_ms": compile_ms + terrain_build_ms + visual_assembly_ms + navigation_bake_ms,
		"frame_time_ms": _distribution(frame_times),
		"semantic_counts": _semantic_counts(definition),
	})
	host.queue_free()
	await get_tree().process_frame
	return result


func _load_scene_baseline(path: String) -> Dictionary:
	var source := FileAccess.get_file_as_string(path)
	var run: Variant = JSON.parse_string(source)
	if not run is Dictionary:
		push_error("Invalid Lower Town scene baseline: %s" % path)
		return {
			"id": "lower_town_scene",
			"kind": "production_scene_with_3d_view",
			"available": false,
			"reason": "Invalid scene baseline JSON: %s" % path,
			"metrics": {},
		}
	var runs: Array[Dictionary] = [run]
	var result := _summarize_runs("lower_town_scene", "production_scene_with_3d_view", LowerTownDefinitionFactory.create().size_cells, runs)
	result["available"] = true
	return result


func _benchmark_synthetic(profile_id: String, size: int) -> Dictionary:
	for ignored in _warmup_runs:
		await _run_synthetic_once(size, false)
	var runs: Array[Dictionary] = []
	for ignored in _timed_runs:
		runs.append(await _run_synthetic_once(size, true))
	return _summarize_runs(profile_id, "non_production_monolithic_synthetic", Vector2i(size, size), runs)


func _run_synthetic_once(size: int, sample_frames: bool) -> Dictionary:
	var memory_before := _memory_bytes()
	var started := Time.get_ticks_usec()
	var definition := _create_synthetic_definition(size)
	var definition_create_ms := _elapsed_ms(started)

	started = Time.get_ticks_usec()
	var grid: MapTerrainGrid = MapBuilderScript.build(definition)
	var terrain_build_ms := _elapsed_ms(started)

	var host := Node2D.new()
	host.name = "SyntheticBenchmarkHost"
	var actors := Node2D.new()
	actors.name = "Actors"
	host.add_child(actors)
	get_tree().root.add_child(host)

	started = Time.get_ticks_usec()
	var bootstrap := MapSceneBootstrapScript.assemble(host, definition, actors)
	var bootstrap_ms := _elapsed_ms(started)
	var terrain_renderer := bootstrap["assembled"]["terrain"] as MapTerrainRenderer
	started = Time.get_ticks_usec()
	terrain_renderer.update_active_chunks(Vector2(size - 1, size - 1) * float(definition.cell_size))
	var terrain_chunk_reload_ms := _elapsed_ms(started)
	# Isolate current nav cost as well; this duplicate bake is benchmark-only and
	# excluded from pipeline_cpu_ms because bootstrap already includes one bake.
	started = Time.get_ticks_usec()
	var isolated_navigation := MapNavBuilderScript.create_navigation_region(definition, grid)
	var navigation_bake_ms := _elapsed_ms(started)
	isolated_navigation.free()
	await get_tree().process_frame

	var frame_times: Array[float] = []
	if sample_frames:
		frame_times = await _sample_frame_times()
	var result := _capture_tree_metrics(host, memory_before)
	result.merge({
		"definition_create_ms": definition_create_ms,
		"terrain_build_ms": terrain_build_ms,
		"terrain_resident_chunk_count": terrain_renderer.loaded_chunk_count(),
		"terrain_resident_node_count": terrain_renderer.get_child_count(),
		"terrain_chunk_reload_ms": terrain_chunk_reload_ms,
		"bootstrap_ms": bootstrap_ms,
		"navigation_bake_ms": navigation_bake_ms,
		"pipeline_cpu_ms": definition_create_ms + bootstrap_ms,
		"frame_time_ms": _distribution(frame_times),
		"semantic_counts": _semantic_counts(definition),
		"navigation_polygon_count": (bootstrap["navigation"] as NavigationRegion2D).navigation_polygon.get_polygon_count(),
	})
	host.queue_free()
	await get_tree().process_frame
	return result


func _create_synthetic_definition(size: int) -> MapDefinition:
	var definition := MapDefinition.new()
	definition.map_id = StringName("benchmark.synthetic_%d" % size)
	definition.location = StringName("loc.benchmark.synthetic_%d" % size)
	definition.scope = &"prototype"
	definition.active = false
	definition.palette = &"clean_painted"
	definition.size_cells = Vector2i(size, size)
	definition.base_terrain = MapTypes.TERRAIN_DIRT
	definition.player_spawn = Vector2.ONE * float(definition.cell_size * 2)
	definition.camera_bounds = Rect2(Vector2.ZERO, definition.world_size())
	definition.fingerprint = "benchmark-v1-%d" % size

	# Water lanes preserve Lower Town's expensive per-cell collision behavior.
	for x in range(15, size, 16):
		definition.zones.append({"rect": Rect2i(x, 0, 1, size), "terrain": MapTypes.TERRAIN_WATER})

	var benchmark_config := _config.get("benchmark", {}) as Dictionary
	var stride := int(benchmark_config.get("building_stride_cells", 8))
	for y in range(2, size - 3, stride):
		for x in range(3, size - 3, stride):
			definition.buildings.append({
				"id": StringName("building.%d.%d" % [x, y]),
				"kind": MapTypes.BUILDING_KIND_HOUSE,
				"footprint": definition.cell_rect_to_world_rect(Rect2i(x, y, 3, 3)),
				"wall_height": 96.0,
			})

	var chunk_size := int(_config.get("chunk_size_cells", 32))
	var props_per_chunk := int(benchmark_config.get("props_per_chunk", 4))
	var chunk_count := ceili(float(size) / float(chunk_size))
	for chunk_y in chunk_count:
		for chunk_x in chunk_count:
			for prop_index in props_per_chunk:
				var cell := Vector2i(chunk_x * chunk_size + 2 + prop_index * 2, chunk_y * chunk_size + 2)
				if cell.x >= size or cell.y >= size:
					continue
				definition.props.append({
					"id": StringName("prop.%d.%d.%d" % [chunk_x, chunk_y, prop_index]),
					"kind": MapTypes.PROP_KIND_BARRELS,
					"position": definition.cell_rect_center(Rect2i(cell, Vector2i.ONE)),
				})
	return definition


func _capture_tree_metrics(root_node: Node, memory_before: int) -> Dictionary:
	return {
		"node_count": _count_nodes(root_node),
		"collision_count": _count_collisions(root_node),
		"memory_static_bytes": _memory_bytes(),
		"memory_delta_mib": maxf(0.0, float(_memory_bytes() - memory_before) / MIB),
	}


func _count_nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count


func _count_collisions(node: Node) -> int:
	var count := 1 if node is CollisionShape2D or node is CollisionPolygon2D else 0
	for child in node.get_children():
		count += _count_collisions(child)
	return count


func _semantic_counts(definition: MapDefinition) -> Dictionary:
	return {
		"cells": definition.size_cells.x * definition.size_cells.y,
		"zones": definition.zones.size(),
		"buildings": definition.buildings.size(),
		"props": definition.props.size(),
		"transitions": definition.transitions.size(),
		"anchors": definition.interaction_anchors.size(),
	}


func _sample_frame_times() -> Array[float]:
	var samples: Array[float] = []
	var previous := Time.get_ticks_usec()
	for ignored in _frame_samples:
		await get_tree().process_frame
		var current := Time.get_ticks_usec()
		samples.append(float(current - previous) / 1000.0)
		previous = current
	return samples


func _summarize_runs(profile_id: String, kind: String, size: Vector2i, runs: Array[Dictionary]) -> Dictionary:
	var summary := {
		"id": profile_id,
		"kind": kind,
		"size_cells": [size.x, size.y],
		"runs": runs,
		"metrics": {},
	}
	if runs.is_empty():
		return summary
	for key in runs[0].keys():
		if runs[0][key] is int or runs[0][key] is float:
			var values: Array[float] = []
			for run in runs:
				values.append(float(run[key]))
			summary["metrics"][key] = _distribution(values)
	# Frame timing is already a per-run distribution; summarize each percentile.
	if runs[0].has("frame_time_ms"):
		for percentile in ["median", "p95", "p99", "max"]:
			var values: Array[float] = []
			for run in runs:
				values.append(float(run["frame_time_ms"].get(percentile, 0.0)))
			summary["metrics"]["frame_time_ms_%s" % percentile] = _distribution(values)
	summary["semantic_counts"] = runs[0].get("semantic_counts", {})
	return summary


func _distribution(input_values: Array[float]) -> Dictionary:
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


func _percentile(sorted_values: Array[float], fraction: float) -> float:
	return sorted_values[clampi(ceili(float(sorted_values.size()) * fraction) - 1, 0, sorted_values.size() - 1)]


func _budget_summary(profiles: Array) -> Dictionary:
	var budgets := _config.get("budgets", {}) as Dictionary
	var summary := {
		"note": "Hardware observations are evidence, not CI gates. pass=false identifies work the future chunk runtime must avoid or reduce.",
		"profiles": {},
	}
	for profile in profiles:
		var metrics := profile.get("metrics", {}) as Dictionary
		var checks := {
			"node_count": _check_budget(metrics, "node_count", "median", float(budgets.get("resident_node_count", INF))),
			"collision_count": _check_budget(metrics, "collision_count", "median", float(budgets.get("resident_collision_count", INF))),
			"memory_delta_mib": _check_budget(metrics, "memory_delta_mib", "p95", float(budgets.get("resident_memory_delta_mib", INF))),
			"frame_time_ms_p95": _check_budget(metrics, "frame_time_ms_p95", "p95", float(budgets.get("steady_frame_time_ms_p95", INF))),
			"navigation_bake_ms": _check_budget(metrics, "navigation_bake_ms", "p95", float(budgets.get("chunk_navigation_bake_ms_p95", INF))),
			"terrain_resident_node_count": _check_budget(metrics, "terrain_resident_node_count", "median", 25.0),
			"terrain_chunk_reload_ms": _check_budget(metrics, "terrain_chunk_reload_ms", "p95", float(budgets.get("chunk_activation_cpu_ms_p95", INF))),
		}
		if String(profile.get("id", "")) == "synthetic_32":
			checks["chunk_activation_cpu_ms"] = _check_budget(metrics, "pipeline_cpu_ms", "p95", float(budgets.get("chunk_activation_cpu_ms_p95", INF)))
		summary["profiles"][profile.get("id", "unknown")] = checks
	return summary


func _check_budget(metrics: Dictionary, metric: String, statistic: String, limit: float) -> Dictionary:
	if not metrics.has(metric):
		return {"available": false, "limit": limit}
	var observed := float(metrics[metric].get(statistic, 0.0))
	return {"available": true, "observed": observed, "limit": limit, "pass": observed <= limit}


func _memory_bytes() -> int:
	return int(Performance.get_monitor(Performance.MEMORY_STATIC))


func _elapsed_ms(started_usec: int) -> float:
	return float(Time.get_ticks_usec() - started_usec) / 1000.0


func _argument_value(prefix: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return fallback


func _has_flag(flag: String) -> bool:
	return OS.get_cmdline_user_args().has(flag)


func _git_commit() -> String:
	var output: Array = []
	if OS.execute("git", PackedStringArray(["rev-parse", "HEAD"]), output, true) == 0 and not output.is_empty():
		return String(output[0]).strip_edges()
	return "unknown"
