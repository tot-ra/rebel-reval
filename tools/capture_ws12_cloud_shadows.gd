extends SceneTree

## WS-12 / R-1033 GPU evidence. One plate or strip per process; needs a real
## renderer through the minimized wrapper:
##   tools/godot_render.sh --rendering-method mobile --rendering-driver metal \
##     --script tools/capture_ws12_cloud_shadows.gd -- --scenario=partly
## Compatibility: `--rendering-driver opengl3`.
##
## Modes:
##   --scenario=partly|overcast|night
##       gameplay-camera harbour plate on reval_harbor_north.
##       partly = clear noon with cloud_coverage forced to 0.45
##   --clip     20 s partly-cloudy contact strip (10 frames, 2 s of cloud drift)
##   --sky --elevation=<deg> --weather=clear|overcast|storm
##       WS-10-style horizon sky sheet (toward / away from the sun)
##   --bench    1080p pass on vs off wall-clock delta (vsync off)
##   --no-pass  hide CloudShadowOverlay for A/B plates
## Output: docs/reports/images/ws12_<renderer>_*.png

const MapAuditRegistry := preload("res://scripts/map/map_audit_registry.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapTypesContract := preload("res://scripts/map/map_types.gd")
const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")
const SkyWeather3D := preload("res://scripts/map/view3d/sky_weather_3d.gd")

const MAP_ID := "reval_harbor_north"
const OUTPUT_DIR := "res://docs/reports/images"
const PLATE_SIZE := Vector2i(1280, 720)
const SKY_HALF := Vector2i(960, 540)
const BENCH_SIZE := Vector2i(1920, 1080)
const WARMUP_FRAMES := 60
const BENCH_WARMUP := 40
const BENCH_FRAMES := 240
## Gameplay third-person ortho size used by the default camera zoom.
const GAMEPLAY_ORTHO := 33.75
const PARTLY_COVERAGE := 0.45
const CLIP_FRAMES := 10
const CLIP_STEP_S := 2.0
const CAPTURE_DATE := {"day": 21, "month": 6, "year": 1343}
const SKY_HEIGHT := 4.0
const SKY_PITCH_DEG := 16.0
const SKY_FOV := 80.0
const SCENARIOS := {
	&"partly": {"weather": &"clear", "progress": 0.5, "coverage": PARTLY_COVERAGE},
	&"overcast": {"weather": &"overcast", "progress": 0.5, "coverage": -1.0},
	&"night": {"weather": &"clear", "progress": 0.0, "coverage": -1.0},
}
const SKY_WEATHERS := [&"clear", &"overcast", &"storm"]


var _scenario := &"partly"
var _clip := false
var _sky := false
var _bench := false
var _no_pass := false
var _elevation := 20.0
var _weather := &"clear"


func _initialize() -> void:
	for raw in OS.get_cmdline_user_args():
		var argument := String(raw)
		if argument.begins_with("--scenario="):
			_scenario = StringName(argument.trim_prefix("--scenario="))
		elif argument.begins_with("--elevation="):
			_elevation = float(argument.trim_prefix("--elevation="))
		elif argument.begins_with("--weather="):
			_weather = StringName(argument.trim_prefix("--weather="))
		elif argument == "--clip":
			_clip = true
		elif argument == "--sky":
			_sky = true
		elif argument == "--bench":
			_bench = true
		elif argument == "--no-pass":
			_no_pass = true
		else:
			push_error("WS-12 capture: unknown argument %s" % argument)
			quit(1)
			return
	if not SCENARIOS.has(_scenario):
		push_error("WS-12 capture: unsupported scenario")
		quit(1)
		return
	if not SKY_WEATHERS.has(_weather):
		push_error("WS-12 capture: unsupported sky weather")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("WS-12 capture needs a real renderer")
		quit(2)
		return
	var definition: MapDefinition = MapAuditRegistry.by_id().get(MAP_ID)
	MapViewMaterials.WATER_MATERIALS.force_ocean_fft_support = true
	MapViewMaterials.reset()
	var host: Viewport = root
	if _sky:
		# Sky-parity plates hide the ground pass, so a SubViewport is safe.
		var nested := SubViewport.new()
		nested.size = Vector2i(SKY_HALF.x * 2, SKY_HALF.y)
		nested.own_world_3d = true
		nested.msaa_3d = Viewport.MSAA_4X
		nested.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(nested)
		host = nested
	else:
		# WHY: CloudShadowPass samples hint_screen_texture. A nested
		# SubViewport binds a default buffer, so Metal plates went beige and
		# Compatibility plates were RGB noise. The root window is the play path.
		DisplayServer.window_set_size(BENCH_SIZE if _bench else PLATE_SIZE)
	var grid := MapBuilder.build(definition)
	var view := MapView3D.create(definition, grid, MapView3D.TIME_DAY)
	host.add_child(view)
	var fog := view.find_child("FogOfWar", true, false) as Node3D
	if fog != null:
		fog.visible = false
	if _sky:
		await _run_sky(view, host, grid)
		return
	if _bench:
		await _run_bench(view, host, grid)
		return
	await _run_harbour(view, host, grid)
	quit(0)


func _run_harbour(view: MapView3D, viewport: Viewport, grid: MapTerrainGrid) -> void:
	var spec: Dictionary = SCENARIOS[_scenario]
	var sky := view.sky_weather()
	view.set_calendar_date(CAPTURE_DATE)
	view.set_weather_time_scale(0.0)
	sky.auto_weather = false
	sky.set_weather(spec["weather"])
	sky.advance(SkyWeather3D.TRANSITION_SECONDS)
	view.apply_cycle_progress(float(spec["progress"]))
	_aim_gameplay(view, grid)
	_sync_share(view)
	# Stop MapView3D._process so update_share cannot re-show the overlay
	# after --no-pass, and so still plates stay on a frozen clock.
	view.set_process(false)
	_set_pass_visible(view, not _no_pass)
	for _frame in WARMUP_FRAMES:
		_apply_scenario(view, spec)
		await process_frame
	if _clip:
		await _write_clip(view, viewport, spec)
		return
	_apply_scenario(view, spec)
	await process_frame
	await process_frame
	var suffix := "_nopass" if _no_pass else ""
	_save(
		viewport.get_texture().get_image(),
		"ws12_%s_%s_harbour%s.png" % [
			_driver(), String(_scenario), suffix
		]
	)
	_print_state(view, spec)


func _write_clip(view: MapView3D, viewport: Viewport, spec: Dictionary) -> void:
	var thumb := Vector2i(PLATE_SIZE.x / 5, PLATE_SIZE.y / 2)
	var strip := Image.create(thumb.x * 5, thumb.y * 2, false, Image.FORMAT_RGBA8)
	var sky := view.sky_weather()
	for index in CLIP_FRAMES:
		# WHY: keep lighting frozen at noon and only step the shared cloud
		# offset so the strip shows downwind patch motion, not a day cycle.
		sky.advance(CLIP_STEP_S)
		_apply_scenario(view, spec)
		await process_frame
		await process_frame
		var frame := viewport.get_texture().get_image()
		frame.convert(Image.FORMAT_RGBA8)
		frame.resize(thumb.x, thumb.y, Image.INTERPOLATE_BILINEAR)
		var at := Vector2i((index % 5) * thumb.x, (index / 5) * thumb.y)
		strip.blit_rect(frame, Rect2i(Vector2i.ZERO, thumb), at)
	_save(strip, "ws12_%s_partly_harbour_clip.png" % _driver())
	print(
		"WS12_CLIP frames=%d step_s=%.1f coverage=%.2f" % [
			CLIP_FRAMES, CLIP_STEP_S, PARTLY_COVERAGE
		]
	)


func _run_sky(view: MapView3D, viewport: Viewport, grid: MapTerrainGrid) -> void:
	var sky := view.sky_weather()
	view.set_calendar_date(CAPTURE_DATE)
	view.set_weather_time_scale(0.0)
	sky.auto_weather = false
	sky.set_weather(_weather)
	sky.advance(SkyWeather3D.TRANSITION_SECONDS)
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
	# Sky-parity plates must not include the ground pass: the include peel is
	# a dome-only identity check.
	_set_pass_visible(view, false)
	var camera := view.view_camera()
	camera.current = true
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = SKY_FOV
	camera.far = 4000.0
	var origin := view.world_position(
		Vector2(_open_water_cell(grid)) + Vector2(0.5, 0.5), SKY_HEIGHT
	)
	var halves: Array[Image] = []
	for toward_sun in [true, false]:
		var flat := Vector3(azimuth.x, 0.0, azimuth.y) * (1.0 if toward_sun else -1.0)
		var look := flat * cos(deg_to_rad(SKY_PITCH_DEG))
		look.y = sin(deg_to_rad(SKY_PITCH_DEG))
		camera.look_at_from_position(origin, origin + look, Vector3.UP)
		for _frame in WARMUP_FRAMES:
			sky.apply_sky_state(progress, day_blend, sun_dir)
			_set_pass_visible(view, false)
			await process_frame
		var half := viewport.get_texture().get_image()
		half = half.get_region(Rect2i(Vector2i.ZERO, SKY_HALF))
		halves.append(half)
	var sheet := Image.create(SKY_HALF.x * 2, SKY_HALF.y, false, halves[0].get_format())
	sheet.blit_rect(halves[0], Rect2i(Vector2i.ZERO, SKY_HALF), Vector2i.ZERO)
	sheet.blit_rect(halves[1], Rect2i(Vector2i.ZERO, SKY_HALF), Vector2i(SKY_HALF.x, 0))
	var elev_label := str(int(_elevation)).replace("-", "m")
	_save(
		sheet,
		"ws12_%s_%s_sky_e%s.png" % [_driver(), String(_weather), elev_label]
	)
	quit(0)


func _run_bench(view: MapView3D, _viewport: Viewport, grid: MapTerrainGrid) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var spec: Dictionary = SCENARIOS[&"partly"]
	var sky := view.sky_weather()
	view.set_calendar_date(CAPTURE_DATE)
	view.set_weather_time_scale(0.0)
	sky.auto_weather = false
	sky.set_weather(spec["weather"])
	sky.advance(SkyWeather3D.TRANSITION_SECONDS)
	view.apply_cycle_progress(float(spec["progress"]))
	_aim_gameplay(view, grid)
	for _warm in BENCH_WARMUP:
		_apply_scenario(view, spec)
		await process_frame
	var on_ms := await _mean_frame_ms(view, spec, true)
	var off_ms := await _mean_frame_ms(view, spec, false)
	print(
		"WS12_BENCH renderer=%s size=%s on_ms=%.3f off_ms=%.3f delta_ms=%.3f" % [
			_driver(), BENCH_SIZE, on_ms, off_ms, on_ms - off_ms
		]
	)
	quit(0)


func _mean_frame_ms(view: MapView3D, spec: Dictionary, pass_on: bool) -> float:
	_set_pass_visible(view, pass_on)
	for _warm in 20:
		_apply_scenario(view, spec)
		await process_frame
	var start := Time.get_ticks_usec()
	for _frame in BENCH_FRAMES:
		_apply_scenario(view, spec)
		await process_frame
	return float(Time.get_ticks_usec() - start) / 1000.0 / float(BENCH_FRAMES)


func _aim_gameplay(view: MapView3D, _grid: MapTerrainGrid) -> void:
	# Same harbour cell as tools/capture_ws02_glint.gd: boats, shore and a
	# water wedge the gameplay camera actually sees.
	var target := view.world_position(Vector2(80.5, 24.5) * float(view.definition.cell_size), 0.0)
	var camera := view.view_camera()
	camera.current = true
	camera.size = GAMEPLAY_ORTHO
	camera.position = target + camera.transform.basis.z * MapView3D.CAMERA_DISTANCE


func _apply_scenario(view: MapView3D, spec: Dictionary) -> void:
	MapViewRuntimeEnvironment.set_ocean_time(6.0)
	view.apply_cycle_progress(float(spec["progress"]))
	_sync_share(view)
	var coverage := float(spec["coverage"])
	if coverage >= 0.0:
		_force_coverage(view, coverage)
	if _no_pass:
		_set_pass_visible(view, false)


func _sync_share(view: MapView3D) -> void:
	var sky := view.sky_weather()
	var shadow_pass: Node = view.cloud_shadow_pass()
	if sky == null or shadow_pass == null:
		return
	var day_blend := SkyWeather3D.daylight_blend(float(view.cycle_progress), sky.calendar_date)
	shadow_pass.call(
		&"update_share", sky.presentation_snapshot(float(view.cycle_progress), day_blend)
	)
	# The pass always writes ALPHA=1 from hint_screen_texture. When share is
	# ~0, hide the overlay so overcast/night plates are the real scene.
	if float(shadow_pass.get("sun_share")) <= 0.01:
		_set_pass_visible(view, false)


func _force_coverage(view: MapView3D, coverage: float) -> void:
	# Capture-only override. SkyWeather3D has no public setter; the pass and
	# the dome both read these uniforms after each weather push.
	RenderingServer.global_shader_parameter_set(&"cloud_coverage_g", coverage)
	var sky := view.sky_weather()
	var material: ShaderMaterial = sky._material
	if material != null:
		material.set_shader_parameter(&"cloud_coverage", coverage)


func _set_pass_visible(view: MapView3D, visible: bool) -> void:
	var shadow_pass: Node = view.cloud_shadow_pass()
	if shadow_pass == null:
		return
	var overlay := shadow_pass.find_child("CloudShadowOverlay", true, false) as MeshInstance3D
	if overlay != null:
		overlay.visible = visible
		var mesh := overlay.mesh as PrimitiveMesh
		var material: ShaderMaterial = mesh.material as ShaderMaterial if mesh != null else null
		if material != null and not visible:
			material.set_shader_parameter(&"sun_share", 0.0)


func _print_state(view: MapView3D, spec: Dictionary) -> void:
	var shadow_pass: Node = view.cloud_shadow_pass()
	var share := 0.0
	if shadow_pass != null and shadow_pass.get("sun_share") != null:
		share = float(shadow_pass.get("sun_share"))
	print(
		"WS12_STATE scenario=%s progress=%.3f coverage=%.2f sun_share=%.3f pass=%s" % [
			_scenario,
			float(spec["progress"]),
			float(spec["coverage"]),
			share,
			shadow_pass != null,
		]
	)


func _morning_progress_for(target_deg: float) -> float:
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
	var best := Vector2i(grid.size_cells.x / 2, grid.size_cells.y / 2)
	var best_score := -1
	for y in range(4, grid.size_cells.y - 4, 3):
		for x in range(4, grid.size_cells.x - 4, 3):
			var score := 0
			for dy in range(-4, 5, 2):
				for dx in range(-4, 5, 2):
					if MapTypesContract.WATER_TERRAINS.has(
						grid.get_terrain(Vector2i(x + dx, y + dy))
					):
						score += 1
			if score > best_score:
				best_score = score
				best = Vector2i(x, y)
	return best


func _driver() -> String:
	return RenderingServer.get_current_rendering_driver_name()


func _save(image: Image, filename: String) -> void:
	var path := "%s/%s" % [OUTPUT_DIR, filename]
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("WS-12 capture: could not save %s" % path)
		quit(1)
		return
	print("WS12_CAPTURED %s" % path)
