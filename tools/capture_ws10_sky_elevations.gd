extends SceneTree

## WS-10 physical-sky evidence: one plate per process, looking along the horizon towards the
## sun (left half) and away from it (right half) over reval_harbor_north, with the sun placed
## at a fixed elevation through SkyWeather3D.apply_sky_state. Needs a real renderer:
##   /Applications/Godot.app/Contents/MacOS/Godot --path . \
##     [--rendering-method mobile --rendering-driver metal] \
##     --script tools/capture_ws10_sky_elevations.gd -- --elevation=5 [--weather=clear] [--gradient]
##     [--tier=minimum|recommended]
## --gradient forces the pre-WS-10 gradient sky (sky_lut_available = false), which is the
## unchanged old shader path, so before/after plates share everything else.
## Output: docs/reports/images/ws10_<renderer>_<weather>_<lut|gradient>_e<elevation>.png
##
## --day-sweep instead runs the real runtime path (MapView3D.apply_cycle_progress every frame)
## through one compressed day at 60 frames per in-game hour-of-arc, looking east along the
## horizon, and reports the largest frame-to-frame sky change (pop/flicker check) plus a
## 12-thumbnail strip: docs/reports/images/ws10_<renderer>_day_sweep.png
##
## --benchmark renders the 20-degree sky view at 2560x1440 with vsync off and prints the mean
## wall-clock frame time (SubViewport GPU timers read 0 on this Mac); pair with --gradient.

