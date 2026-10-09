extends SceneTree

## Water sandbox plates (docs/SYSTEMS/WATER_SANDBOX.md, R-1498 / WR-0). Needs a renderer:
##   tools/godot_render.sh --script tools/water_sandbox/capture.gd -- \
##     [--case=sand,quay] [--shot=close,side,wide,swim,open] [--light=noon,sunset,night,overcast] \
##     [--wind=calm,fresh,gale] [--rain] [--gust] [--motion=N] [--advance=S]
##     [--tier=recommended] [--size=1280x720] [--tag=x]
## Every list argument is a comma list; the run covers the full cross product.
## Output: build/water_sandbox/<tag>/<case>_<shot>_<light>_<wind>[_rain][_gust].png plus
## sheet.png (all plates in one contact sheet). --motion=N writes N frames at 24 Hz per plate.

const SANDBOX_PATH := "res://tools/water_sandbox/water_sandbox.gd"
const OUTPUT_ROOT := "res://build/water_sandbox"
const WIND_DIRECTION := Vector2(0.25, 1.0)
const WINDS := {"calm": 0.1, "fresh": 0.55, "gale": 0.95}
const SHEET_COLUMNS := 4
const SHEET_THUMB := Vector2i(480, 270)

var _cases: Array = []
var _shots: Array = ["close", "side"]
var _lights: Array = ["noon"]
var _winds: Array = ["fresh"]
var _rain := false
var _gust := false
var _motion := 0
var _advance := 4.0
var _tier: StringName = &"recommended"
var _tag := "now"
var _size := Vector2i(1280, 720)


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var value := arg.get_slice("=", 1)
		if arg.begins_with("--case="):
			_cases = Array(value.split(","))
		elif arg.begins_with("--shot="):
			_shots = Array(value.split(","))
		elif arg.begins_with("--light="):
			_lights = Array(value.split(","))
		elif arg.begins_with("--wind="):
			_winds = Array(value.split(","))
		elif arg == "--rain":
			_rain = true
		elif arg == "--gust":
			_gust = true
		elif arg.begins_with("--motion="):
			_motion = int(value)
		elif arg.begins_with("--advance="):
			_advance = float(value)
		elif arg.begins_with("--tier="):
			_tier = StringName(value)
		elif arg.begins_with("--tag="):
			_tag = value
		elif arg.begins_with("--size="):
			_size = Vector2i(int(value.get_slice("x", 0)), int(value.get_slice("x", 1)))
	call_deferred("_run")


func _run() -> void:
	# A parse error in the builder would otherwise leave the window waiting forever.
	var builder: Script = load(SANDBOX_PATH)
	if builder == null or not builder.can_instantiate():
		push_error("water sandbox: builder script failed to compile")
		quit(2)
		return
	var out_dir := "%s/%s" % [OUTPUT_ROOT, _tag]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	MapViewMaterials.WATER_MATERIALS.set_ocean_fft_quality_tier(_tier)
	var viewport := SubViewport.new()
	viewport.size = _size
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var t0 := Time.get_ticks_msec()
	var sandbox: Node3D = builder.create()
	viewport.add_child(sandbox)
	var world: Node3D = sandbox.world
	var camera := Camera3D.new()
	camera.near = 0.05
	camera.far = 4000.0
	sandbox.add_child(camera)
	camera.current = true
	world.setup_lighting(camera)
	world.sky_weather.set_quality_tier(_tier)
	world.sky_weather.auto_weather = false
	world.sky_weather.set_process(false)
	var build_ms := Time.get_ticks_msec() - t0
	print("water sandbox: built in %d ms, %d cases" % [build_ms, sandbox.case_ids().size()])
	if _cases.is_empty():
		_cases = sandbox.case_ids()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var solar := SkyAstronomy.sunrise_sunset_hours(world.sky_weather.calendar_date)
	var lights := {
		"noon": [0.5, SkyWeather3D.WEATHER_CLEAR],
		"sunset": [(float(solar["sunset"]) - 0.4) / 24.0, SkyWeather3D.WEATHER_CLEAR],
		"night": [0.94, SkyWeather3D.WEATHER_CLEAR],
		"overcast": [0.5, SkyWeather3D.WEATHER_OVERCAST],
	}
	var plates: Array[String] = []
	for id: String in _cases:
		var poses: Dictionary = sandbox.shots_for(id)
		for shot: String in _shots:
			if not poses.has(shot):
				continue
			var pose: Array = poses[shot]
			for light: String in _lights:
				for wind_name: String in _winds:
					var name := "%s_%s_%s_%s%s%s" % [
						id, shot, light, wind_name, "_rain" if _rain else "", "_gust" if _gust else ""
					]
					camera.fov = pose[2]
					camera.look_at_from_position(pose[0], pose[1], Vector3.UP)
					var weather: StringName = lights[light][1]
					if _rain:
						weather = SkyWeather3D.WEATHER_RAIN
					world.sky_weather.set_weather(weather)
					world.sky_weather.advance(SkyWeather3D.TRANSITION_SECONDS + 0.1)
					_apply(world, float(lights[light][0]), float(WINDS[wind_name]), 0.0)
					MapViewRuntimeEnvironment.set_ocean_time(_advance)
					for i in 30:
						MapViewRuntimeEnvironment.advance_ocean_time(0.05)
						await process_frame
					await RenderingServer.frame_post_draw
					var path := "%s/%s.png" % [out_dir, name]
					viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
					plates.append(path)
					print("captured ", path)
					if _motion > 0:
						await _record(viewport, world, "%s/%s_motion" % [out_dir, name],
							float(lights[light][0]), float(WINDS[wind_name]))
	_contact_sheet(plates, "%s/sheet.png" % out_dir)
	quit(0)


