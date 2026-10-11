extends SceneTree
## Frame time inside the real seamless city (people, fauna, interiors, runtime) at spots
## where crowds gather, per graphics quality, in clear daylight:
##   tools/godot_render.sh --resolution 1920x1080 --disable-vsync \
##     --script res://tools/benchmarks/city_crowd_frame_time.gd -- \
##     --output=res://build/benchmarks/city_crowd.json [--spots=poi.forum,poi.fish_landing] \
##     [--qualities=high,mid,low] [--layers]
## `--layers` also runs the PerfMonitor layer-cost measurement at each spot (F4 in the game).

const GraphicsSettingsScript := preload("res://scripts/settings/graphics_settings.gd")
const GraphicsPresetsScript := preload("res://scripts/settings/graphics_presets.gd")
const SETTLE_FRAMES := 90
const MEASURE_FRAMES := 45

var _spots := PackedStringArray(["poi.forum", "poi.fish_landing", "poi.granary.pikk"])
var _qualities := PackedStringArray(["high", "mid", "low"])
var _layers := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var output := "res://build/benchmarks/city_crowd.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		elif arg.begins_with("--spots="):
			_spots = arg.trim_prefix("--spots=").split(",")
		elif arg.begins_with("--qualities="):
			_qualities = arg.trim_prefix("--qualities=").split(",")
		elif arg == "--layers":
			_layers = true
	var settings := GraphicsSettingsScript.default_settings()
	settings.quality = _qualities[0]
	root.get_node("UserSettings").apply_graphics_settings(settings, false)
	var city: Node = (load("res://scenes/world/reval_city/reval_city.tscn") as PackedScene).instantiate()
	root.add_child(city)
	for _i in 60:
		await process_frame
	city.world.sky_weather.auto_weather = false
	city.world.sky_weather.set_weather(SkyWeather3D.WEATHER_CLEAR)
	city.world.sky_weather.advance(SkyWeather3D.TRANSITION_SECONDS + 0.1)
	var monitor := root.get_node("PerfMonitor")
	monitor.mode = 2
	monitor._apply_mode()
	var rows: Array[Dictionary] = []
	for spot in _spots:
		city.arrive_at(spot)
		for _i in SETTLE_FRAMES:
			await process_frame
		for quality in _qualities:
			settings.quality = quality
			root.get_node("UserSettings").apply_graphics_settings(settings, false)
			for _i in 30:
				await process_frame
			var wall: Array[float] = []
			var last := Time.get_ticks_usec()
			for _i in MEASURE_FRAMES:
				await process_frame
				var now := Time.get_ticks_usec()
				wall.append(float(now - last) / 1000.0)
				last = now
			wall.sort()
			var row := {
				"spot": spot,
				"quality": quality,
				"frame_ms_median": wall[wall.size() / 2],
				"frame_ms_p95": wall[int(wall.size() * 0.95)],
				"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
				"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			}
			monitor._collect_scopes()
			var scopes: Dictionary = {}
			for key: StringName in monitor._scopes:
				scopes[String(key)] = snappedf(float(monitor._scopes[key]), 0.01)
			row["cpu_scopes_ms"] = scopes
			if _layers and quality == _qualities[0]:
				await monitor.measure_layers()
				row["layer_cost_ms"] = monitor._layer_cost.duplicate()
				row["layer_tris"] = monitor._layer_tris.duplicate()
			print("  %s %s: %.1f ms (p95 %.1f)" % [spot, quality, row["frame_ms_median"], row["frame_ms_p95"]])
			rows.append(row)
	var absolute := ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	file.store_string(JSON.stringify({"adapter": RenderingServer.get_video_adapter_name(), "shots": rows}, "  ") + "\n")
	file.close()
	quit(0)
