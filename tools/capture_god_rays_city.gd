extends SceneTree

## R-1444 review plates for crepuscular rays over the seamless city: a street-level
## lens toward a low morning sun behind broken cloud, an aerial lens over the town and
## sea toward a low sun (shafts falling onto the land), a dawn lens with the sun just
## over the horizon, and a clear-noon control that must stay clean. Needs a renderer:
##   tools/godot_render.sh --script tools/capture_god_rays_city.gd [-- --tag=after]
##     [--only=<shot>[,<shot>...]] [--out=res://build/god_rays_city]
## Output: <out>/godrays_<shot>_<tag>.png

const VIEWPORT_SIZE := Vector2i(1280, 720)
const STREET := Vector2(-60, -200)

var _only := ""
var _tag := "after"
var _out := "res://docs/reports/images/weather"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			_only = arg.substr(7)
		elif arg.begins_with("--tag="):
			_tag = arg.substr(6)
		elif arg.begins_with("--out="):
			_out = arg.substr(6)
	call_deferred("_run")


func _wanted(shot: String) -> bool:
	return _only.is_empty() or shot in _only.split(",")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var plan := CityPlan.load_default()
	# WHY root, not a SubViewport: the god-ray and shadow passes composite over the
	# live framebuffer, which is only the real play path in the root window.
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	var view := CityMapView.create_city(plan)
	root.add_child(view)
	var camera: Camera3D = view.camera_3d() if view.has_method("camera_3d") else view._camera
	var sky: SkyWeather3D = view._sky_weather
	sky.auto_weather = false
	sky.time_scale = 0.0
	var open := _open_spot(view, plan)
	var street := Vector3(open.x, plan.walk_height(open) + 1.7, open.y)
	print("street eye %s" % street)

	if _wanted("street_morning"):
		var progress := _progress_for_elevation(sky, 0.22, true)
		await _settle(view, sky, SkyWeather3D.WEATHER_CLOUDY, progress)
		var sun := SkyWeather3D.solar_direction(progress, sky.calendar_date)
		await _shot(camera, "street_morning", street, _aim_below(street, sun, 0.12), 75.0)
	if _wanted("aerial_lowsun"):
		var progress := _progress_for_elevation(sky, 0.16, true)
		await _settle(view, sky, SkyWeather3D.WEATHER_CLOUDY, progress)
		await _sun_behind_cloud_edge(view, sky, progress)
		var sun := SkyWeather3D.solar_direction(progress, sky.calendar_date)
		var flat := Vector3(sun.x, 0.0, sun.z).normalized()
		var eye := Vector3(STREET.x, 140.0, STREET.y) - flat * 400.0
		await _shot(camera, "aerial_lowsun", eye, _aim_below(eye, sun, 0.32), 70.0)
	if _wanted("dawn"):
		var progress := _progress_for_elevation(sky, 0.035, true)
		await _settle(view, sky, SkyWeather3D.WEATHER_CLOUDY, progress)
		await _sun_behind_cloud_edge(view, sky, progress)
		var sun := SkyWeather3D.solar_direction(progress, sky.calendar_date)
		var eye := street + Vector3(0.0, 28.0, 0.0)
		await _shot(camera, "dawn", eye, _aim_below(eye, sun, -0.12), 80.0)
	if _wanted("noon_clear"):
		var progress := 0.5
		await _settle(view, sky, SkyWeather3D.WEATHER_CLEAR, progress)
		var sun := SkyWeather3D.solar_direction(progress, sky.calendar_date)
		await _shot(camera, "noon_clear", street, _aim_below(street, sun, 0.35), 75.0)
	if OS.get_cmdline_user_args().has("--bench"):
		await _bench(view, sky, camera, street)
	quit(0)


## Frame time with the god-ray overlay on and off on the street-morning pose, sky beams
## included in both (they live in the dome shader). Vsync off; 200 frames per state.
func _bench(view: CityMapView, sky: SkyWeather3D, camera: Camera3D, street: Vector3) -> void:
	var progress := _progress_for_elevation(sky, 0.22, true)
	await _settle(view, sky, SkyWeather3D.WEATHER_CLOUDY, progress)
	var sun := SkyWeather3D.solar_direction(progress, sky.calendar_date)
	camera.look_at_from_position(street, _aim_below(street, sun, 0.12), Vector3.UP)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var overlay := view._god_ray_pass.get_node("GodRayOverlay") as MeshInstance3D
	for state: String in ["on", "off", "on", "off"]:
		for _frame in 30:
			await process_frame
			if state == "off":
				overlay.visible = false
		var start := Time.get_ticks_usec()
		for _frame in 200:
			await process_frame
			if state == "off":
				overlay.visible = false
		print("GODRAY bench %s %.2f ms/frame" % [state, (Time.get_ticks_usec() - start) / 200000.0])


## Nearest dry point to STREET with no building within CLEARANCE, so a street-level
## lens has open air around it instead of a wall filling the frame.
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


## Walk the deterministic cloud clock until the sun sits behind a cloud edge (partly
## hidden), the moment crepuscular rays fan out from the gaps around it.
func _sun_behind_cloud_edge(view: CityMapView, sky: SkyWeather3D, progress: float) -> void:
	var blend := SkyWeather3D.daylight_blend(progress, sky.calendar_date)
	for step in 240:
		var clear := sky.presentation_snapshot(progress, blend).sun_cloud_clear
		if clear > 0.15 and clear < 0.5:
			print("sun behind cloud edge after %d steps, clear %.2f" % [step, clear])
			break
		sky.advance(5.0)
	view.apply_cycle_progress(progress)
	for i in 3:
		await process_frame


## Morning (or evening) clock where the sun stands `elevation` (sin) over the horizon.
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


## Look point toward the sun's bearing, tilted `drop` (radians-ish, as y slope) below it
## so the sun sits in the upper part of the frame with the ground below it.
func _aim_below(eye: Vector3, sun: Vector3, drop: float) -> Vector3:
	var flat := Vector3(sun.x, 0.0, sun.z).normalized()
	var slope := sun.y / maxf(Vector2(sun.x, sun.z).length(), 0.01) - drop
	return eye + (flat + Vector3(0.0, slope, 0.0)) * 100.0


func _settle(view: CityMapView, sky: SkyWeather3D, weather: StringName, progress: float) -> void:
	sky.set_weather(weather)
	sky.advance(SkyWeather3D.TRANSITION_SECONDS + 0.1)
	sky.advance(17.0)
	view.apply_cycle_progress(progress)
	for i in 3:
		await process_frame


func _shot(camera: Camera3D, shot: String, eye: Vector3, look: Vector3, fov: float) -> void:
	camera.fov = fov
	camera.far = 9000.0
	camera.near = 0.08 if eye.y < 120.0 else 1.0
	camera.look_at_from_position(eye, look, Vector3.UP)
	for i in 8:
		await process_frame
	var path := "%s/godrays_%s_%s.png" % [_out, shot, _tag]
	var image := root.get_texture().get_image()
	# HiDPI windows render above the requested size; evidence plates are 1280x720.
	if image.get_size() != VIEWPORT_SIZE:
		image.resize(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	image.save_png(ProjectSettings.globalize_path(path))
	print("captured %s" % path)
