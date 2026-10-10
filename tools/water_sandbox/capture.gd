extends SceneTree

## Water sandbox plates (docs/SYSTEMS/WATER_SANDBOX.md, R-1498 / WR-0). Needs a renderer:
##   tools/godot_render.sh --script tools/water_sandbox/capture.gd -- \
##     [--case=sand,quay] [--shot=close,side,wide,swim,open] [--light=noon,sunset,night,overcast] \
##     [--wind=calm,fresh,gale] [--rain] [--gust] [--motion=N] [--advance=S]
##     [--tier=recommended] [--size=1280x720] [--tag=x] [--dolly=M] [--bench=N]
##     [--no-obstacle-sim] [--stability=N] [--dump-obstacle] [--bench-shot=open]
## Every list argument is a comma list; the run covers the full cross product.
## Output: build/water_sandbox/<tag>/<case>_<shot>_<light>_<wind>[_rain][_gust].png plus
## sheet.png (all plates in one contact sheet). --motion=N writes N frames at 24 Hz per plate;
## --dolly=M moves the camera M metres forward (level) over those frames, so the clip
## crosses sea LOD ring boundaries (WR-3 popping check). --bench=N writes bench.json:
## mean frame time over N frames of the first case's open shot (--bench-shot picks
## another, e.g. close to time the WR-5 sim with rocks in view; with --rain / --gust
## the bench runs in rain and at the gust peak, so WR-8 costs can be compared).
## WR-5: the waves-around-rocks sim (WaterRippleSim obstacle mode) runs on the recommended
## and high tiers, its window ahead of the camera, as CityMapView mounts it; each plate
## warms it up for WARMUP_SECONDS of ocean time ending at the same sea phase as without
## it. --no-obstacle-sim keeps the plain sea for A/B plates and benches. Plates log the
## sim's CPU step and mask-raster cost; bench.json records them. --stability=N steps the
## GPU kernel N times at its longest step in a gale at the first case's close shot, then
## reads the state back into stability.json (max |height|, |velocity|, foam, NaN count).
## --dump-obstacle writes the sim state next to every plate (`*_obstacle.png`: R/G = the
## scattered height above/below rest, B = impact foam, black = solid mask texels).

const SANDBOX_PATH := "res://tools/water_sandbox/water_sandbox.gd"
const OUTPUT_ROOT := "res://build/water_sandbox"
const WIND_DIRECTION := Vector2(0.25, 1.0)
const WINDS := {"calm": 0.1, "fresh": 0.55, "gale": 0.95}
const SHEET_COLUMNS := 4
## Gust level of --gust still plates and benches (0..1, the peak of a burst).
const STILL_GUST := 1.0
const SHEET_THUMB := Vector2i(480, 270)
## Ocean seconds the obstacle sim runs before a plate (reflections need time to spread).
const WARMUP_SECONDS := 3.0
## Longest ocean-clock step per rendered frame while the obstacle sim runs (game frame rate).
const SIM_FRAME_DT := 1.0 / 60.0
## Farthest the obstacle window centre sits ahead of the camera (world units).
const OBSTACLE_FOCUS_AHEAD := 26.0

