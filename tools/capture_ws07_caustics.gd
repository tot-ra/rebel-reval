extends SceneTree

## WS-07 bed-caustic evidence on the shallow fishing-harbour beach. One plate (or one clip) per
## process; needs a real renderer, so run it through the minimized-window wrapper:
##   tools/godot_render.sh --rendering-method mobile --rendering-driver metal \
##     --script tools/capture_ws07_caustics.gd -- --scenario=clear --progress=0.5 --label=noon
## Compatibility: replace the renderer flags with --rendering-driver opengl3.
##
## Options:
##   --scenario=clear|overcast|storm   weather preset
##   --progress=<0..1>        day-cycle progress (0 midnight, 0.5 noon)
##   --label=<name>           plate name suffix (noon, sunset, night, ...)
##   --orbit=<degrees>        camera yaw around the focus (shimmer check)
##   --clip=<frames>          instead of one plate, write <frames> frames 1/15 s apart
##                            (ocean clock) as ws07_..._fNN.png and print the mean
##                            frame-to-frame luminance change of the water
##   --set=name:value         water-material uniform override (caustic_strength:0 = off)
## Writes docs/reports/images/ws07_<renderer>_<scenario>_<label>[_o<deg>].png

const MapAuditRegistry := preload("res://scripts/map/map_audit_registry.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")
const SkyWeather3D := preload("res://scripts/map/view3d/sky_weather_3d.gd")

const OUTPUT_DIR := "res://docs/reports/images"
const PLATE_SIZE := Vector2i(1280, 720)
const WARMUP_FRAMES := 90
const MAP_ID := "reval_harbor_east"
## Fishing-harbour beach shelf (the WS-08 beach plate): ankle-deep to deeper water over
## sand, close enough to read the net.
const FOCUS_CELL := Vector2(9.0, 32.0)
const ORTHO_SIZE := 12.0
const WEATHER := {
	&"clear": SkyWeather3D.WEATHER_CLEAR,
	&"overcast": SkyWeather3D.WEATHER_OVERCAST,
	&"storm": SkyWeather3D.WEATHER_STORM,
}
const CLIP_STEP_SECONDS := 1.0 / 15.0

var _scenario := &"clear"
var _progress := 0.5
var _label := "noon"
var _orbit := 0.0
var _clip_frames := 0
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
		elif argument.begins_with("--orbit="):
			_orbit = float(argument.trim_prefix("--orbit="))
		elif argument.begins_with("--clip="):
			_clip_frames = int(argument.trim_prefix("--clip="))
		elif argument.begins_with("--set="):
			var pair := argument.trim_prefix("--set=").split(":")
			_uniform_overrides[StringName(pair[0])] = float(pair[1])
		else:
			push_error("WS-07 capture: unknown argument %s" % argument)
			quit(1)
			return
	if not WEATHER.has(_scenario):
		push_error("WS-07 capture: unsupported scenario")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("WS-07 caustic capture needs a real renderer")
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

	var target := view.world_position(FOCUS_CELL * float(definition.cell_size), 0.0)
	var camera := view.view_camera()
	camera.current = true
	camera.size = ORTHO_SIZE
	var offset := camera.transform.basis.z * MapView3D.CAMERA_DISTANCE
	camera.position = target + offset.rotated(Vector3.UP, deg_to_rad(_orbit))
	camera.look_at(target, Vector3.UP)
	for _frame in WARMUP_FRAMES:
		MapViewRuntimeEnvironment.set_ocean_time(6.0)
		view.apply_cycle_progress(_progress)
		_apply_overrides()
		await process_frame
	var sun_direction := SkyWeather3D.solar_direction(_progress, _date)
	print(
		"WS07_STATE scenario=%s progress=%.4f sun=%s orbit=%.0f"
		% [_scenario, _progress, sun_direction, _orbit]
	)
	if _clip_frames > 0:
		await _capture_clip(view, viewport)
		quit(0)
		return
	await process_frame
	await process_frame
	_save(viewport.get_texture().get_image(), "")
	quit(0)


## Steps the ocean clock (the caustic scroll clock) and writes every frame, then reports
## the mean luminance change so a shimmering net shows up as a number, not only by eye.
func _capture_clip(view: Node, viewport: SubViewport) -> void:
	var previous: Image = null
	var total := 0.0
	for index in _clip_frames:
		MapViewRuntimeEnvironment.set_ocean_time(6.0 + index * CLIP_STEP_SECONDS)
		view.apply_cycle_progress(_progress)
		_apply_overrides()
		await process_frame
		await process_frame
		var frame := viewport.get_texture().get_image()
		_save(frame, "_f%02d" % index)
		var small := frame.duplicate() as Image
		small.resize(PLATE_SIZE.x / 4, PLATE_SIZE.y / 4, Image.INTERPOLATE_BILINEAR)
		if previous != null:
			total += _mean_luminance_change(previous, small)
		previous = small
	var mean_change := total / maxf(float(_clip_frames - 1), 1.0)
	print("WS07_CLIP frames=%d mean_change=%.5f" % [_clip_frames, mean_change])


func _mean_luminance_change(a: Image, b: Image) -> float:
	var sum := 0.0
	for y in a.get_height():
		for x in a.get_width():
			sum += absf(a.get_pixel(x, y).get_luminance() - b.get_pixel(x, y).get_luminance())
	return sum / float(a.get_width() * a.get_height())


## Weather pushes water uniforms every frame, so tuning overrides are re-applied each frame.
func _apply_overrides() -> void:
	for raw in _uniform_overrides:
		for terrain_id in MapViewMaterials.WATER_WAVE_BASE.keys():
			MapViewMaterials.water_surface(terrain_id).set_shader_parameter(raw, _uniform_overrides[raw])


func _save(image: Image, suffix: String) -> void:
	var renderer := RenderingServer.get_current_rendering_driver_name()
	var orbit_suffix := "_o%d" % int(_orbit) if _orbit != 0.0 else ""
	var path := (
		"%s/ws07_%s_%s_%s%s%s.png"
		% [OUTPUT_DIR, renderer, _scenario, _label, orbit_suffix, suffix]
	)
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("WS-07 capture: could not save %s" % path)
		quit(1)
		return
	print("WS07_CAPTURED %s" % path)
