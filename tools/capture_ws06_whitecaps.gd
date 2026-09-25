extends SceneTree

## WS-06 whitecap evidence on the FFT sea. One plate per process; needs a real renderer,
## so run it through the minimized-window wrapper:
##   tools/godot_render.sh --rendering-method mobile --rendering-driver metal \
##     --script tools/capture_ws06_whitecaps.gd -- --scenario=storm --time=day
## Compatibility: replace the renderer flags with --rendering-driver opengl3.
##
## Options:
##   --scenario=clear|overcast|storm   weather preset
##   --time=day|night
##   --focus=harbour|coast    open harbour basin (reval_harbor_north) or the east beach
##   --close                  nearest gameplay zoom (bubble structure check)
##   --aim=<px>,<py>          centre the close-up on this pixel of the wide plate
##   --clip                   10 s contact sheet (11 frames, 1 s apart): foam must ride its wave
##   --ocean-time=<seconds>   sea clock for a single plate (default 6.0)
##   --set=name:value         water-material uniform override for tuning
## The FFT sea is forced on (play keeps Gerstner until WS-05), as the WS-04 plates did.
## Writes docs/reports/images/ws06_<renderer>_<scenario>_<time>_<focus>[_close][_clip].png

const MapAuditRegistry := preload("res://scripts/map/map_audit_registry.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")
const SkyWeather3D := preload("res://scripts/map/view3d/sky_weather_3d.gd")

const OUTPUT_DIR := "res://docs/reports/images"
const PLATE_SIZE := Vector2i(1280, 720)
const WARMUP_FRAMES := 90
const CLIP_SECONDS := 10.0
const CLIP_STEP := 1.0
const CLIP_COLUMNS := 4
## Map and focus cell per focus: open deep water in the harbour basin, and the beach
## spit on the east harbour's west headland.
const FOCUS := {
	&"harbour": {"map": "reval_harbor_north", "cell": Vector2(80.5, 24.5)},
	&"coast": {"map": "reval_harbor_east", "cell": Vector2(12.0, 26.0)},
}
const ORTHO_SIZE := 28.0
const CLOSE_ORTHO_SIZE := 9.0
const WEATHER := {
	&"clear": SkyWeather3D.WEATHER_CLEAR,
	&"overcast": SkyWeather3D.WEATHER_OVERCAST,
	&"storm": SkyWeather3D.WEATHER_STORM,
}
const CAPTURE_DATE := {"day": 21, "month": 6, "year": 1343}

var _scenario := &"overcast"
var _time := MapView3D.TIME_DAY
var _focus := &"harbour"
var _close := false
var _aim := Vector2(-1.0, -1.0)
var _clip := false
var _ocean_time := 6.0
var _uniform_overrides: Dictionary = {}


