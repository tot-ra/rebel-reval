extends SceneTree

## Review plates for the Padise regional site (docs/SYSTEMS/REGIONAL_SITES.md):
## the 1343 monastery, the mill and the frame from the air under the site's own
## sky, by day, at night and in rain. Same view path as
## tools/capture_regional_sites.gd, kept separate so parallel site tasks do not
## edit one shot list.
##   tools/godot_render.sh --script tools/capture_padise_site.gd [-- --only=<shot>[,<shot>]]
## Output: docs/reports/images/sites/<shot>.png (1280x720)

const OUTPUT_DIR := "res://docs/reports/images/sites"
const VIEWPORT_SIZE := Vector2i(1280, 720)
## Cycle progress: 0.5 is local noon.
const DAY := 0.44
const NIGHT := 0.96

## [shot, weather, progress, eye, look, fov]
const SHOTS := [
	["padise_day_monastery", &"clear", DAY, Vector3(-120, 44, 96), Vector3(8, 10, -2), 50.0],
	["padise_day_close", &"clear", DAY, Vector3(-10, 9.6, -40), Vector3(8, 9.4, 4), 62.0],
	["padise_day_mill", &"clear", DAY, Vector3(96, 20, 290), Vector3(30, 9.5, 222), 55.0],
	["padise_day_aerial", &"clear", DAY, Vector3(150, 105, 190), Vector3(-10, 4, 0), 58.0],
	["padise_night_monastery", &"clear", NIGHT, Vector3(-120, 44, 96), Vector3(8, 10, -2), 50.0],
	["padise_rain_monastery", &"rain", DAY, Vector3(-46, 13, 74), Vector3(8, 9.8, -4), 58.0],
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
	var plan := CityPlan.load_site("padise")
	# As site_level.gd does: the sky is computed for the site's own origin.
	SkyAstronomy.set_observer(plan.origin_latitude(), plan.origin_longitude())
	var view := CityMapView.create_city(plan)
	root.add_child(view)
	for shot: Array in SHOTS:
		if not _only.is_empty() and not String(shot[0]) in _only.split(","):
			continue
		var sky: SkyWeather3D = view._sky_weather
		sky.auto_weather = false
		sky.time_scale = 0.0
		sky.set_weather(shot[1])
		sky.advance(SkyWeather3D.TRANSITION_SECONDS + 0.1)
		sky.advance(17.0)
		view.apply_cycle_progress(shot[2])
		await _shot(view._camera, shot[0], shot[3], shot[4], shot[5])
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
