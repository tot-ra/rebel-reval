extends SceneTree

## Sky reference plates (R-1766): a low wide camera over the city looking across the sun
## at fixed times and weathers, so sky exposure and cloud shading can be compared before
## and after a lighting change. Promoted from the build/witcher_sky_probe.gd scratch probe.
##   tools/godot_render.sh --script tools/capture_sky_reference.gd
##   tools/godot_render.sh --script tools/capture_sky_reference.gd -- --out=res://build/sky_before
##   tools/godot_render.sh --script tools/capture_sky_reference.gd -- --only=noon_side_clear
## Output: docs/reports/images/weather/sky_reference_<shot>.png (or <out>/sky_reference_<shot>.png)

const DEFAULT_OUT := "res://docs/reports/images/weather"
const SIZE := Vector2i(1280, 720)
# [name, weather, cycle progress, yaw offset from sun (deg), pitch (deg), fov]
const SHOTS := [
	["noon_side_clear", SkyWeather3D.WEATHER_CLEAR, 0.42, 70.0, 14.0, 80.0],
	["aft_side_cloudy", SkyWeather3D.WEATHER_CLOUDY, 0.71, 60.0, 18.0, 85.0],
	["gold_side_cloudy", SkyWeather3D.WEATHER_CLOUDY, 0.80, 70.0, 14.0, 80.0],
	# R-1767 golden-hour series: sun roughly 22 / 14 / 8 deg high, same side-on framing.
	["gold_070_cloudy", SkyWeather3D.WEATHER_CLOUDY, 0.70, 70.0, 14.0, 80.0],
	["gold_074_cloudy", SkyWeather3D.WEATHER_CLOUDY, 0.74, 70.0, 14.0, 80.0],
	["gold_077_cloudy", SkyWeather3D.WEATHER_CLOUDY, 0.77, 70.0, 14.0, 80.0],
]

var _out := DEFAULT_OUT
var _only := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			_only = arg.substr(7)
		elif arg.begins_with("--out="):
			_out = arg.substr(6)
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var plan := CityPlan.load_default()
	DisplayServer.window_set_size(SIZE)
	var view := CityMapView.create_city(plan)
	root.add_child(view)
	var camera: Camera3D = view.camera_3d() if view.has_method("camera_3d") else view._camera
	var sky: SkyWeather3D = view._sky_weather
	sky.auto_weather = false
	sky.time_scale = 0.0
	# Open ground south-west of the old town, 35 m up so roofs do not fill the frame.
	var ground := Vector2(-60, -200)
	var eye := Vector3(ground.x, plan.walk_height(ground) + 35.0, ground.y)
	for s in SHOTS:
		if not _only.is_empty() and not (s[0] in _only.split(",")):
			continue
		sky.set_weather(s[1])
		sky.advance(SkyWeather3D.TRANSITION_SECONDS + 0.1)
		sky.advance(17.0)
		view.apply_cycle_progress(s[2])
		var sun := SkyWeather3D.solar_direction(s[2], sky.calendar_date)
		var yaw := atan2(sun.x, sun.z) + deg_to_rad(s[3])
		var pitch := deg_to_rad(s[4])
		var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
		camera.fov = s[5]
		camera.far = 9000.0
		camera.near = 0.1
		camera.look_at_from_position(eye, eye + dir * 100.0, Vector3.UP)
		# Several frames so the sky radiance cubemap and screen passes settle.
		for i in 8:
			await process_frame
		var image := root.get_texture().get_image()
		if image.get_size() != SIZE:
			image.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
		var path := ProjectSettings.globalize_path("%s/sky_reference_%s.png" % [_out, s[0]])
		image.save_png(path)
		print("captured %s sun=%s" % [path, sun])
	quit()
