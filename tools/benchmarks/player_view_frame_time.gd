extends SceneTree
## Frame time from the player's own cameras on the continuous city: first person
## (eye 1.65 m, pitch -10, fov 75), third person (behind the character, pitch -12,
## fov 65), looking at the sky, and the same at the quay and the beach, per weather.
## The numbers mirror scripts/map/view3d/map_view_runtime_camera_modes.gd.
##   tools/godot_render.sh --resolution 1920x1080 --disable-vsync \
##     --script res://tools/benchmarks/player_view_frame_time.gd -- \
##     --output=res://build/benchmarks/player_views.json [--tier=minimum|recommended] [--frames=60]
## Wall frame time, vsync off (the minimized window reports no GPU timer).

const GraphicsPresetsScript := preload("res://scripts/settings/graphics_presets.gd")
const GraphicsSettingsScript := preload("res://scripts/settings/graphics_settings.gd")
const FIRST_EYE := 1.65
const FIRST_PITCH := -10.0
const FIRST_FOV := 75.0
const THIRD_BACK := 3.2
const THIRD_TARGET := 1.15
const THIRD_PITCH := -12.0
const THIRD_FOV := 65.0
const WARMUP_FRAMES := 30
const WEATHERS := {
	"clear": [SkyWeather3D.WEATHER_CLEAR, 0.1, 0.0],
	"rain": [SkyWeather3D.WEATHER_RAIN, 0.6, 0.8],
	"storm": [SkyWeather3D.WEATHER_STORM, 0.95, 0.6],
}
const TIMES := {"day": 0.42, "night": 0.0}

var _frames := 60
var _tier: StringName = &"recommended"
## Attribution switches (one cost source per run), like tools/benchmarks/render_probe.gd.
var _quality := ""
## --interleave=high,mid,low --rounds=3: apply each quality live at every shot, repeat, and
## keep the best median per quality. Other renders on the machine hit all of them equally.
var _interleave: PackedStringArray = []
var _rounds := 3
var _scale := 1.0
var _msaa := -1
var _no_sun_shadows := false
var _only: PackedStringArray = []
var _hide: PackedStringArray = []
## "view,shadow,far" ray-march steps for the god-ray pass (empty = shader defaults).
var _godray_steps: PackedStringArray = []
var _png_dir := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var output := "res://build/benchmarks/player_views.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		elif arg.begins_with("--frames="):
			_frames = int(arg.trim_prefix("--frames="))
		elif arg.begins_with("--tier="):
			_tier = StringName(arg.trim_prefix("--tier="))
		elif arg.begins_with("--interleave="):
			_interleave = arg.trim_prefix("--interleave=").split(",")
		elif arg.begins_with("--rounds="):
			_rounds = int(arg.trim_prefix("--rounds="))
		elif arg.begins_with("--quality="):
			_quality = arg.trim_prefix("--quality=")
		elif arg.begins_with("--scale="):
			_scale = float(arg.trim_prefix("--scale="))
		elif arg.begins_with("--msaa="):
			_msaa = int(arg.trim_prefix("--msaa="))
		elif arg == "--no-sun-shadows":
			_no_sun_shadows = true
		elif arg.begins_with("--godray-steps="):
			_godray_steps = arg.trim_prefix("--godray-steps=").split(",")
		elif arg.begins_with("--png-dir="):
			_png_dir = arg.trim_prefix("--png-dir=")
		elif arg.begins_with("--hide="):
			_hide = arg.trim_prefix("--hide=").split(",")
		elif arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=").split(",")
	if not _quality.is_empty():
		# The player's own setting: render scale, shadows, sky tier and god-ray steps.
		var settings := GraphicsSettingsScript.default_settings()
		settings.quality = _quality
		root.get_node("UserSettings").apply_graphics_settings(settings, false)
		_tier = GraphicsPresetsScript.row(_quality)["sky_tier"]
	var plan := CityPlan.load_default()
	var view := CityMapView.create_city(plan, _tier)
	root.add_child(view)
	var world := view.world
	var camera := view.view_camera()
	camera.far = 4000.0
	camera.near = 0.05
	camera.current = true
	world.sky_weather.set_quality_tier(_tier)
	if _scale != 1.0:
		root.scaling_3d_scale = _scale
	if _msaa >= 0:
		root.msaa_3d = _msaa as Viewport.MSAA
	if _no_sun_shadows:
		world.sun.shadow_enabled = false
	if _godray_steps.size() == 3 and view._god_ray_pass != null:
		var material: ShaderMaterial = view._god_ray_pass._material
		material.set_shader_parameter(&"view_steps", int(_godray_steps[0]))
		material.set_shader_parameter(&"shadow_steps", int(_godray_steps[1]))
		material.set_shader_parameter(&"far_steps", int(_godray_steps[2]))
	# --hide=godrays,cloudshadow,atmosphere,water,fauna
	var hideable := {
		"godrays": view._god_ray_pass, "cloudshadow": view._cloud_shadow_pass,
		"atmosphere": view._local_atmosphere, "water": world.get_node_or_null("Water"),
	}
	for key: String in _hide:
		var node: Node3D = hideable.get(key)
		if node != null:
			node.visible = false
		else:
			push_warning("player_view: nothing to hide for %s" % key)
	world.sky_weather.auto_weather = false
	var crane: Array = plan.data["harbour"]["crane"]["at"]
	var quay := Vector2(crane[0], crane[1])
	var forum_polygon: Array = plan.data["forum"]["polygon"]
	var forum := Vector2.ZERO
	for p: Array in forum_polygon:
		forum += Vector2(p[0], p[1])
	forum /= forum_polygon.size()
	var beach := quay - Vector2(60.0, -8.0)
	# (name, ground point, heading in degrees, mode, pitch override)
	var spots: Array[Dictionary] = [
		{"name": "forum_first", "at": forum, "heading": 0.0, "mode": "first"},
		{"name": "forum_third", "at": forum, "heading": 0.0, "mode": "third"},
		{"name": "forum_sky", "at": forum, "heading": 0.0, "mode": "first", "pitch": 55.0},
		{"name": "quay_first_sea", "at": quay, "heading": 0.0, "mode": "first"},
		{"name": "quay_third_sea", "at": quay, "heading": 0.0, "mode": "third"},
		{"name": "quay_sky", "at": quay, "heading": 0.0, "mode": "first", "pitch": 55.0},
		{"name": "beach_first_sea", "at": beach, "heading": 90.0, "mode": "first"},
		{"name": "beach_third_sea", "at": beach, "heading": 90.0, "mode": "third"},
	]
	var rows: Array[Dictionary] = []
	# Pass 0 only visits every shot so shaders, cloud LUTs and streamed chunks are warm;
	# pass 1 records. Without it the first weather group measures compilation.
	for pass_index in 2:
		for weather_name: String in WEATHERS:
			var w: Array = WEATHERS[weather_name]
			world.sky_weather.set_weather(w[0])
			world.sky_weather.advance(SkyWeather3D.TRANSITION_SECONDS + 0.1)
			MapViewMaterials.apply_sea_weather(w[1], w[2], Vector2(0.4, -0.9))
			MapViewMaterials.apply_world_wind(Vector2(0.4, -0.9), w[1])
			world.set_wind(Vector2(0.4, -0.9))
			for time_name: String in TIMES:
				view.apply_cycle_progress(TIMES[time_name])
				for spot: Dictionary in spots:
					var label := "%s/%s/%s" % [spot["name"], weather_name, time_name]
					if not _only.is_empty() and not label in _only:
						continue
					_place(camera, plan, spot)
					if pass_index == 0:
						for _frame in 6:
							await process_frame
					elif _interleave.is_empty():
						rows.append(await _measure(label))
					else:
						rows.append_array(await _measure_interleaved(label, world))
	var absolute := ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var report := {
		"tier": _tier,
		"quality": _quality,
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"video_adapter": RenderingServer.get_video_adapter_name(),
		"render_size": root.get_visible_rect().size,
		"frames": _frames,
		"shots": rows,
	}
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("Player views (%s): %d shots -> %s" % [_tier, rows.size(), output])
	quit(0)


