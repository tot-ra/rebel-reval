extends SceneTree

## R-799 water-only benchmark protocol runner.
##
## The runner measures an intentionally isolated baseline node and the same node
## with one representative production material per authored water family. Deltas, rather
## than complete-scene totals, prevent generic map cost from being relabelled as
## water cost. Target identity is kept separate from the detected measurement
## host so non-target and headless runs stay supplementary.

const DEFAULT_CONFIG := "res://tools/benchmarks/r715_water_benchmark_config.json"
const DEFAULT_TIER := "recommended"
const MapViewMaterialsScript := preload("res://scripts/map/view3d/map_view_materials.gd")
const MIB := 1024.0 * 1024.0
const WATER_TERRAINS: Array[StringName] = [
	&"water", &"river_water", &"shallow_water", &"deep_water"
]

var _config: Dictionary = {}
var _tier_id := DEFAULT_TIER
var _samples := 120
var _warmup_frames := 30


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var config_path := _argument_value("--config=", DEFAULT_CONFIG)
	_config = _load_json(config_path)
	_tier_id = _argument_value("--tier=", DEFAULT_TIER)
	var errors := validate_config(_config)
	if not errors.is_empty():
		for error: String in errors:
			push_error(error)
		quit(1)
		return
	var tiers: Dictionary = _config["tiers"]
	if not tiers.has(_tier_id):
		push_error("Unknown R-715 benchmark tier: %s" % _tier_id)
		quit(1)
		return
	_samples = maxi(int(_config["minimum_samples"]), int(_argument_value("--samples=", "120")))
	_warmup_frames = maxi(0, int(_config.get("warmup_frames", 30)))
	var tier: Dictionary = tiers[_tier_id]
	var target: Dictionary = _load_json(String(tier["target_hardware"]))
	if target.is_empty():
		push_error("Could not load target hardware for tier %s" % _tier_id)
		quit(1)
		return

	var host_identity := measurement_host_identity()
	var renderer_identity := renderer_identity()
	var baseline := await _sample_phase(false)
	var with_water := await _sample_phase(true)
	var metrics := water_only_metrics(baseline, with_water)
	var identity_matches: bool = host_matches_target(host_identity, target)
	var acceptance_eligible: bool = (
		identity_matches and bool(renderer_identity["headless"]) == false
	)
	var report := {
		"schema_version": 1,
		"protocol_id": _config["protocol_id"],
		"task": "R-755",
		"protocol_owner": "R-799",
		"tier": _tier_id,
		"status": "MEASURED" if acceptance_eligible else "SUPPLEMENTARY",
		"budget_scope": "water_only",
		"target_hardware": target,
		"measurement_host": host_identity,
		"renderer": renderer_identity,
		"samples": _samples,
		"metrics": metrics,
		"thresholds": merged_thresholds(tier),
		"fallback": _config["fallback"],
		"map_matrix": _config["map_matrix"],
		"methodology":
		{
			"baseline": "isolated representative surfaces hidden",
			"water_phase": "one visible representative surface per closed water terrain family",
			"frame_clock": "wall time between SceneTree.process_frame signals",
			"metric_attribution":
			"water phase minus baseline phase; counts are node-owned resource deltas",
		},
		"acceptance":
		{
			"eligible": acceptance_eligible,
			"target_matches_measurement_host": identity_matches,
			"real_renderer": renderer_identity["headless"] == false,
			"reason": acceptance_reason(identity_matches, bool(renderer_identity["headless"])),
		},
	}
	var output_path := _argument_value("--output=", String(tier["output"]))
	var absolute_output := _globalize_output(output_path)
	DirAccess.make_dir_recursive_absolute(absolute_output.get_base_dir())
	var file := FileAccess.open(absolute_output, FileAccess.WRITE)
	if file == null:
		push_error("Could not write R-715 water benchmark: %s" % absolute_output)
		quit(1)
		return
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("R-715 water-only benchmark: %s" % absolute_output)
	print("R-715 evidence status: %s" % report["status"])
	quit(0)