## Light, sky and sea for one plate. `gust` (0..1) adds a short wind burst on top
## of the base wind so the sea's response to changing wind can be recorded.
func _apply(world: Node3D, progress: float, wind: float, gust: float) -> void:
	var strength := clampf(wind + gust * 0.4, 0.0, 1.0)
	var rain := 0.8 if _rain else 0.0
	MapViewLighting.apply_cycle_progress(
		progress, world.sun, world.environment, world.sky_weather, false
	)
	MapViewMaterials.apply_world_wind(WIND_DIRECTION, strength)
	MapViewMaterials.apply_sea_weather(strength, rain, WIND_DIRECTION)
	world.set_wind(WIND_DIRECTION)
	if world.spray != null:
		world.spray.set_wind(strength)
	var ground := CityTerrainBuilder.shared_material()
	if ground != null:
		ground.set_shader_parameter("rain_intensity", rain)
		ground.set_shader_parameter("wetness", rain * 0.6)


## 24 Hz frames. With --gust the wind follows a deterministic gust envelope:
## two bursts of different strength, each rising over ~1.5 s and dying away.
func _record(
	viewport: SubViewport, world: Node3D, dir: String, progress: float, wind: float
) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for i in _motion:
		var t := float(i) / 24.0
		if _gust:
			var burst := exp(-pow((t - 2.0) / 1.2, 2.0)) + 0.6 * exp(-pow((t - 6.0) / 0.8, 2.0))
			_apply(world, progress, wind, burst)
		MapViewRuntimeEnvironment.advance_ocean_time(1.0 / 24.0)
		await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(
			ProjectSettings.globalize_path("%s/%04d.png" % [dir, i])
		)


func _contact_sheet(paths: Array[String], out: String) -> void:
	if paths.is_empty():
		return
	var rows := int(ceil(float(paths.size()) / SHEET_COLUMNS))
	var columns := mini(paths.size(), SHEET_COLUMNS)
	var sheet := Image.create(SHEET_THUMB.x * columns, SHEET_THUMB.y * rows, false, Image.FORMAT_RGB8)
	for i in paths.size():
		var image := Image.load_from_file(ProjectSettings.globalize_path(paths[i]))
		image.convert(Image.FORMAT_RGB8)
		image.resize(SHEET_THUMB.x, SHEET_THUMB.y, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, SHEET_THUMB),
			Vector2i(i % SHEET_COLUMNS, i / SHEET_COLUMNS) * SHEET_THUMB)
	sheet.save_png(ProjectSettings.globalize_path(out))
	print("contact sheet ", out)