func _place(camera: Camera3D, plan: CityPlan, spot: Dictionary) -> void:
	var at: Vector2 = spot["at"]
	var ground := maxf(plan.ground_height(at), 0.0)
	var heading := deg_to_rad(float(spot["heading"]))
	var forward := Vector3(sin(heading), 0.0, -cos(heading))
	var third: bool = spot["mode"] == "third"
	var pitch := deg_to_rad(float(spot.get("pitch", THIRD_PITCH if third else FIRST_PITCH)))
	camera.fov = THIRD_FOV if third else FIRST_FOV
	var base := Vector3(at.x, ground, at.y)
	var eye := base + Vector3.UP * FIRST_EYE
	if third:
		eye = base + Vector3.UP * THIRD_TARGET - forward * THIRD_BACK + Vector3.UP * 0.9
	camera.global_position = eye
	camera.look_at(eye + forward * cos(pitch) + Vector3.UP * sin(pitch), Vector3.UP)


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
		"draw_calls": RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
	}
	if not _png_dir.is_empty():
		var dir := ProjectSettings.globalize_path(_png_dir)
		DirAccess.make_dir_recursive_absolute(dir)
		root.get_texture().get_image().save_png("%s/%s.png" % [dir, label.replace("/", "_")])
	print("  %s: %.2f ms (p95 %.2f), %d draws" % [
			label, row["frame_ms_median"], row["frame_ms_p95"], row["draw_calls"]])
	return row


## One row per quality for this shot: the lowest of `_rounds` medians.
func _measure_interleaved(label: String, world: CityWorld3D) -> Array[Dictionary]:
	var best: Dictionary = {}
	for _round in _rounds:
		for quality: String in _interleave:
			var settings := GraphicsSettingsScript.default_settings()
			settings.quality = quality
			root.get_node("UserSettings").apply_graphics_settings(settings, false)
			world.sky_weather.set_quality_tier(GraphicsPresetsScript.row(quality)["sky_tier"])
			var row := await _measure("%s|%s" % [label, quality])
			if not best.has(quality) or row["frame_ms_median"] < best[quality]["frame_ms_median"]:
				best[quality] = row
	var rows: Array[Dictionary] = []
	for quality: String in _interleave:
		best[quality]["quality"] = quality
		rows.append(best[quality])
	return rows