func _initialize() -> void:
	for raw in OS.get_cmdline_user_args():
		var argument := String(raw)
		if argument.begins_with("--scenario="):
			_scenario = StringName(argument.trim_prefix("--scenario="))
		elif argument.begins_with("--time="):
			_time = StringName(argument.trim_prefix("--time="))
		elif argument.begins_with("--focus="):
			_focus = StringName(argument.trim_prefix("--focus="))
		elif argument.begins_with("--ocean-time="):
			_ocean_time = float(argument.trim_prefix("--ocean-time="))
		elif argument.begins_with("--set="):
			var pair := argument.trim_prefix("--set=").split(":")
			_uniform_overrides[StringName(pair[0])] = float(pair[1])
		elif argument.begins_with("--aim="):
			var aim := argument.trim_prefix("--aim=").split(",")
			_aim = Vector2(float(aim[0]), float(aim[1]))
		elif argument == "--close":
			_close = true
		elif argument == "--clip":
			_clip = true
		else:
			push_error("WS-06 capture: unknown argument %s" % argument)
			quit(1)
			return
	if not FOCUS.has(_focus) or not WEATHER.has(_scenario):
		push_error("WS-06 capture: unsupported focus or scenario")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("WS-06 whitecap capture needs a real renderer")
		quit(2)
		return
	var focus: Dictionary = FOCUS[_focus]
	var definition: MapDefinition = MapAuditRegistry.by_id().get(String(focus["map"]))
	MapViewMaterials.WATER_MATERIALS.force_ocean_fft_support = true
	MapViewMaterials.reset()
	var viewport := SubViewport.new()
	viewport.size = PLATE_SIZE
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var grid := MapBuilder.build(definition)
	var view := MapView3D.create(definition, grid, _time)
	viewport.add_child(view)
	var fog := view.find_child("FogOfWar", true, false) as Node3D
	if fog != null:
		fog.visible = false
	var sky := view.sky_weather()
	view.set_calendar_date(CAPTURE_DATE)
	view.set_time_of_day(_time)
	view.set_weather_time_scale(0.0)
	sky.auto_weather = false
	sky.set_weather(WEATHER[_scenario])
	sky.advance(SkyWeather3D.TRANSITION_SECONDS)
	view.apply_cycle_progress(view.cycle_progress)

	var cell: Vector2 = focus["cell"]
	var target := view.world_position(cell * float(definition.cell_size), 0.0)
	var camera := view.view_camera()
	camera.current = true
	camera.size = ORTHO_SIZE
	camera.position = target + camera.transform.basis.z * MapView3D.CAMERA_DISTANCE
	if _aim.x >= 0.0:
		# Re-centre on the sea point under a pixel of the wide plate (orthographic ray).
		await process_frame
		var origin := camera.project_ray_origin(_aim)
		var direction := camera.project_ray_normal(_aim)
		if absf(direction.y) > 0.0001:
			target = origin + direction * ((target.y - origin.y) / direction.y)
			camera.position = target + camera.transform.basis.z * MapView3D.CAMERA_DISTANCE
	if _close:
		camera.size = CLOSE_ORTHO_SIZE
	for _frame in WARMUP_FRAMES:
		MapViewRuntimeEnvironment.set_ocean_time(_ocean_time)
		_apply_overrides()
		await process_frame

	var sea_material := MapViewMaterials.water_surface(MapTypes.TERRAIN_DEEP_WATER)
	print(
		"WS06_SEA scenario=%s coverage=%.3f streaks=%.3f amplitude=%.3f" % [
			_scenario,
			float(sea_material.get_shader_parameter("storm_foam_coverage")),
			float(sea_material.get_shader_parameter("storm_streaks")),
			float(sea_material.get_shader_parameter("ocean_amplitude")),
		]
	)
	var suffix := "_close" if _close else ""
	if not _clip:
		MapViewRuntimeEnvironment.set_ocean_time(_ocean_time)
		await process_frame
		await process_frame
		_save(viewport.get_texture().get_image(), suffix)
		quit(0)
		return
	var frames: Array[Image] = []
	var t := 0.0
	while t <= CLIP_SECONDS + 0.001:
		MapViewRuntimeEnvironment.set_ocean_time(_ocean_time + t)
		await process_frame
		await process_frame
		var frame := viewport.get_texture().get_image()
		frame.resize(PLATE_SIZE.x / 2, PLATE_SIZE.y / 2, Image.INTERPOLATE_BILINEAR)
		frames.append(frame)
		t += CLIP_STEP
	_save(_contact_sheet(frames), suffix + "_clip")
	quit(0)


## Weather pushes water uniforms every frame, so tuning overrides are re-applied each frame.
func _apply_overrides() -> void:
	for raw in _uniform_overrides:
		for terrain_id in MapViewMaterials.WATER_WAVE_BASE.keys():
			MapViewMaterials.water_surface(terrain_id).set_shader_parameter(
				raw, _uniform_overrides[raw]
			)


func _contact_sheet(frames: Array[Image]) -> Image:
	var tile := frames[0].get_size()
	var rows := ceili(float(frames.size()) / float(CLIP_COLUMNS))
	var sheet := Image.create_empty(tile.x * CLIP_COLUMNS, tile.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.BLACK)
	for index in frames.size():
		var frame := frames[index]
		frame.convert(Image.FORMAT_RGBA8)
		var origin := Vector2i((index % CLIP_COLUMNS) * tile.x, (index / CLIP_COLUMNS) * tile.y)
		sheet.blit_rect(frame, Rect2i(Vector2i.ZERO, tile), origin)
	return sheet


func _save(image: Image, suffix: String) -> void:
	var renderer := RenderingServer.get_current_rendering_driver_name()
	var path := (
		"%s/ws06_%s_%s_%s_%s%s.png" % [OUTPUT_DIR, renderer, _scenario, _time, _focus, suffix]
	)
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("WS-06 capture: could not save %s" % path)
		quit(1)
		return
	print("WS06_CAPTURED %s" % path)
