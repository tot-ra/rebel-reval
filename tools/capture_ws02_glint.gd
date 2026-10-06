extends SceneTree

## WS-02 sun/moon glint evidence on the harbour sea. One plate per process; needs a real
## renderer, so run it through the minimized-window wrapper:
##   tools/godot_render.sh --rendering-method mobile --rendering-driver metal \
##     --script tools/capture_ws02_glint.gd -- --scenario=clear --progress=0.5 --label=noon
## Compatibility: replace the renderer flags with --rendering-driver opengl3.
##
## Options:
##   --scenario=clear|overcast|storm   weather preset
##   --progress=<0..1>        day-cycle progress (0 midnight, 0.5 noon), set through
##                            MapView3D.apply_cycle_progress like the game clock
##   --date=<day>-<month>     calendar date in 1343 (default 21-6); a moon-path night needs a
##                            bright moon low in the camera's reflected direction, e.g. 6-4
##   --label=<name>           plate name suffix (noon, sunset, night, ...)
##   --focus=harbour|quay     open harbour basin, or the quay wall whose shadow falls on water
##   --strobe                 render 120 frames of the normal-speed day cycle (60 s per day)
##                            and print the mean frame-to-frame water luminance change
##   --no-mist                disable the pre-dawn ground mist so a moon path can be judged
##                            (the plate name gets _nomist). It hides only the Environment
##                            fog: the glints keep MapViewLighting.glint_haze_transmittance,
##                            so pick a low-fog date for an unveiled moon path
##   --set=name:value         water-material uniform override for tuning
## The FFT sea is forced on, as the WS-04 and WS-06 plates did.
## Writes docs/reports/images/ws02_<renderer>_<scenario>_<label>_<focus>.png

const MapAuditRegistry := preload("res://scripts/map/map_audit_registry.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")
const SkyWeather3D := preload("res://scripts/map/view3d/sky_weather_3d.gd")

const OUTPUT_DIR := "res://docs/reports/images"
const PLATE_SIZE := Vector2i(1280, 720)
const WARMUP_FRAMES := 90
const MAP_ID := "reval_harbor_north"
const FOCUS := {
	&"harbour": Vector2(80.5, 24.5),
	&"quay": Vector2(70.0, 30.0),
}
const ORTHO_SIZE := 28.0
const WEATHER := {
	&"clear": SkyWeather3D.WEATHER_CLEAR,
	&"overcast": SkyWeather3D.WEATHER_OVERCAST,
	&"storm": SkyWeather3D.WEATHER_STORM,
}
## DayNightCycle packs a solar day into 60 s; at 60 fps one frame is 1/3600 of a day.
const STROBE_FRAMES := 120
const STROBE_PROGRESS_PER_FRAME := 1.0 / 3600.0

var _scenario := &"clear"
var _progress := 0.5
var _label := "noon"
var _focus := &"harbour"
var _strobe := false
var _no_mist := false
var _uniform_overrides: Dictionary = {}
var _date := {"day": 21, "month": 6, "year": 1343}


