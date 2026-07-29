extends Node

## Headless or windowed Lower Town renderer comparison capture for P0-142.
## Run through renderer_comparison_benchmark.tscn with --rendering-method on the Godot CLI.

const DEFAULT_OUTPUT := "user://renderer_comparison.json"
const MIB := 1024.0 * 1024.0

var _started_usec := Time.get_ticks_usec()
var _memory_before := 0


func _enter_tree() -> void:
	_memory_before = int(Performance.get_monitor(Performance.MEMORY_STATIC))


func _ready() -> void:
	call_deferred("_record")


func _record() -> void:
	await get_tree().process_frame
	var startup_ms := float(Time.get_ticks_usec() - _started_usec) / 1000.0
	var frame_count := 120
	var capture_path := ""
	for argument in OS.get_cmdline_user_args():
		if argument == "--quick":
			frame_count = 20
		elif argument.begins_with("--output="):
			pass
		elif argument.begins_with("--capture="):
			capture_path = argument.trim_prefix("--capture=")

	var frame_times: Array[float] = []
	var previous := Time.get_ticks_usec()
	var scene_root := get_parent().get_node("LowerTown")
	for ignored in frame_count:
		await get_tree().process_frame
		var current := Time.get_ticks_usec()
		frame_times.append(float(current - previous) / 1000.0)
		previous = current

	var memory_after := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var texture_memory := int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
	var render_memory := int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
	var rendering_method := _requested_renderer()
	var display_driver := DisplayServer.get_name()
	var report := {
		"rendering_method": rendering_method,
		"display_driver": display_driver,
		"headless": display_driver == "headless",
		"scene_startup_ms": startup_ms,
		"memory_static_bytes": memory_after,
		"memory_delta_mib": maxf(0.0, float(memory_after - _memory_before) / MIB),
		"texture_memory_bytes": texture_memory,
		"render_video_memory_bytes": render_memory,
		"frame_time_ms": _distribution(frame_times),
		"fidelity_features": _probe_fidelity_features(scene_root, rendering_method),
	}
	if not capture_path.is_empty():
		report["capture_path"] = capture_path
		_write_capture(scene_root, capture_path)

	var output_path := DEFAULT_OUTPUT
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write renderer comparison report: %s" % output_path)
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	get_tree().quit(0)


func _requested_renderer() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--renderer-requested="):
			return argument.trim_prefix("--renderer-requested=")
	return str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown"))


func _probe_fidelity_features(scene_root: Node, rendering_method: String) -> Dictionary:
	var environment: Environment = null
	var directional_shadow := false
	var view_runtime: MapViewRuntime = scene_root.get_node_or_null("MapViewRuntime")
	if view_runtime != null and view_runtime.view != null:
		var view_3d: MapView3D = view_runtime.view
		var world_env := view_3d.get_node_or_null("ViewEnvironment")
		if world_env is WorldEnvironment:
			environment = world_env.environment
		var sun := view_3d.sun_light()
		if sun != null:
			directional_shadow = sun.shadow_enabled

	var forward_or_mobile := rendering_method in ["forward_plus", "mobile"]
	return {
		"ssao_supported": forward_or_mobile,
		"ssil_supported": rendering_method == "forward_plus",
		"sdfgi_supported": rendering_method == "forward_plus",
		"volumetric_fog_supported": forward_or_mobile,
		"screen_space_reflections_supported": rendering_method == "forward_plus",
		"glow_enabled": environment.glow_enabled if environment != null else false,
		"tonemap_mode": environment.tonemap_mode if environment != null else -1,
		"fog_enabled": environment.fog_enabled if environment != null else false,
		"directional_shadow_enabled": directional_shadow,
	}


func _write_capture(_scene_root: Node, capture_path: String) -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		push_warning("Renderer comparison capture skipped empty framebuffer: %s" % capture_path)
		return
	var absolute := capture_path
	if capture_path.begins_with("res://") or capture_path.begins_with("user://"):
		absolute = ProjectSettings.globalize_path(capture_path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	image.save_png(absolute)


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
