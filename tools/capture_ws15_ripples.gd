extends SceneTree

## WS-15 interactive-ripple evidence over reval_harbor_north. One plate per process; needs a
## real renderer:
##   tools/godot_render.sh \
##     [--rendering-method mobile --rendering-driver metal] \
##     --script tools/capture_ws15_ripples.gd -- --scenario=rain [--off]
## Scenarios:
##   clear | rain | storm   day plate from a close perspective camera over open water
##   wake                    a scripted debug hull crossing the view with add_moving_body
##   stability               600 steps at maximum rain; reads the state back every 60 steps
##                           (capture-only readback) and prints the largest |h| and aeration
##   clip                    storm, 10 s at 60 fps while the camera pans 12 units so the
##                           window scrolls; saves an 8-frame strip and prints the largest
##                           full-frame mean change between frames 4 apart (pop check)
##   benchmark               2560x1440, vsync off, storm + wake; pair with --off
## --off detaches the sim (flat ripple state), giving the before plate / baseline.
## --fft forces the WS-04 FFT sea (play keeps Gerstner until WS-05), as the WS-04 plates did.
## --set=name:value overrides a water-material uniform for tuning.
## Output: docs/reports/images/ws15_<renderer>_<scenario>[_fft][_off].png

const MapAuditRegistry := preload("res://scripts/map/map_audit_registry.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")
const SkyWeather3D := preload("res://scripts/map/view3d/sky_weather_3d.gd")
const WaterRippleSimScript := preload("res://scripts/map/view3d/water_ripple_sim.gd")

const MAP_ID := "reval_harbor_north"
const OUTPUT_DIR := "res://docs/reports/images"
const PLATE_SIZE := Vector2i(1280, 720)
const BENCHMARK_SIZE := Vector2i(2560, 1440)
const BENCHMARK_FRAMES := 600
const WARMUP_FRAMES := 150
const ORTHO_SIZE := 16.0
const WAKE_SPEED := 3.2
const WAKE_HALF_LENGTH := 2.4
const WAKE_HALF_BEAM := 0.9
## Open deep water in the middle of the harbour basin, well inside the map edges (rows 0-45
## are deep_water on reval_harbor_north), so the whole 64-unit window lies on sea.
const TARGET_CELL := Vector2i(80, 24)
const CAPTURE_DATE := {"day": 21, "month": 6, "year": 1343}

var _scenario := &"rain"
var _off := false
var _fft := false
## --set=name:value water-material uniform overrides for tuning plates.
var _uniform_overrides := {}


func _initialize() -> void:
	for raw in OS.get_cmdline_user_args():
		var argument := String(raw)
		if argument.begins_with("--scenario="):
			_scenario = StringName(argument.trim_prefix("--scenario="))
		elif argument == "--off":
			_off = true
		elif argument == "--fft":
			_fft = true
		elif argument.begins_with("--set="):
			var pair := argument.trim_prefix("--set=").split(":")
			_uniform_overrides[StringName(pair[0])] = float(pair[1])
		else:
			push_error("WS-15 capture: unknown argument %s" % argument)
			quit(1)
			return
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("WS-15 ripple capture needs a real renderer")
		quit(2)
		return
	var definition: MapDefinition = MapAuditRegistry.by_id().get(MAP_ID)
	if _fft:
		# Same hook as the WS-04 plates: play keeps Gerstner until WS-05 ships FFT buoyancy.
		MapViewMaterials.WATER_MATERIALS.force_ocean_fft_support = true
		MapViewMaterials.reset()
	var viewport := SubViewport.new()
	viewport.size = BENCHMARK_SIZE if _scenario == &"benchmark" else PLATE_SIZE
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var grid := MapBuilder.build(definition)
	var view := MapView3D.create(definition, grid, MapView3D.TIME_DAY)
	viewport.add_child(view)
	var sim := view.water_ripple_sim()
	if sim == null:
		push_error("WS-15 capture: the harbour view built no ripple sim")
		quit(3)
		return
	if _off:
		_detach(view, sim)
	var sky := view.sky_weather()
	view.set_calendar_date(CAPTURE_DATE)
	view.set_weather_time_scale(0.0)
	sky.auto_weather = false
	var weather := SkyWeather3D.WEATHER_CLEAR
	if _scenario in [&"rain", &"stability"]:
		weather = SkyWeather3D.WEATHER_RAIN
	elif _scenario in [&"storm", &"benchmark", &"clip"]:
		weather = SkyWeather3D.WEATHER_STORM
	sky.set_weather(weather)
	sky.advance(SkyWeather3D.TRANSITION_SECONDS)
	# Late morning: a readable sun glint without the noon top light flattening the rings.
	view.apply_cycle_progress(0.42)

	# world_position takes logic pixels, not cells.
	var target := view.world_position(
		(Vector2(TARGET_CELL) + Vector2(0.5, 0.5)) * float(definition.cell_size), 0.0
	)
	# Gameplay projection (orthographic, fixed pitch/yaw), zoomed to the closest gameplay
	# size so a 0.25-unit texel covers ~10 px. The heading is the camera's ground direction.
	var camera := view.view_camera()
	camera.current = true
	camera.size = ORTHO_SIZE
	camera.position = target + camera.transform.basis.z * MapView3D.CAMERA_DISTANCE
	var heading := -camera.transform.basis.z
	heading = Vector3(heading.x, 0.0, heading.z).normalized()
	for raw in _uniform_overrides:
		for terrain_id in MapViewMaterials.WATER_WAVE_BASE.keys():
			MapViewMaterials.water_surface(terrain_id).set_shader_parameter(
				raw, _uniform_overrides[raw]
			)

	match _scenario:
		&"stability":
			await _run_stability(sim)
		&"clip":
			await _run_clip(viewport, camera, heading)
		&"benchmark":
			await _run_benchmark(sim, target, heading)
		_:
			for frame in WARMUP_FRAMES:
				if _scenario == &"wake":
					_drive_wake(sim, target, heading, frame)
				await process_frame
			_save(viewport.get_texture().get_image(), String(_scenario))
			if _scenario == &"wake" and not _off:
				var state := sim.state_texture().get_image()
				var stats := _state_stats(state)
				_save(_state_image(state), "wake_state")
				print("WS15_WAKE max_abs_h=%.4f max_aer=%.4f" % [stats.x, stats.y])
			quit(0)


