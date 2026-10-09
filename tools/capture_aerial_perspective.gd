extends SceneTree

## R-1482 review plates for aerial perspective over the seamless city: a long view across
## the town from a raised eye at clear April noon, evening low sun and rain, a hot June
## midday (heat shimmer), and street- and first-person-height lenses. Needs a renderer:
##   tools/godot_render.sh --script tools/capture_aerial_perspective.gd [-- --tag=after]
##     [--only=<shot>[,<shot>...]] [--no-pass] [--debug=1|2|3] [--bench] [--out=res://build/aerial]
## --no-pass hides the pass (before plates); --debug shows 1 haze, 2 blur, 3 the raw
## screen copy (must match --no-pass if the screen texture is reliable).
## Output: <out>/aerial_<shot>_<tag>.png

const VIEWPORT_SIZE := Vector2i(1280, 720)
const STREET := Vector2(-60, -200)
const HOT_DATE := {"day": 24, "month": 6, "year": 1343}

var _only := ""
var _tag := "after"
var _out := "res://docs/reports/images/weather"
var _no_pass := false
var _debug := 0
var _progress := 0.5


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			_only = arg.substr(7)
		elif arg.begins_with("--tag="):
			_tag = arg.substr(6)
		elif arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--debug="):
			_debug = int(arg.substr(8))
		elif arg == "--no-pass":
			_no_pass = true
	# Pin shader TIME so shimmer plates are comparable between runs (playbook).
	ProjectSettings.set_setting("rendering/limits/time/time_rollover_secs", 0.000001)
	call_deferred("_run")


func _wanted(shot: String) -> bool:
	return _only.is_empty() or shot in _only.split(",")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var plan := CityPlan.load_default()
	# WHY root, not a SubViewport: screen passes composite over the live framebuffer,
	# which is only the real play path in the root window.
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	var view := CityMapView.create_city(plan)
	root.add_child(view)
	var camera: Camera3D = view.camera_3d() if view.has_method("camera_3d") else view._camera
	var sky: SkyWeather3D = view._sky_weather
	sky.auto_weather = false
	sky.time_scale = 0.0
	var aerial: AerialPerspectivePass = view._local_atmosphere.aerial
	aerial.set_debug_mode(_debug)
	aerial.suppressed = _no_pass
	var open := _open_spot(view, plan)
	var street := Vector3(open.x, plan.walk_height(open) + 1.7, open.y)
	var raised := street + Vector3(0.0, 34.0, 0.0)
	# Long axis of the view: from the street toward the town centre and the far shore.
	var heading := Vector3(1.0, 0.0, 0.35).normalized()
	print("street eye %s" % street)

	if _wanted("long_noon"):
		await _settle(view, sky, SkyWeather3D.WEATHER_CLEAR, 0.5)
		await _shot(view, camera, "long_noon", raised, raised + heading * 100.0 + Vector3(0, -9, 0), 70.0)
	if _wanted("long_evening"):
		var progress := _progress_for_elevation(sky, 0.12, false)
		await _settle(view, sky, SkyWeather3D.WEATHER_CLEAR, progress)
		var sun := SkyWeather3D.solar_direction(progress, sky.calendar_date)
		var flat := Vector3(sun.x, 0.0, sun.z).normalized()
		await _shot(view, camera, "long_evening", raised, raised + flat * 100.0 + Vector3(0, -9, 0), 70.0)
	if _wanted("hot_june"):
		sky.calendar_date = HOT_DATE.duplicate()
		await _settle(view, sky, SkyWeather3D.WEATHER_CLEAR, 0.52)
		await _shot(view, camera, "hot_june", raised, raised + heading * 100.0 + Vector3(0, -4, 0), 60.0)
		sky.calendar_date = GameCalendar.DEFAULT_DATE.duplicate()
	if _wanted("street_noon"):
		await _settle(view, sky, SkyWeather3D.WEATHER_CLEAR, 0.5)
		var look := street + heading * 100.0 + Vector3(0, -2, 0)
		await _shot(view, camera, "street_noon", street, look, 75.0)
	if _wanted("first_person"):
		await _settle(view, sky, SkyWeather3D.WEATHER_CLEAR, 0.45)
		var eye := street + Vector3(0.0, -0.1, 0.0)
		await _shot(view, camera, "first_person", eye, eye - heading * 100.0 + Vector3(0, -3, 0), 75.0)
	if OS.get_cmdline_user_args().has("--bench"):
		await _bench(view, sky, camera, aerial, raised, heading)
	# Rain last: its puddles keep damping heat and haze in any later shot.
	if _wanted("long_rain"):
		await _settle(view, sky, SkyWeather3D.WEATHER_RAIN, 0.5)
		await _shot(view, camera, "long_rain", raised, raised + heading * 100.0 + Vector3(0, -9, 0), 70.0)
	quit(0)