func _initialize() -> void:
	for raw in OS.get_cmdline_user_args():
		var argument := String(raw)
		if argument.begins_with("--scenario="):
			_scenario = StringName(argument.trim_prefix("--scenario="))
		elif argument.begins_with("--progress="):
			_progress = float(argument.trim_prefix("--progress="))
		elif argument.begins_with("--label="):
			_label = argument.trim_prefix("--label=")
		elif argument.begins_with("--focus="):
			_focus = StringName(argument.trim_prefix("--focus="))
		elif argument.begins_with("--set="):
			var pair := argument.trim_prefix("--set=").split(":")
			_uniform_overrides[StringName(pair[0])] = float(pair[1])
		elif argument.begins_with("--date="):
			var parts := argument.trim_prefix("--date=").split("-")
			_date = {"day": int(parts[0]), "month": int(parts[1]), "year": 1343}
		elif argument == "--no-mist":
			_no_mist = true
		elif argument == "--strobe":
			_strobe = true
		else:
			push_error("WS-02 capture: unknown argument %s" % argument)
			quit(1)
			return
	if not FOCUS.has(_focus) or not WEATHER.has(_scenario):
		push_error("WS-02 capture: unsupported focus or scenario")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("WS-02 glint capture needs a real renderer")
		quit(2)
		return
	var definition: MapDefinition = MapAuditRegistry.by_id().get(MAP_ID)
	MapViewMaterials.WATER_MATERIALS.force_ocean_fft_support = true
	MapViewMaterials.reset()
	var viewport := SubViewport.new()
	viewport.size = PLATE_SIZE
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var grid := MapBuilder.build(definition)
	var view := MapView3D.create(definition, grid, MapView3D.TIME_DAY)
	viewport.add_child(view)
	var fog := view.find_child("FogOfWar", true, false) as Node3D
	if fog != null:
		fog.visible = false
	var sky := view.sky_weather()
	view.set_calendar_date(_date)
	view.set_weather_time_scale(0.0)
	sky.auto_weather = false
	sky.set_weather(WEATHER[_scenario])
	sky.advance(SkyWeather3D.TRANSITION_SECONDS)
	view.apply_cycle_progress(_progress)

	var cell: Vector2 = FOCUS[_focus]
	var target := view.world_position(cell * float(definition.cell_size), 0.0)
	var camera := view.view_camera()
	camera.current = true
	camera.size = ORTHO_SIZE
	camera.position = target + camera.transform.basis.z * MapView3D.CAMERA_DISTANCE
	for _frame in WARMUP_FRAMES:
		MapViewRuntimeEnvironment.set_ocean_time(6.0)
		view.apply_cycle_progress(_progress)
		_apply_overrides()
		_clear_mist(view)
		await process_frame

	var sea := MapViewMaterials.water_surface(MapTypes.TERRAIN_DEEP_WATER)
	var sun_direction := SkyWeather3D.solar_direction(_progress, _date)
	print(
		"WS02_STATE scenario=%s progress=%.4f sun=%s camera_forward=%s chop_x_chaos=%.3f" % [
			_scenario,
			_progress,
			sun_direction,
			-camera.global_transform.basis.z,
			float(sea.get_shader_parameter("choppiness"))
				* float(sea.get_shader_parameter("wave_chaos")),
		]
	)
	print("WS02_SUN_REFLECTION_COLOR %s" % sea.get_shader_parameter("sun_reflection_color"))
	if _strobe:
		await _measure_strobe(view, viewport)
		quit(0)
		return
	_clear_mist(view)
	await process_frame
	await process_frame
	_save(viewport.get_texture().get_image())
	quit(0)


## Advances the day cycle at game speed and the sea at real time, one 60 fps frame per
## step, and reports how much the water's luminance jumps between consecutive frames.
func _measure_strobe(view: Node, viewport: SubViewport) -> void:
	var previous: Image = null
	var total := 0.0
	var worst := 0.0
	for index in STROBE_FRAMES:
		var progress := _progress + index * STROBE_PROGRESS_PER_FRAME
		view.apply_cycle_progress(progress)
		MapViewRuntimeEnvironment.set_ocean_time(6.0 + index / 60.0)
		_apply_overrides()
		_clear_mist(view)
		await process_frame
		await process_frame
		var frame := viewport.get_texture().get_image()
		frame.resize(PLATE_SIZE.x / 4, PLATE_SIZE.y / 4, Image.INTERPOLATE_BILINEAR)
		if previous != null:
			var change := _mean_luminance_change(previous, frame)
			total += change
			worst = maxf(worst, change)
		previous = frame
	print(
		"WS02_STROBE scenario=%s progress=%.4f mean_change=%.5f worst_change=%.5f" % [
			_scenario, _progress, total / float(STROBE_FRAMES - 1), worst
		]
	)


func _mean_luminance_change(a: Image, b: Image) -> float:
	var sum := 0.0
	for y in a.get_height():
		for x in a.get_width():
			sum += absf(a.get_pixel(x, y).get_luminance() - b.get_pixel(x, y).get_luminance())
	return sum / float(a.get_width() * a.get_height())


func _clear_mist(view: Node) -> void:
	if not _no_mist:
		return
	for node in view.find_children("*", "WorldEnvironment", true, false):
		(node as WorldEnvironment).environment.fog_enabled = false


## Weather pushes water uniforms every frame, so tuning overrides are re-applied each frame.
func _apply_overrides() -> void:
	for raw in _uniform_overrides:
		for terrain_id in MapViewMaterials.WATER_WAVE_BASE.keys():
			MapViewMaterials.water_surface(terrain_id).set_shader_parameter(
				raw, _uniform_overrides[raw]
			)


func _save(image: Image) -> void:
	var renderer := RenderingServer.get_current_rendering_driver_name()
	var mist_suffix := "_nomist" if _no_mist else ""
	var path := (
		"%s/ws02_%s_%s_%s_%s%s.png" % [OUTPUT_DIR, renderer, _scenario, _label, _focus, mist_suffix]
	)
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("WS-02 capture: could not save %s" % path)
		quit(1)
		return
	print("WS02_CAPTURED %s" % path)
