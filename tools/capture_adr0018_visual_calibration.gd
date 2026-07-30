extends SceneTree

## ADR 0018 visual-calibration evidence. Capture one frame per process:
##   godot --path . --script tools/capture_adr0018_visual_calibration.gd -- \
##     --map=kalev_smithy --camera=third_person --time=day

const Registry := preload("res://scripts/map/map_audit_registry.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const RuntimeCamera := preload("res://scripts/map/view3d/map_view_runtime_camera.gd")

const OUTPUT_DIR := "res://docs/reports/images/adr0018_calibration"
const VIEWPORT_SIZE := Vector2i(1280, 720)
const MAP_IDS: Array[String] = ["kalev_smithy", "lower_town_slice", "reval_harbor_east"]
const CAMERA_MODES: Array[StringName] = [&"third_person", &"top_down"]
const TIMES: Array[StringName] = [MapView3D.TIME_DAY, MapView3D.TIME_NIGHT]
const SETTLE_FRAMES := 16

var _map_id := ""
var _camera_mode := &""
var _time_of_day := &""


func _initialize() -> void:
	_parse_args()
	call_deferred("_run")


func _parse_args() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--map="):
			_map_id = argument.trim_prefix("--map=")
		elif argument.begins_with("--camera="):
			_camera_mode = StringName(argument.trim_prefix("--camera="))
		elif argument.begins_with("--time="):
			_time_of_day = StringName(argument.trim_prefix("--time="))


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	if _map_id.is_empty():
		# Batch mode kept for local iteration; prefer one-frame processes in CI.
		var definitions := Registry.by_id()
		for map_id in MAP_IDS:
			for camera_mode in CAMERA_MODES:
				for time_of_day in TIMES:
					var error := await _capture(definitions[map_id], camera_mode, time_of_day)
					if error != OK:
						quit(1)
						return
		print("ADR0018_CALIBRATION_CAPTURES_OK dir=%s" % OUTPUT_DIR)
		quit(0)
		return

	var definitions := Registry.by_id()
	if not definitions.has(_map_id):
		push_error("Unknown map id for ADR 0018 calibration: %s" % _map_id)
		quit(1)
		return
	if _camera_mode not in CAMERA_MODES or _time_of_day not in TIMES:
		push_error("Invalid camera/time for ADR 0018 calibration")
		quit(1)
		return
	var error := await _capture(definitions[_map_id], _camera_mode, _time_of_day)
	quit(0 if error == OK else 1)


func _capture(definition: MapDefinition, camera_mode: StringName, time_of_day: StringName) -> Error:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)

	var view := MapView3D.create(definition, MapBuilder.build(definition), time_of_day)
	viewport.add_child(view)

	var sky := view.sky_weather()
	if sky != null:
		sky.auto_weather = false
		sky.set_weather(SkyWeather3D.WEATHER_CLEAR)
		sky.advance(1.0)
	view.set_time_of_day(time_of_day)

	var ortho := view.view_camera()
	if camera_mode == &"third_person":
		view.set_close_camera_mode(true)
		ortho.current = false
		var follow := _make_third_person_camera(definition)
		viewport.add_child(follow)
		follow.make_current()
	else:
		view.set_close_camera_mode(false)
		ortho.current = true

	for _frame in SETTLE_FRAMES:
		await process_frame

	var image := viewport.get_texture().get_image()
	var output := "%s/%s_%s_%s.png" % [OUTPUT_DIR, definition.map_id, camera_mode, time_of_day]
	var error := image.save_png(ProjectSettings.globalize_path(output))
	if error != OK:
		push_error("Could not save ADR 0018 capture %s: %s" % [output, error_string(error)])
	else:
		print(
			"ADR0018 capture: %s mean_Y=%.2f clip_hi=%.3f sat=%.3f"
			% [output, _mean_luminance(image), _highlight_clip_ratio(image), _mean_saturation(image)]
		)
	viewport.queue_free()
	await process_frame
	return error


func _make_third_person_camera(definition: MapDefinition) -> Camera3D:
	var scale := MapViewBridge.world_scale(definition.cell_size)
	var spawn := definition.player_spawn
	var target := Vector3(spawn.x * scale, RuntimeCamera.THIRD_PERSON_TARGET_HEIGHT, spawn.y * scale)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = RuntimeCamera.THIRD_PERSON_FOV_DEGREES
	camera.near = RuntimeCamera.THIRD_PERSON_NEAR
	camera.far = MapView3D.CAMERA_FAR
	camera.rotation_degrees = Vector3(
		RuntimeCamera.THIRD_PERSON_PITCH_DEGREES,
		MapView3D.CAMERA_YAW_DEGREES,
		0.0
	)
	camera.position = target + camera.transform.basis.z * RuntimeCamera.THIRD_PERSON_DISTANCE
	return camera


func _mean_luminance(image: Image) -> float:
	var total := 0.0
	var count := 0
	for sample in _samples(image):
		total += 0.2126 * sample.r + 0.7152 * sample.g + 0.0722 * sample.b
		count += 1
	return 0.0 if count == 0 else (total / float(count)) * 255.0


func _mean_saturation(image: Image) -> float:
	var total := 0.0
	var count := 0
	for sample in _samples(image):
		total += sample.s
		count += 1
	return 0.0 if count == 0 else total / float(count)


func _highlight_clip_ratio(image: Image) -> float:
	var clipped := 0
	var count := 0
	for sample in _samples(image):
		count += 1
		if sample.r >= 0.985 and sample.g >= 0.985 and sample.b >= 0.985:
			clipped += 1
	return 0.0 if count == 0 else float(clipped) / float(count)


func _samples(image: Image) -> Array[Color]:
	var out: Array[Color] = []
	if image == null or image.get_width() == 0:
		return out
	var step_x := maxi(image.get_width() / 64, 1)
	var step_y := maxi(image.get_height() / 36, 1)
	for y in range(0, image.get_height(), step_y):
		for x in range(0, image.get_width(), step_x):
			out.append(image.get_pixel(x, y))
	return out