## Frame time with the pass on and off on the long noon view. Vsync off, 200 frames each.
func _bench(
	view: CityMapView, sky: SkyWeather3D, camera: Camera3D, aerial: AerialPerspectivePass,
	eye: Vector3, heading: Vector3
) -> void:
	await _settle(view, sky, SkyWeather3D.WEATHER_CLEAR, 0.5)
	camera.look_at_from_position(eye, eye + heading * 100.0 + Vector3(0, -9, 0), Vector3.UP)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for state: String in ["on", "off", "on", "off"]:
		aerial.suppressed = state == "off"
		for _frame in 30:
			await process_frame
		var start := Time.get_ticks_usec()
		for _frame in 200:
			await process_frame
		print("AERIAL bench %s %.2f ms/frame" % [state, (Time.get_ticks_usec() - start) / 200000.0])
	aerial.suppressed = _no_pass


## Nearest dry point to STREET with no building within CLEARANCE.
func _open_spot(view: CityMapView, plan: CityPlan) -> Vector2:
	const CLEARANCE := 12.0
	var best := STREET
	var best_d := INF
	for j in range(-50, 51):
		for i in range(-50, 51):
			var p := STREET + Vector2(i, j) * 6.0
			var d := p.distance_to(STREET)
			if d >= best_d or plan.ground_height(p) < 0.5:
				continue
			var clear := true
			for box: AABB in view._occluder_bounds:
				var near := Vector2(
					clampf(p.x, box.position.x, box.end.x), clampf(p.y, box.position.z, box.end.z)
				)
				if near.distance_to(p) < CLEARANCE:
					clear = false
					break
			if clear:
				best = p
				best_d = d
	return best


func _progress_for_elevation(sky: SkyWeather3D, elevation: float, morning: bool) -> float:
	var best := 0.3
	var best_error := INF
	var from := 150 if morning else 500
	var to := 500 if morning else 900
	for step in range(from, to):
		var progress := float(step) / 1000.0
		var error := absf(SkyWeather3D.solar_direction(progress, sky.calendar_date).y - elevation)
		if error < best_error:
			best_error = error
			best = progress
	return best


func _settle(view: CityMapView, sky: SkyWeather3D, weather: StringName, progress: float) -> void:
	sky.set_weather(weather)
	sky.advance(SkyWeather3D.TRANSITION_SECONDS + 0.1)
	sky.advance(17.0)
	_progress = progress
	view.apply_cycle_progress(progress)
	for i in 3:
		await process_frame


func _shot(
	view: CityMapView, camera: Camera3D, shot: String, eye: Vector3, look: Vector3, fov: float
) -> void:
	camera.fov = fov
	camera.far = 9000.0
	camera.near = 0.08
	camera.look_at_from_position(eye, look, Vector3.UP)
	for i in 8:
		await process_frame
	var aerial: AerialPerspectivePass = view._local_atmosphere.aerial
	var p := view._sky_weather.presentation_snapshot(_progress, 1.0)
	print("  sun_y %.2f vis %.2f cloud_clear %.2f coverage %.2f wind %.2f puddles %.2f" % [
		p.sun_direction.y, p.sun_visibility, p.sun_cloud_clear, p.cloud_coverage,
		p.wind_strength, p.puddle_wetness
	])
	print("%s: density %.5f blur %.2f shimmer %.2f visible %s" % [
		shot, aerial.haze_density, aerial.blur_pixels, aerial.shimmer_pixels,
		aerial.overlay_visible()
	])
	var path := "%s/aerial_%s_%s.png" % [_out, shot, _tag]
	var image := root.get_texture().get_image()
	if image.get_size() != VIEWPORT_SIZE:
		image.resize(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	image.save_png(ProjectSettings.globalize_path(path))
	print("captured %s" % path)
