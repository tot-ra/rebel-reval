extends SceneTree

## Review plates for regional sites (ADR 0042, docs/SYSTEMS/REGIONAL_SITES.md):
## the site plan built by the shared city view under its own sky, by day, at
## night and in rain, plus one Reval plate through the same path to show the
## city keeps its sea.
##   tools/godot_render.sh --script tools/capture_regional_sites.gd [-- --only=<shot>[,<shot>]]
## Output: docs/reports/images/sites/<shot>.png (1280x720)

const OUTPUT_DIR := "res://docs/reports/images/sites"
const VIEWPORT_SIZE := Vector2i(1280, 720)
## Cycle progress: 0.5 is local noon.
const DAY := 0.44
const NIGHT := 0.96

## [shot, site, weather, progress, eye, look, fov]
const SHOTS := [
	["paide_day_castle", "paide", &"clear", DAY, Vector3(-150, 70, 150), Vector3(0, 16, -6), 50.0],
	["paide_day_keep_from_town", "paide", &"clear", DAY, Vector3(-112, 12.4, 158), Vector3(-6, 22, -4), 58.0],
	["paide_day_aerial", "paide", &"cloudy", DAY, Vector3(260, 260, 360), Vector3(-40, 0, 20), 55.0],
	["paide_night_castle", "paide", &"clear", NIGHT, Vector3(-150, 70, 150), Vector3(0, 16, -6), 50.0],
	["paide_rain_castle", "paide", &"rain", DAY, Vector3(-112, 12.4, 158), Vector3(-6, 22, -4), 58.0],
	["reval_day_aerial", "reval_city", &"clear", DAY, Vector3(700, 380, -900), Vector3(-80, 20, -150), 50.0],
]

var _only := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			_only = arg.substr(7)
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	var current_site := ""
	var view: CityMapView
	for shot: Array in SHOTS:
		if not _only.is_empty() and not String(shot[0]) in _only.split(","):
			continue
		if shot[1] != current_site:
			if view != null:
				view.queue_free()
				await process_frame
			current_site = shot[1]
			var plan := CityPlan.load_site(current_site)
			# As site_level.gd does: the sky is computed for the site's own origin.
			SkyAstronomy.set_observer(plan.origin_latitude(), plan.origin_longitude())
			view = CityMapView.create_city(plan)
			root.add_child(view)
		var sky: SkyWeather3D = view._sky_weather
		sky.auto_weather = false
		sky.time_scale = 0.0
		sky.set_weather(shot[2])
		sky.advance(SkyWeather3D.TRANSITION_SECONDS + 0.1)
		sky.advance(17.0)
		view.apply_cycle_progress(shot[3])
		await _shot(view._camera, shot[0], shot[4], shot[5], shot[6])
	SkyAstronomy.reset_observer()
	quit(0)


func _shot(camera: Camera3D, shot: String, eye: Vector3, look: Vector3, fov: float) -> void:
	camera.fov = fov
	camera.far = 9000.0
	camera.near = 0.08 if eye.y < 120.0 else 1.0
	camera.look_at_from_position(eye, look, Vector3.UP)
	for i in 8:
		await process_frame
	var image := root.get_texture().get_image()
	if image.get_size() != VIEWPORT_SIZE:
		image.resize(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	var path := "%s/%s.png" % [OUTPUT_DIR, shot]
	image.save_png(ProjectSettings.globalize_path(path))
	print("captured %s" % path)