var _cases: Array = []
var _shots: Array = ["close", "side"]
var _lights: Array = ["noon"]
var _winds: Array = ["fresh"]
var _rain := false
var _gust := false
var _motion := 0
var _bench := 0
var _dolly := 0.0
var _advance := 4.0
var _tier: StringName = &"recommended"
var _tag := "now"
var _size := Vector2i(1280, 720)
var _obstacle_enabled := true
var _stability := 0
var _dump_obstacle := false
var _bench_shot := "open"
var _obstacle_sim: WaterRippleSim


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
		elif arg.begins_with("--dolly="):
			_dolly = float(value)
		elif arg.begins_with("--bench="):
			_bench = int(value)
		elif arg.begins_with("--stability="):
			_stability = int(value)
		elif arg.begins_with("--bench-shot="):
			_bench_shot = value
		elif arg == "--dump-obstacle":
			_dump_obstacle = true
		elif arg == "--no-obstacle-sim":
			_obstacle_enabled = false
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
	_create_obstacle_sim(sandbox, camera)
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
					# WR-8: a --gust still is taken at the peak of a burst, so the cat's
					# paws read in the plate and not only in the clip.
					_apply(world, float(lights[light][0]), float(WINDS[wind_name]),
						STILL_GUST if _gust else 0.0)
					if _obstacle_sim != null:
						# Warm the field up so that the plate lands on the same sea phase.
						# Moving the clock back is a jump: the sim restarts flat for this pose.
						MapViewRuntimeEnvironment.set_ocean_time(_advance - WARMUP_SECONDS)
						await _advance_clock(WARMUP_SECONDS)
					else:
						MapViewRuntimeEnvironment.set_ocean_time(_advance)
					for i in 30:
						await _advance_clock(0.05)
					await RenderingServer.frame_post_draw
					var path := "%s/%s.png" % [out_dir, name]
					viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
					plates.append(path)
					print("captured ", path)
					if _obstacle_sim != null and _dump_obstacle:
						_save_obstacle_state(path.trim_suffix(".png") + "_obstacle.png")
					if _obstacle_sim != null:
						print("  obstacle sim %dx%d: step %.1f us mean, mask raster %.1f ms (%d builds)" % [
							_obstacle_sim.sim_size, _obstacle_sim.sim_size, _obstacle_sim.step_usec_mean,
							_obstacle_sim.obstacle_mask.last_build_usec / 1000.0, _obstacle_sim.mask_builds
						])
					if _motion > 0:
						await _record(viewport, world, camera, "%s/%s_motion" % [out_dir, name],
							float(lights[light][0]), float(WINDS[wind_name]))
	_contact_sheet(plates, "%s/sheet.png" % out_dir)
	if _bench > 0:
		await _benchmark(viewport, sandbox, camera, "%s/bench.json" % out_dir)
	if _stability > 0 and _obstacle_sim != null:
		await _stability_run(sandbox, camera, "%s/stability.json" % out_dir)
	quit(0)