## A hull crossing the view left to right, ending just past the look-at point so the V and
## the white water behind the stern are both in frame.
func _drive_wake(sim: WaterRippleSimScript, target: Vector3, heading: Vector3, frame: int) -> void:
	var across := Vector2(-heading.z, heading.x)
	var start := Vector2(target.x, target.z) - across * 7.5 + Vector2(heading.x, heading.z) * 2.0
	var position := start + across * WAKE_SPEED * (float(frame) / 60.0)
	sim.add_moving_body(position, across * WAKE_SPEED, WAKE_HALF_LENGTH, WAKE_HALF_BEAM)


func _run_stability(sim: WaterRippleSimScript) -> void:
	# Maximum rain regardless of the weather profile; the sky would lower it otherwise.
	var sky_hooked := sim.get_parent() as MapView3D
	sky_hooked.sky_weather().ripple_sim = null
	sim.set_rain(1.0)
	var max_h := 0.0
	var max_aer := 0.0
	var samples: Array[String] = []
	var start_frame := sim.frame_index
	while sim.frame_index - start_frame < 600:
		await process_frame
		var steps := sim.frame_index - start_frame
		if steps > 0 and steps % 60 == 0 and samples.size() < steps / 60:
			var stats := _state_stats(sim.state_texture().get_image())
			max_h = maxf(max_h, stats.x)
			max_aer = maxf(max_aer, stats.y)
			samples.append("%d:%.4f" % [steps, stats.x])
	_save(_state_image(sim.state_texture().get_image()), "stability_state")
	print(
		"WS15_STABILITY renderer=%s steps=%d max_abs_h=%.4f max_aer=%.4f checker=%.5f samples=%s"
		% [
			RenderingServer.get_current_rendering_driver_name(),
			sim.frame_index - start_frame,
			max_h,
			max_aer,
			_checkerboard(sim.state_texture().get_image()),
			",".join(samples),
		]
	)
	quit(0 if max_h < 1.0 else 1)