const MapAuditRegistry := preload("res://scripts/map/map_audit_registry.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapTypesContract := preload("res://scripts/map/map_types.gd")
const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")
const SkyWeather3D := preload("res://scripts/map/view3d/sky_weather_3d.gd")

const MAP_ID := "reval_harbor_north"
const OUTPUT_DIR := "res://docs/reports/images"
const HALF_SIZE := Vector2i(960, 540)
const BENCHMARK_SIZE := Vector2i(2560, 1440)
const BENCHMARK_FRAMES := 600
const WARMUP_FRAMES := 20
const CAMERA_HEIGHT := 4.0
const CAMERA_PITCH_DEG := 16.0
const CAMERA_FOV := 80.0
# Summer solstice keeps the reachable noon sun highest; 60 degrees still needs the override.
const CAPTURE_DATE := {"day": 21, "month": 6, "year": 1343}

var _elevation := 20.0
var _weather := &"clear"
var _gradient := false
var _day_sweep := false
var _benchmark := false
var _tier := SkyWeather3D.QUALITY_RECOMMENDED


func _initialize() -> void:
	for raw in OS.get_cmdline_user_args():
		var argument := String(raw)
		if argument.begins_with("--elevation="):
			_elevation = float(argument.trim_prefix("--elevation="))
		elif argument.begins_with("--weather="):
			_weather = StringName(argument.trim_prefix("--weather="))
		elif argument == "--gradient":
			_gradient = true
		elif argument == "--day-sweep":
			_day_sweep = true
		elif argument == "--benchmark":
			_benchmark = true
		elif argument.begins_with("--tier="):
			_tier = StringName(argument.trim_prefix("--tier="))
		else:
			push_error("WS-10 capture: unknown argument %s" % argument)
			quit(1)
			return
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("WS-10 sky capture needs a real renderer")
		quit(2)
		return
	var definition: MapDefinition = MapAuditRegistry.by_id().get(MAP_ID)
	var viewport := SubViewport.new()
	viewport.size = BENCHMARK_SIZE if _benchmark else HALF_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var grid := MapBuilder.build(definition)
	var view := MapView3D.create(definition, grid, MapView3D.TIME_DAY)
	viewport.add_child(view)
	var sky := view.sky_weather()
	view.set_calendar_date(CAPTURE_DATE)
	view.set_weather_time_scale(0.0)
	sky.auto_weather = false
	sky.set_quality_tier(_tier)
	sky.set_weather(_weather)
	sky.advance(SkyWeather3D.TRANSITION_SECONDS)

	if _day_sweep:
		await _run_day_sweep(view, viewport, grid)
		return
	# Morning progress whose real sun is nearest the target keeps the scene lights plausible;
	# the sky itself gets the exact elevation below.
	var progress := _morning_progress_for(_elevation)
	view.apply_cycle_progress(progress)
	var real_sun := SkyWeather3D.solar_direction(progress, CAPTURE_DATE)
	var azimuth := Vector2(real_sun.x, real_sun.z).normalized()
	var elevation := deg_to_rad(_elevation)
	var sun_dir := Vector3(
		azimuth.x * cos(elevation), sin(elevation), azimuth.y * cos(elevation)
	)
	var day_blend := clampf(SkyWeather3D.daylight_blend(progress, CAPTURE_DATE), 0.0, 1.0)
	if _elevation >= 30.0:
		day_blend = 1.0
	sky.apply_sky_state(progress, day_blend, sun_dir)
	view.set_process(false)
	# The sky material is owned by SkyWeather3D; read it directly rather than hunting the
	# environment, which MapView3D may keep on a WorldEnvironment or the World3D.
	var sky_material: ShaderMaterial = sky._material
	if _gradient:
		sky_material.set_shader_parameter(&"sky_lut_available", false)

	var camera := view.view_camera()
	camera.current = true
	camera.fov = CAMERA_FOV
	camera.far = 4000.0
	if _benchmark:
		await _run_benchmark(view, camera, grid, sky, progress, day_blend, sun_dir, azimuth)
		return
	var focus_cell := _open_water_cell(grid)
	var origin := view.world_position(Vector2(focus_cell) + Vector2(0.5, 0.5), CAMERA_HEIGHT)
	var halves: Array[Image] = []
	for toward_sun in [true, false]:
		var flat := Vector3(azimuth.x, 0.0, azimuth.y) * (1.0 if toward_sun else -1.0)
		var look := flat * cos(deg_to_rad(CAMERA_PITCH_DEG))
		look.y = sin(deg_to_rad(CAMERA_PITCH_DEG))
		camera.look_at_from_position(origin, origin + look, Vector3.UP)
		for _frame in WARMUP_FRAMES:
			# Keep the LUT fresh: apply_sky_state schedules a render for this frame.
			sky.apply_sky_state(progress, day_blend, sun_dir)
			await process_frame
		halves.append(viewport.get_texture().get_image())
	var sheet := Image.create(HALF_SIZE.x * 2, HALF_SIZE.y, false, halves[0].get_format())
	sheet.blit_rect(halves[0], Rect2i(Vector2i.ZERO, HALF_SIZE), Vector2i.ZERO)
	sheet.blit_rect(halves[1], Rect2i(Vector2i.ZERO, HALF_SIZE), Vector2i(HALF_SIZE.x, 0))
	var renderer := RenderingServer.get_current_rendering_driver_name()
	var mode := "gradient" if _gradient else "lut"
	var path := "%s/ws10_%s_%s_%s_e%s.png" % [
		OUTPUT_DIR, renderer, String(_weather), mode, str(int(_elevation)).replace("-", "m")
	]
	var error := sheet.save_png(ProjectSettings.globalize_path(path))
	print("WS10_SKY_CAPTURE path=%s ok=%s lut=%s" % [path, error == OK, sky.uses_atmosphere_lut()])
	quit(0 if error == OK else 1)


func _run_benchmark(
	view: MapView3D, camera: Camera3D, grid: MapTerrainGrid, sky: SkyWeather3D,
	progress: float, day_blend: float, sun_dir: Vector3, azimuth: Vector2
) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var water := Vector2(_open_water_cell(grid)) + Vector2(0.5, 0.5)
	var origin := view.world_position(water, CAMERA_HEIGHT)
	var look := Vector3(azimuth.x, 0.0, azimuth.y) * cos(deg_to_rad(CAMERA_PITCH_DEG))
	look.y = sin(deg_to_rad(CAMERA_PITCH_DEG))
	camera.look_at_from_position(origin, origin + look, Vector3.UP)
	for _frame in 60:
		sky.apply_sky_state(progress, day_blend, sun_dir)
		await process_frame
	var start := Time.get_ticks_usec()
	for _frame in BENCHMARK_FRAMES:
		# The runtime pushes the sky state every frame in both modes; the gradient run cancels
		# the LUT render so it measures the old cost.
		sky.apply_sky_state(progress, day_blend, sun_dir)
		if _gradient:
			sky.atmosphere_lut().viewport().render_target_update_mode = SubViewport.UPDATE_DISABLED
		await process_frame
	var mean_ms := float(Time.get_ticks_usec() - start) / 1000.0 / float(BENCHMARK_FRAMES)
	print(
		"WS10_BENCHMARK renderer=%s tier=%s mode=%s size=%s mean_frame_ms=%.3f"
		% [
			RenderingServer.get_current_rendering_driver_name(),
			_tier,
			"gradient" if _gradient else "lut",
			BENCHMARK_SIZE,
			mean_ms,
		]
	)
	quit(0)


func _run_day_sweep(view: MapView3D, viewport: SubViewport, grid: MapTerrainGrid) -> void:
	# 3600 frames = one compressed day at 60 fps (DayNightCycle: ~60 s per day), so every step
	# matches what a player sees frame to frame.
	const FRAMES := 3600
	const THUMBS := 12
	const SKY_ROWS := 200
	view.set_process(false)
	var camera := view.view_camera()
	camera.current = true
	camera.fov = CAMERA_FOV
	camera.far = 4000.0
	var water := Vector2(_open_water_cell(grid)) + Vector2(0.5, 0.5)
	var origin := view.world_position(water, CAMERA_HEIGHT)
	var look := Vector3(cos(deg_to_rad(CAMERA_PITCH_DEG)), sin(deg_to_rad(CAMERA_PITCH_DEG)), 0.0)
	camera.look_at_from_position(origin, origin + look, Vector3.UP)
	var thumb_size := Vector2i(HALF_SIZE.x / 4, HALF_SIZE.y / 4)
	var strip := Image.create(thumb_size.x * THUMBS / 2, thumb_size.y * 2, false, Image.FORMAT_RGBA8)
	var previous: PackedByteArray
	var worst := 0.0
	var worst_progress := 0.0
	var total := 0.0
	# Warm up at midnight so the first measured step is not the empty-to-rendered jump.
	for _warm in 30:
		view.apply_cycle_progress(0.0)
		await process_frame
	for frame in FRAMES:
		var progress := float(frame) / float(FRAMES)
		view.apply_cycle_progress(progress)
		await process_frame
		var image := viewport.get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		# Sky band only (top rows): the water has its own animation and is not under test.
		var sky := image.get_region(Rect2i(0, 0, HALF_SIZE.x, SKY_ROWS))
		sky.resize(HALF_SIZE.x / 8, SKY_ROWS / 8, Image.INTERPOLATE_BILINEAR)
		var data := sky.get_data()
		if not previous.is_empty():
			var diff := 0.0
			for i in data.size():
				diff += absf(float(data[i]) - float(previous[i]))
			diff /= float(data.size())
			total += diff
			if diff > worst:
				worst = diff
				worst_progress = progress
		previous = data
		if frame % (FRAMES / THUMBS) == 0:
			var index := frame / (FRAMES / THUMBS)
			image.resize(thumb_size.x, thumb_size.y, Image.INTERPOLATE_BILINEAR)
			var at := Vector2i((index % (THUMBS / 2)) * thumb_size.x, (index / (THUMBS / 2)) * thumb_size.y)
			strip.blit_rect(image, Rect2i(Vector2i.ZERO, thumb_size), at)
	var renderer := RenderingServer.get_current_rendering_driver_name()
	var path := "%s/ws10_%s_day_sweep.png" % [OUTPUT_DIR, renderer]
	var error := strip.save_png(ProjectSettings.globalize_path(path))
	print(
		"WS10_DAY_SWEEP path=%s ok=%s mean_step=%.3f max_step=%.3f at_progress=%.4f"
		% [path, error == OK, total / float(FRAMES - 1), worst, worst_progress]
	)
	quit(0 if error == OK else 1)


func _morning_progress_for(target_deg: float) -> float:
	# Bisection between solar midnight and noon; elevation rises monotonically there.
	var lo := 0.0
	var hi := 0.5
	for _i in 40:
		var mid := (lo + hi) * 0.5
		if SkyWeather3D.solar_elevation_degrees(mid, CAPTURE_DATE) < target_deg:
			lo = mid
		else:
			hi = mid
	return (lo + hi) * 0.5


func _open_water_cell(grid: MapTerrainGrid) -> Vector2i:
	# Deepest-in-water cell: the one with the most water around it, away from buildings.
	var best := Vector2i(grid.size_cells.x / 2, grid.size_cells.y / 2)
	var best_score := -1
	for y in range(4, grid.size_cells.y - 4, 3):
		for x in range(4, grid.size_cells.x - 4, 3):
			var score := 0
			for dy in range(-4, 5, 2):
				for dx in range(-4, 5, 2):
					if MapTypesContract.WATER_TERRAINS.has(grid.get_terrain(Vector2i(x + dx, y + dy))):
						score += 1
			if score > best_score:
				best_score = score
				best = Vector2i(x, y)
	return best