## WR-3: mean frame time of the first case's open shot (fresh wind, noon). Wall
## time between presented frames plus the GPU render time when the driver reports
## it; the sea vertex count is the deterministic part of the comparison.
func _benchmark(viewport: SubViewport, sandbox: Node3D, camera: Camera3D, out: String) -> void:
	var world: Node3D = sandbox.world
	var pose: Array = sandbox.shots_for(String(_cases[0]))[_bench_shot]
	camera.fov = pose[2]
	camera.look_at_from_position(pose[0], pose[1], Vector3.UP)
	world.sky_weather.set_weather(SkyWeather3D.WEATHER_RAIN if _rain else SkyWeather3D.WEATHER_CLEAR)
	world.sky_weather.advance(SkyWeather3D.TRANSITION_SECONDS + 0.1)
	_apply(world, 0.5, float(WINDS["fresh"]), STILL_GUST if _gust else 0.0)
	var rid := viewport.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	for i in 30:
		MapViewRuntimeEnvironment.advance_ocean_time(1.0 / 60.0)
		await RenderingServer.frame_post_draw
	var wall: Array[float] = []
	var gpu: Array[float] = []
	var last := Time.get_ticks_usec()
	for i in _bench:
		MapViewRuntimeEnvironment.advance_ocean_time(1.0 / 60.0)
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		wall.append(float(now - last) / 1000.0)
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		last = now
	wall.sort()
	gpu.sort()
	var report := {
		"tier": String(_tier),
		"rain": _rain,
		"gust": _gust,
		"case": String(_cases[0]),
		"shot": _bench_shot,
		"frames": _bench,
		"wall_ms_mean": _mean(wall),
		"wall_ms_median": wall[wall.size() / 2],
		"gpu_ms_mean": _mean(gpu),
		"sea_vertices": _sea_vertices(world),
		"obstacle_sim_size": _obstacle_sim.sim_size if _obstacle_sim != null else 0,
		"obstacle_step_usec_mean": _obstacle_sim.step_usec_mean if _obstacle_sim != null else 0.0,
		"obstacle_mask_build_usec": (
			_obstacle_sim.obstacle_mask.last_build_usec if _obstacle_sim != null else 0
		),
	}
	var file := FileAccess.open(ProjectSettings.globalize_path(out), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	print("water sandbox bench: ", JSON.stringify(report))


static func _mean(values: Array[float]) -> float:
	var total := 0.0
	for v in values:
		total += v
	return total / maxf(float(values.size()), 1.0)


## Vertices the sea submits per frame: every mesh under the Water node, with a
## MultiMesh counted once per visible instance.
static func _sea_vertices(world: Node3D) -> int:
	var water := world.get_node_or_null("Water")
	if water == null:
		return 0
	var total := 0
	for node in water.find_children("*", "GeometryInstance3D", true, false):
		if node is MeshInstance3D and (node as MeshInstance3D).mesh is ArrayMesh:
			var mesh := (node as MeshInstance3D).mesh as ArrayMesh
			for s in mesh.get_surface_count():
				total += mesh.surface_get_array_len(s)
		elif node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh != null:
			var multi := (node as MultiMeshInstance3D).multimesh
			if multi.mesh is ArrayMesh:
				var count := multi.visible_instance_count
				if count < 0:
					count = multi.instance_count
				total += (multi.mesh as ArrayMesh).surface_get_array_len(0) * count
	return total


## Moves the ocean clock by `seconds` over rendered frames. Without the obstacle sim this
## is one frame, as before. With it the clock moves in steps of at most SIM_FRAME_DT, one
## rendered frame each: the sim steps once per frame, and at a capture's 1/24 s or 1/20 s
## its CFL cap (0.25 m texels on high) would slow the waves the game shows at 60 fps.
func _advance_clock(seconds: float) -> void:
	var steps := 1 if _obstacle_sim == null else maxi(ceili(seconds / SIM_FRAME_DT - 0.001), 1)
	for i in steps:
		MapViewRuntimeEnvironment.advance_ocean_time(seconds / float(steps))
		await process_frame


## WR-5: N GPU steps of the obstacle kernel at OBSTACLE_DT_MAX in a gale, then a state
## readback (a tool-only readback; the runtime never reads the sim back).
func _stability_run(sandbox: Node3D, camera: Camera3D, out: String) -> void:
	var pose: Array = sandbox.shots_for(String(_cases[0]))["close"]
	camera.fov = pose[2]
	camera.look_at_from_position(pose[0], pose[1], Vector3.UP)
	_apply(sandbox.world, 0.5, float(WINDS["gale"]), 0.0)
	var peak := Vector3.ZERO
	var report := {"steps": _stability, "case": String(_cases[0]), "checkpoints": []}
	for i in _stability:
		MapViewRuntimeEnvironment.advance_ocean_time(WaterRippleSim.OBSTACLE_DT_MAX)
		await RenderingServer.frame_post_draw
		if (i + 1) % 250 == 0 or i == _stability - 1:
			var stats := _state_stats(_obstacle_sim.state_texture().get_image())
			peak = peak.max(Vector3(stats["max_height"], stats["max_velocity"], stats["max_foam"]))
			stats["step"] = i + 1
			(report["checkpoints"] as Array).append(stats)
			print("stability step %d: %s" % [i + 1, JSON.stringify(stats)])
	report["peak"] = {"max_height": peak.x, "max_velocity": peak.y, "max_foam": peak.z}
	report["step_usec_mean"] = _obstacle_sim.step_usec_mean
	var file := FileAccess.open(ProjectSettings.globalize_path(out), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))


## Tool-only readback of the obstacle state for review: heights at 0.5 units full scale.
func _save_obstacle_state(out: String) -> void:
	var state := _obstacle_sim.state_texture().get_image()
	var mask := _obstacle_sim.mask_texture().get_image()
	var offset := _obstacle_sim.mask_offset()
	var view := Image.create_empty(state.get_width(), state.get_height(), false, Image.FORMAT_RGB8)
	for j in state.get_height():
		for i in state.get_width():
			var c := state.get_pixel(i, j)
			var solid := mask.get_pixel(i + offset.x, j + offset.y).r <= CityObstacleMask.SOLID_DEPTH
			if solid:
				view.set_pixel(i, j, Color(0.0, 0.0, 0.0))
				continue
			var h := clampf(c.r / 0.5, -1.0, 1.0)
			view.set_pixel(i, j, Color(maxf(h, 0.0), maxf(-h, 0.0), clampf(c.b, 0.0, 1.0)))
	view.resize(state.get_width() * 2, state.get_height() * 2, Image.INTERPOLATE_NEAREST)
	view.save_png(ProjectSettings.globalize_path(out))
	print("  obstacle state ", out)


