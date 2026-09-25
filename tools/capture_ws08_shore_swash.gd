extends SceneTree

## WS-08 shore swash evidence on reval_harbor_east (coast sand beach plus timber piers).
##
## One plate per process. Needs a real renderer, never --headless:
##   /Applications/Godot.app/Contents/MacOS/Godot --path . \
##     --rendering-method mobile --rendering-driver metal \
##     --script tools/capture_ws08_shore_swash.gd -- --scenario=clear --time=day
## Compatibility: replace the renderer flags with --rendering-driver opengl3.
##
## Options:
##   --scenario=clear|storm   weather preset
##   --time=day|night
##   --focus=beach|quay       beach spit (run-up) or pier edge (slosh, no run-up)
##   --clip                   20 s contact sheet (11 frames, 2 s apart)
##   --ocean-time=<seconds>   sea clock for a single plate (default 4.0)
##   --off                    shore field disabled (before/after comparison)
## Writes docs/reports/images/ws08_<renderer>_<scenario>_<time>_<focus>[_clip|_off].png

const MapAuditRegistry := preload("res://scripts/map/map_audit_registry.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")
const SkyWeather3D := preload("res://scripts/map/view3d/sky_weather_3d.gd")

const MAP_ID := "reval_harbor_east"
const OUTPUT_DIR := "res://docs/reports/images"
const PLATE_SIZE := Vector2i(1280, 720)
const WARMUP_FRAMES := 90
const CLIP_SECONDS := 20.0
const CLIP_STEP := 2.0
const CLIP_COLUMNS := 4
## Beach spit on the west headland and the west pier's water-side edge (cells).
const FOCUS_CELLS := {&"beach": Vector2(9.0, 32.0), &"quay": Vector2(27.0, 29.0)}
const ORTHO_SIZE := {&"beach": 16.0, &"quay": 16.0}
const CAPTURE_DATE := {"day": 21, "month": 6, "year": 1343}

var _scenario := &"clear"
var _time := MapView3D.TIME_DAY
var _focus := &"beach"
var _clip := false
var _off := false
var _ocean_time := 4.0


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
		elif argument == "--clip":
			_clip = true
		elif argument == "--off":
			_off = true
		else:
			push_error("WS-08 capture: unknown argument %s" % argument)
			quit(1)
			return
	if not FOCUS_CELLS.has(_focus) or _scenario not in [&"clear", &"storm"]:
		push_error("WS-08 capture: unsupported focus or scenario")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("WS-08 shore capture needs a real renderer")
		quit(2)
		return
	var definition: MapDefinition = MapAuditRegistry.by_id().get(MAP_ID)
	var viewport := SubViewport.new()
	viewport.size = PLATE_SIZE
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var grid := MapBuilder.build(definition)
	var view := MapView3D.create(definition, grid, _time)
	viewport.add_child(view)
	if _off:
		MapViewMaterials.apply_shore_field(null, Vector2.ZERO, Vector2.ONE)
		var sheet := view.find_child("ShoreSwashSheet", true, false) as Node3D
		if sheet != null:
			sheet.visible = false
	var sky := view.sky_weather()
	view.set_calendar_date(CAPTURE_DATE)
	view.set_time_of_day(_time)
	view.set_weather_time_scale(0.0)
	sky.auto_weather = false
	var weather := SkyWeather3D.WEATHER_STORM if _scenario == &"storm" else SkyWeather3D.WEATHER_CLEAR
	sky.set_weather(weather)
	sky.advance(SkyWeather3D.TRANSITION_SECONDS)
	view.apply_cycle_progress(view.cycle_progress)

	var cell: Vector2 = FOCUS_CELLS[_focus]
	var target := view.world_position(cell * float(definition.cell_size), 0.0)
	var camera := view.view_camera()
	camera.current = true
	camera.size = ORTHO_SIZE[_focus]
	camera.position = target + camera.transform.basis.z * MapView3D.CAMERA_DISTANCE
	for _frame in WARMUP_FRAMES:
		MapViewRuntimeEnvironment.set_ocean_time(_ocean_time)
		await process_frame

	var suffix := "_off" if _off else ""
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
	_save(_contact_sheet(frames), "_clip" + suffix)
	quit(0)


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
		"%s/ws08_%s_%s_%s_%s%s.png" % [OUTPUT_DIR, renderer, _scenario, _time, _focus, suffix]
	)
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("WS-08 capture: could not save %s" % path)
		quit(1)
		return
	print("WS08_CAPTURED %s" % path)
