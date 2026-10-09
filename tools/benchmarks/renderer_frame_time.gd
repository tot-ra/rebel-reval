extends SceneTree
## P0-142 per-renderer frame time (vsync off, so 1000 / ms = FPS) on the live game world (continuous Reval city, ADR 0031)
## and the Kalev smithy interior. Renders in the root window like the game, not a SubViewport.
##   tools/godot_render.sh --rendering-method mobile --rendering-driver metal --resolution 1920x1080 \
##     --disable-vsync --script res://tools/benchmarks/renderer_frame_time.gd -- \
##     --output=res://build/hdr_spike/frame_time_mobile.json [--frames=90]
##
## WHY: tools/run_performance_report.sh and the vegetation benchmark still load retired legacy
## scenes (scenes/reval_east, lower_town_slice) and cannot measure the current world. Shots reuse
## tools/capture_reval_city.gd so the cameras match the committed review plates.

const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")
const Registry := preload("res://scripts/map/map_audit_registry.gd")
const CityShots := preload("res://tools/capture_reval_city.gd")
const CITY_SHOTS: Array[String] = [
	"forum", "from_toompea_over_roofs", "city_aerial_ne", "smithy_cutaway"
]
## Cycle progress: late morning and midnight.
const TIMES := {"day": 0.42, "night": 0.0}
const WARMUP_FRAMES := 20

var _frames := 90


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var output := "res://build/hdr_spike/frame_time.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		elif arg.begins_with("--frames="):
			_frames = int(arg.trim_prefix("--frames="))
	var report := {
		"task_id": "P0-142",
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"video_adapter": RenderingServer.get_video_adapter_name(),
		"render_size": root.get_visible_rect().size,
		"frames": _frames,
		"shots": [],
	}
	var city_start := Time.get_ticks_msec()
	var plan := CityPlan.load_default()
	var world := CityWorld3D.create(plan)
	root.add_child(world)
	var camera := Camera3D.new()
	camera.far = 6000.0
	camera.near = 0.15
	root.add_child(camera)
	camera.make_current()
	world.setup_lighting(camera)
	report["city_build_ms"] = Time.get_ticks_msec() - city_start
	var shot_source: Object = CityShots.new()
	var shots: Array = shot_source.call("_shots", plan)
	shot_source.free()
	for shot: Dictionary in shots:
		if not String(shot["name"]) in CITY_SHOTS:
			continue
		for time_name: String in TIMES:
			camera.fov = shot["fov"]
			camera.look_at_from_position(shot["eye"], shot["look"], Vector3.UP)
			for site in plan.sites:
				for r: Dictionary in site.rooms:
					world.set_site_room_hidden(site, r, bool(shot.get("cutaway", false)))
			world.apply_time(TIMES[time_name])
			(report["shots"] as Array).append(await _measure("city/%s/%s" % [shot["name"], time_name]))
	world.queue_free()
	camera.queue_free()
	await process_frame
	var definition: MapDefinition = Registry.by_id()["kalev_smithy"]
	for time_of_day in [MapView3D.TIME_DAY, MapView3D.TIME_NIGHT]:
		var view := MapView3D.create(definition, MapBuilder.build(definition), time_of_day)
		root.add_child(view)
		await view.assemble_async(200.0)
		view.set_close_camera_mode(true)
		var eye := Camera3D.new()
		eye.fov = 70.0
		eye.near = 0.05
		root.add_child(eye)
		eye.make_current()
		eye.position = Vector3(15.8, 1.65, 11.6)
		eye.look_at(Vector3(20.5, 1.1, 2.0), Vector3.UP)
		(report["shots"] as Array).append(await _measure("smithy/forge_bay/%s" % time_of_day))
		view.queue_free()
		eye.queue_free()
		await process_frame
	var medians: Array[float] = []
	for row: Dictionary in report["shots"]:
		medians.append(row["frame_ms_median"])
	medians.sort()
	report["frame_ms_median_of_shots"] = medians[medians.size() / 2]
	report["frame_ms_worst_shot"] = medians[-1]
	report["fps_median_of_shots"] = 1000.0 / medians[medians.size() / 2]
	var absolute := ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("Renderer frame time %s: median shot %.2f ms (%.0f FPS), worst %.2f ms -> %s" % [
		report["rendering_method"], report["frame_ms_median_of_shots"], report["fps_median_of_shots"],
		report["frame_ms_worst_shot"], output])
	quit(0)


## Median/p95 wall frame time over `_frames` frames after warm-up. The RenderingServer GPU
## timer reads 0 for the minimized godot_render.sh window, so wall time is the measure.
func _measure(label: String) -> Dictionary:
	for _frame in WARMUP_FRAMES:
		await process_frame
	var wall: Array[float] = []
	var last := Time.get_ticks_usec()
	for _frame in _frames:
		await process_frame
		var now := Time.get_ticks_usec()
		wall.append(float(now - last) / 1000.0)
		last = now
	wall.sort()
	var row := {
		"shot": label,
		"frame_ms_median": wall[wall.size() / 2],
		"frame_ms_p95": wall[int(wall.size() * 0.95)],
		"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
	}
	print("  %s: frame %.2f ms (p95 %.2f)" % [label, row["frame_ms_median"], row["frame_ms_p95"]])
	return row