static func _state_stats(image: Image) -> Dictionary:
	var stats := {"max_height": 0.0, "max_velocity": 0.0, "max_foam": 0.0, "nan": 0}
	for j in image.get_height():
		for i in image.get_width():
			var c := image.get_pixel(i, j)
			if is_nan(c.r) or is_nan(c.g) or is_nan(c.b) or is_inf(c.r) or is_inf(c.g):
				stats["nan"] += 1
				continue
			stats["max_height"] = maxf(stats["max_height"], absf(c.r))
			stats["max_velocity"] = maxf(stats["max_velocity"], absf(c.g))
			stats["max_foam"] = maxf(stats["max_foam"], c.b)
	return stats


## WR-5: the waves-around-rocks sim as CityMapView mounts it (sea LOD tier, the sea
## material's swell, the sandbox's bathymetry and rocks). Off with --no-obstacle-sim or
## on the minimum tier, where the sea keeps obstacle_window.w = 0.
func _create_obstacle_sim(sandbox: Node3D, camera: Camera3D) -> void:
	var sea := MapViewMaterials.water_surface(MapTypes.TERRAIN_SHALLOW_WATER)
	var tier := MapViewMaterials.WATER_MATERIALS.sea_lod_tier()
	var size := WaterRippleSim.obstacle_sim_size_for_tier(tier)
	if not _obstacle_enabled or size <= 0:
		var off := Vector4(0.0, 0.0, WaterRippleSim.WINDOW_WORLD_SIZE, 0.0)
		sea.set_shader_parameter(&"obstacle_window", off)
		return
	_obstacle_sim = WaterRippleSim.new()
	_obstacle_sim.name = "WaterObstacleSim"
	sandbox.add_child(_obstacle_sim)
	_obstacle_sim.configure_obstacles(size, sandbox.obstacle_mask(), sea)
	_obstacle_sim.focus_provider = func() -> Vector3:
		return _obstacle_focus(camera)
	_obstacle_sim.bind_callback = func(texture: Texture2D, window: Vector4, texels: float) -> void:
		sea.set_shader_parameter(&"obstacle_state", texture)
		sea.set_shader_parameter(&"obstacle_window", window)
		sea.set_shader_parameter(&"obstacle_texel_count", texels)


## Where the camera's view meets the sea, at most OBSTACLE_FOCUS_AHEAD ahead (level).
static func _obstacle_focus(camera: Camera3D) -> Vector3:
	var origin := camera.global_position
	var forward := -camera.global_transform.basis.z
	var flat := Vector2(forward.x, forward.z)
	if flat.length() < 0.01:
		return origin
	var reach := OBSTACLE_FOCUS_AHEAD
	if forward.y < -0.01:
		reach = minf(reach, origin.y / -forward.y * flat.length())
	var ahead := flat.normalized() * reach
	return origin + Vector3(ahead.x, 0.0, ahead.y)


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
	world.mirror_shore_to_ground()
	world.set_wind(WIND_DIRECTION)
	if _obstacle_sim != null:
		_obstacle_sim.foam_wind = WIND_DIRECTION.normalized() * strength
	if world.spray != null:
		world.spray.set_wind(strength)
	var ground := CityTerrainBuilder.shared_material()
	if ground != null:
		ground.set_shader_parameter("rain_intensity", rain)
		ground.set_shader_parameter("wetness", rain * 0.6)


## 24 Hz frames. With --gust the wind follows a deterministic gust envelope:
## two bursts of different strength, each rising over ~1.5 s and dying away.
func _record(
	viewport: SubViewport, world: Node3D, camera: Camera3D, dir: String, progress: float,
	wind: float
) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var start := camera.global_transform
	var forward := -start.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	for i in _motion:
		if _dolly != 0.0:
			camera.global_position = start.origin + forward * _dolly * float(i) / maxf(_motion - 1, 1)
		var t := float(i) / 24.0
		if _gust:
			var burst := exp(-pow((t - 2.0) / 1.2, 2.0)) + 0.6 * exp(-pow((t - 6.0) / 0.8, 2.0))
			_apply(world, progress, wind, burst)
		await _advance_clock(1.0 / 24.0)
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(
			ProjectSettings.globalize_path("%s/%04d.png" % [dir, i])
		)
	camera.global_transform = start


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