func _run_clip(viewport: SubViewport, camera: Camera3D, heading: Vector3) -> void:
	const FRAMES := 600
	const THUMBS := 8
	var pan := Vector3(-heading.z, 0.0, heading.x) * 12.0
	var start := camera.position
	for _frame in 60:
		await process_frame
	var thumb := Vector2i(PLATE_SIZE.x / 4, PLATE_SIZE.y / 4)
	var strip := Image.create(thumb.x * THUMBS / 2, thumb.y * 2, false, Image.FORMAT_RGBA8)
	var previous: Image
	var worst := 0.0
	for frame in FRAMES:
		camera.position = start + pan * (float(frame) / float(FRAMES))
		await process_frame
		var thumb_frame := frame % (FRAMES / THUMBS) == 0
		if frame % 4 != 0 and not thumb_frame:
			continue
		var image := viewport.get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		if frame % 4 == 0:
			if previous != null:
				worst = maxf(worst, _mean_difference(previous, image))
			previous = image
		if thumb_frame:
			var index := frame / (FRAMES / THUMBS)
			var small := image.duplicate() as Image
			small.resize(thumb.x, thumb.y, Image.INTERPOLATE_BILINEAR)
			strip.blit_rect(
				small,
				Rect2i(Vector2i.ZERO, thumb),
				Vector2i((index % (THUMBS / 2)) * thumb.x, (index / (THUMBS / 2)) * thumb.y)
			)
	_save(strip, "clip")
	print("WS15_CLIP renderer=%s frames=%d max_mean_step=%.5f" % [
		RenderingServer.get_current_rendering_driver_name(), FRAMES, worst
	])
	quit(0)


func _run_benchmark(sim: WaterRippleSimScript, target: Vector3, heading: Vector3) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for frame in 120:
		_drive_wake(sim, target, heading, frame % 240)
		await process_frame
	var start := Time.get_ticks_usec()
	for frame in BENCHMARK_FRAMES:
		_drive_wake(sim, target, heading, frame % 240)
		await process_frame
	var mean_ms := float(Time.get_ticks_usec() - start) / 1000.0 / float(BENCHMARK_FRAMES)
	print(
		"WS15_BENCHMARK renderer=%s mode=%s size=%s mean_frame_ms=%.3f"
		% [
			RenderingServer.get_current_rendering_driver_name(),
			"off" if _off else "sim",
			BENCHMARK_SIZE,
			mean_ms,
		]
	)
	quit(0)


## Baseline: stop stepping and bind the flat state so the water shader skips the ripple path.
func _detach(view: MapView3D, sim: WaterRippleSimScript) -> void:
	sim.set_process(false)
	for ripple_viewport in sim.viewports():
		ripple_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	view.sky_weather().ripple_sim = null
	view._bind_water_ripples(null, Vector4(0.0, 0.0, WaterRippleSimScript.WINDOW_WORLD_SIZE, 0.0), 1.0)


## Height field as grey (0.5 = rest, +-0.1 h = white/black) with aeration in red.
func _state_image(state: Image) -> Image:
	var image := Image.create(state.get_width(), state.get_height(), false, Image.FORMAT_RGB8)
	for y in state.get_height():
		for x in state.get_width():
			var texel := state.get_pixel(x, y)
			var grey := clampf(0.5 + texel.r * 5.0, 0.0, 1.0)
			image.set_pixel(x, y, Color(maxf(grey, texel.b), grey, grey))
	return image


## x = largest |h|, y = largest aeration over the whole state.
func _state_stats(image: Image) -> Vector2:
	var stats := Vector2.ZERO
	for y in image.get_height():
		for x in image.get_width():
			var texel := image.get_pixel(x, y)
			stats.x = maxf(stats.x, absf(texel.r))
			stats.y = maxf(stats.y, texel.b)
	return stats


## Mean |h - neighbour average| relative to mean |h|: an odd-even blow-up drives it past 1.
func _checkerboard(image: Image) -> float:
	var residual := 0.0
	var magnitude := 0.0
	for y in range(1, image.get_height() - 1):
		for x in range(1, image.get_width() - 1):
			var h := image.get_pixel(x, y).r
			var neighbours := (
				image.get_pixel(x + 1, y).r + image.get_pixel(x - 1, y).r
				+ image.get_pixel(x, y + 1).r + image.get_pixel(x, y - 1).r
			) * 0.25
			residual += absf(h - neighbours)
			magnitude += absf(h)
	return residual / maxf(magnitude, 0.000001)


func _mean_difference(a: Image, b: Image) -> float:
	var total := 0.0
	var count := 0
	for y in range(0, a.get_height(), 4):
		for x in range(0, a.get_width(), 4):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			total += (absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)) / 3.0
			count += 1
	return total / float(maxi(count, 1))


func _save(image: Image, label: String) -> void:
	var path := "%s/ws15_%s_%s%s%s.png" % [
		OUTPUT_DIR, RenderingServer.get_current_rendering_driver_name(), label,
		"_fft" if _fft else "", "_off" if _off else ""
	]
	var error := image.save_png(ProjectSettings.globalize_path(path))
	print("WS15_CAPTURE path=%s ok=%s" % [path, error == OK])