static func validate_config(config: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if config.get("budget_scope") != "water_only":
		errors.append("R-715 benchmark budget_scope must be water_only")
	if int(config.get("minimum_samples", 0)) < 120:
		errors.append("R-715 benchmark requires at least 120 samples")
	var tiers: Variant = config.get("tiers")
	if not tiers is Dictionary:
		errors.append("R-715 benchmark config must declare tiers")
		return errors
	for tier_id: String in ["minimum", "recommended"]:
		if not tiers.has(tier_id) or not tiers[tier_id] is Dictionary:
			errors.append("R-715 benchmark missing tier: %s" % tier_id)
			continue
		var tier: Dictionary = tiers[tier_id]
		for identity_key: String in ["target_hardware", "output", "quality", "thresholds"]:
			if not tier.has(identity_key):
				errors.append("R-715 tier %s missing %s" % [tier_id, identity_key])
		var thresholds: Variant = tier.get("thresholds")
		if not thresholds is Dictionary:
			errors.append("R-715 tier %s thresholds must be an object" % tier_id)
			continue
		for metric: String in required_metric_keys():
			if not thresholds.has(metric):
				errors.append("R-715 tier %s missing water metric %s" % [tier_id, metric])
		for generic_key: String in [
			"steady_frame_time_ms_p95", "resident_node_count", "resident_memory_delta_mib"
		]:
			if thresholds.has(generic_key):
				errors.append(
					"generic scene metric cannot substitute for water metric: %s" % generic_key
				)
	var fallback: Variant = config.get("fallback")
	if not fallback is Dictionary or fallback.get("id") != "compatibility_water_surface":
		errors.append("R-715 benchmark requires compatibility_water_surface fallback")
	var matrix: Variant = config.get("map_matrix")
	if not matrix is Array or matrix.size() != 13:
		errors.append("R-715 benchmark map_matrix must contain 13 rollout maps")
	return errors


static func required_metric_keys() -> Array[String]:
	return ["frame_time_ms_p95", "draw_calls_peak", "resource_count_peak", "memory_delta_mib"]


static func merged_thresholds(tier: Dictionary) -> Dictionary:
	var result: Dictionary = (tier.get("quality", {}) as Dictionary).duplicate(true)
	result.merge(tier.get("thresholds", {}) as Dictionary, true)
	return result


static func host_matches_target(host: Dictionary, target: Dictionary) -> bool:
	return (
		String(host.get("profile_id", "")) == String(target.get("profile_id", ""))
		and String(host.get("architecture", "")) == String(target.get("architecture", ""))
		and String(host.get("gpu", "")) == String(target.get("gpu", ""))
	)


static func acceptance_reason(identity_matches: bool, headless: bool) -> String:
	if headless:
		return "Headless measurements are supplementary and cannot certify acceptance."
	if not identity_matches:
		return "Measurement host does not match declared target hardware."
	return "Real-renderer measurement host matches the declared target identity."


static func water_only_metrics(baseline: Dictionary, with_water: Dictionary) -> Dictionary:
	return {
		"frame_time_ms_p95":
		maxf(
			0.0,
			(
				float(with_water.get("frame_time_ms_p95", 0.0))
				- float(baseline.get("frame_time_ms_p95", 0.0))
			)
		),
		"draw_calls_peak":
		maxi(
			0, int(with_water.get("draw_calls_peak", 0)) - int(baseline.get("draw_calls_peak", 0))
		),
		"resource_count_peak":
		maxi(
			0,
			(
				int(with_water.get("resource_count_peak", 0))
				- int(baseline.get("resource_count_peak", 0))
			)
		),
		"memory_delta_mib":
		maxf(
			0.0, float(with_water.get("memory_mib", 0.0)) - float(baseline.get("memory_mib", 0.0))
		),
	}


func _sample_phase(include_water: bool) -> Dictionary:
	var host := Node3D.new()
	host.name = "R715WaterBenchmark"
	root.add_child(host)
	if include_water:
		_add_representative_water_surfaces(host)
	for _ignored: int in _warmup_frames:
		await process_frame
	var frame_times: Array[float] = []
	for _ignored: int in _samples:
		var started := Time.get_ticks_usec()
		await process_frame
		frame_times.append(float(Time.get_ticks_usec() - started) / 1000.0)
	var result := {
		"frame_time_ms_p95": percentile(frame_times, 0.95),
		"draw_calls_peak":
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"resource_count_peak": _count_owned_resources(host),
		"memory_mib": float(Performance.get_monitor(Performance.MEMORY_STATIC)) / MIB,
	}
	host.queue_free()
	await process_frame
	return result


func _add_representative_water_surfaces(host: Node3D) -> void:
	for index: int in WATER_TERRAINS.size():
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "Water_%s" % String(WATER_TERRAINS[index])
		var plane := PlaneMesh.new()
		plane.size = Vector2(24.0, 24.0)
		plane.subdivide_width = 16
		plane.subdivide_depth = 16
		mesh_instance.mesh = plane
		mesh_instance.position = Vector3(float(index % 2) * 28.0, 0.0, float(index / 2) * 28.0)
		mesh_instance.material_override = MapViewMaterialsScript.water_surface(
			WATER_TERRAINS[index]
		)
		host.add_child(mesh_instance)


static func percentile(values: Array[float], quantile: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var index := clampi(ceili(float(sorted.size()) * quantile) - 1, 0, sorted.size() - 1)
	return sorted[index]


static func _count_owned_resources(host: Node) -> int:
	var resources: Dictionary = {}
	for child: Node in host.get_children():
		if child is MeshInstance3D:
			var mesh_instance := child as MeshInstance3D
			if mesh_instance.mesh != null:
				resources[mesh_instance.mesh.get_instance_id()] = true
			if mesh_instance.material_override != null:
				resources[mesh_instance.material_override.get_instance_id()] = true
	return resources.size()


static func measurement_host_identity() -> Dictionary:
	return {
		"status": "detected",
		"profile_id": OS.get_environment("R715_MEASUREMENT_PROFILE_ID"),
		"architecture": Engine.get_architecture_name(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"os": OS.get_name(),
		"processor": OS.get_processor_name(),
	}


static func renderer_identity() -> Dictionary:
	return {
		"status": "detected",
		"method": RenderingServer.get_current_rendering_method(),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"display_server": DisplayServer.get_name(),
		"headless": DisplayServer.get_name() == "headless",
	}


static func _load_json(path: String) -> Dictionary:
	var source := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(source)
	if parsed is Dictionary:
		return parsed
	return {}


static func _argument_value(prefix: String, fallback: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return fallback


static func _globalize_output(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	if path.is_absolute_path():
		return path
	return ProjectSettings.globalize_path("res://%s" % path)
