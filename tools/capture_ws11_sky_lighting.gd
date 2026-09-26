extends SceneTree

## WS-11 evidence: sky-driven sun, ambient, fog and water reflection over reval_harbor_north.
## One plate per process, through the real runtime path (MapView3D.apply_cycle_progress), so
## the DirectionalLight, ambient, fog and water all take the AtmosphereCpu colours. 2x2 sheet:
## top row the gameplay camera over the open harbour and over the quay (walls, shadows, sea
## reflection as the player sees it); bottom row a low perspective view along the sea towards
## the sun (disk, glitter, warm horizon in the water) and away from it (sun-lit walls and the
## Earth-shadow band mirrored in the sea).
## Needs a real renderer:
##   tools/godot_render.sh [--rendering-method mobile --rendering-driver metal] \
##     --script tools/capture_ws11_sky_lighting.gd -- --elevation=2 [--weather=clear]
## Options:
##   --elevation=<deg>   evening sun elevation (bisected on the capture date; the noon
##                       culmination is used when the target is higher than it)
##   --weather=<preset>  clear|cloudy|overcast|rain|storm (default clear)
##   --first-light       3 May 1343 at sunrise, a fog-prone morning: the mist plate
##   --legacy            disable AtmosphereCpu (missing-LUT fallback) for before/after pairs;
##                       the WS-10 dome and water LUT stay on
##   --day-sweep         60 s compressed day at 60 fps; prints the largest frame-to-frame
##                       change of the sun and ambient colours and saves a thumbnail strip
## Output: docs/reports/images/ws11_<renderer>_<weather>_<label>[_legacy].png

const MapAuditRegistry := preload("res://scripts/map/map_audit_registry.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapTypesContract := preload("res://scripts/map/map_types.gd")
const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")
const MapViewMaterialsScript := preload("res://scripts/map/view3d/map_view_materials.gd")
const MapViewRuntimeEnvironmentScript := preload(
	"res://scripts/map/view3d/map_view_runtime_environment.gd"
)
const SkyWeather3D := preload("res://scripts/map/view3d/sky_weather_3d.gd")
const Atmosphere := preload("res://scripts/map/view3d/atmosphere_cpu.gd")

const MAP_ID := "reval_harbor_north"
const OUTPUT_DIR := "res://docs/reports/images"
const HALF_SIZE := Vector2i(960, 540)
const PLATE_SIZE := Vector2i(1280, 720)
## Gameplay framing shared with tools/capture_ws02_glint.gd.
const GAMEPLAY_FOCUS: Array[Vector2] = [Vector2(80.5, 24.5), Vector2(70.0, 30.0)]
const GAMEPLAY_ORTHO_SIZE := 28.0
const WARMUP_FRAMES := 45
const CAMERA_HEIGHT := 6.0
const CAMERA_PITCH_DEG := 6.0
const CAMERA_FOV := 75.0
const SUMMER_DATE := {"day": 21, "month": 6, "year": 1343}
## R-908/R-911 fog-prone morning.
const MIST_DATE := {"day": 3, "month": 5, "year": 1343}

var _elevation := 10.0
var _weather := &"clear"
var _first_light := false
var _legacy := false
var _day_sweep := false


func _initialize() -> void:
	for raw in OS.get_cmdline_user_args():
		var argument := String(raw)
		if argument.begins_with("--elevation="):
			_elevation = float(argument.trim_prefix("--elevation="))
		elif argument.begins_with("--weather="):
			_weather = StringName(argument.trim_prefix("--weather="))
		elif argument == "--first-light":
			_first_light = true
		elif argument == "--legacy":
			_legacy = true
		elif argument == "--day-sweep":
			_day_sweep = true
		else:
			push_error("WS-11 capture: unknown argument %s" % argument)
			quit(1)
			return
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("WS-11 capture needs a real renderer")
		quit(2)
		return
	if _legacy:
		Atmosphere.load_luts("res://missing/transmittance.exr", "res://missing/multiscatter.exr")
	var date: Dictionary = MIST_DATE if _first_light else SUMMER_DATE
	var definition: MapDefinition = MapAuditRegistry.by_id().get(MAP_ID)
	MapViewMaterialsScript.WATER_MATERIALS.force_ocean_fft_support = true
	MapViewMaterialsScript.reset()
	var viewport := SubViewport.new()
	viewport.size = HALF_SIZE
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
	view.set_calendar_date(date)
	view.set_weather_time_scale(0.0)
	sky.auto_weather = false
	sky.set_weather(_weather)
	sky.advance(SkyWeather3D.TRANSITION_SECONDS)
	view.set_process(false)
	# The low perspective shots sit near the waterline; the WS-13 lens pass is not under test.
	if view.underwater_pass() != null:
		view.underwater_pass().visible = false
	var camera := view.view_camera()
	camera.current = true
	var gameplay_transform := camera.transform
	var gameplay_projection := camera.projection
	if _day_sweep:
		await _run_day_sweep(view, viewport, camera, definition)
		return

	var progress: float
	var label: String
	if _first_light:
		progress = float(SkyWeather3D.sunrise_sunset_hours(date)["sunrise"]) / 24.0
		label = "first_light_mist"
	else:
		progress = _evening_progress_for(_elevation, date)
		label = "e%s" % str(int(_elevation)).replace("-", "m")
	var sun_dir := SkyWeather3D.solar_direction(progress, date)
	var azimuth := Vector2(sun_dir.x, sun_dir.z).normalized()
	var panels: Array[Image] = []
	for focus in GAMEPLAY_FOCUS:
		camera.projection = gameplay_projection
		camera.transform = gameplay_transform
		camera.size = GAMEPLAY_ORTHO_SIZE
		var target := view.world_position(focus * float(definition.cell_size), 0.0)
		camera.position = target + camera.transform.basis.z * MapView3D.CAMERA_DISTANCE
		panels.append(await _render(view, viewport, progress))
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = CAMERA_FOV
	camera.far = 4000.0
	var water_cell := Vector2(_open_water_cell(grid)) + Vector2(0.5, 0.5)
	var origin := view.world_position(water_cell, CAMERA_HEIGHT)
	for toward_sun: bool in [true, false]:
		var flat := Vector3(azimuth.x, 0.0, azimuth.y) * (1.0 if toward_sun else -1.0)
		var look := flat * cos(deg_to_rad(CAMERA_PITCH_DEG))
		look.y = -sin(deg_to_rad(CAMERA_PITCH_DEG))
		camera.look_at_from_position(origin, origin + look, Vector3.UP)
		panels.append(await _render(view, viewport, progress))
	var sheet := Image.create(HALF_SIZE.x * 2, HALF_SIZE.y * 2, false, panels[0].get_format())
	for i in panels.size():
		var at := Vector2i((i % 2) * HALF_SIZE.x, (i / 2) * HALF_SIZE.y)
		sheet.blit_rect(panels[i], Rect2i(Vector2i.ZERO, HALF_SIZE), at)
	# docs/ASSET_STORAGE_POLICY.md: active evidence plates are 1280x720.
	sheet.resize(PLATE_SIZE.x, PLATE_SIZE.y, Image.INTERPOLATE_LANCZOS)
	var renderer := RenderingServer.get_current_rendering_driver_name()
	var path := "%s/ws11_%s_%s_%s%s.png" % [
		OUTPUT_DIR, renderer, String(_weather), label, "_legacy" if _legacy else ""
	]
	var error := sheet.save_png(ProjectSettings.globalize_path(path))
	var environment := _environment(view)
	var day_blend := SkyWeather3D.daylight_blend(progress, date)
	var presentation := sky.presentation_snapshot(progress, day_blend)
	var disk := Atmosphere.sun_color_for(sun_dir).linear_to_srgb()
	print(
		(
			"WS11_CAPTURE path=%s ok=%s elevation=%.2f physical=%s sun_light=%s (hue %.1f)"
			+ " sun_disk_T=%s (hue %.1f) water_sun=%s ambient=%s fog_on=%s fog=%s"
		)
		% [
			path,
			error == OK,
			SkyWeather3D.solar_elevation_degrees(progress, date),
			presentation.atmosphere_available,
			view.sun_light().light_color,
			view.sun_light().light_color.h * 360.0,
			disk,
			disk.h * 360.0,
			presentation.sun_reflection_color,
			environment.ambient_light_color,
			environment.fog_enabled,
			environment.fog_light_color,
		]
	)
	quit(0 if error == OK else 1)


## One compressed day (3600 frames = 60 s at 60 fps) at the runtime cadence. Frame time is
## faked at 1/60 s by holding each frame for that long, so the 4 Hz throttle and the smoothing
## filter see the same real-time spacing as play.
func _run_day_sweep(
	view: MapView3D, viewport: SubViewport, camera: Camera3D, definition: MapDefinition
) -> void:
	const FRAMES := 3600
	const THUMBS := 12
	camera.size = GAMEPLAY_ORTHO_SIZE
	var target := view.world_position(GAMEPLAY_FOCUS[1] * float(definition.cell_size), 0.0)
	camera.position = target + camera.transform.basis.z * MapView3D.CAMERA_DISTANCE
	var environment := _environment(view)
	var thumb_size := Vector2i(HALF_SIZE.x / 4, HALF_SIZE.y / 4)
	var strip := Image.create(thumb_size.x * THUMBS / 2, thumb_size.y * 2, false, Image.FORMAT_RGBA8)
	var worst_sun := 0.0
	var worst_ambient := 0.0
	var worst_at := 0.0
	var previous_sun := Color.BLACK
	var previous_ambient := Color.BLACK
	for frame in FRAMES:
		var progress := float(frame) / float(FRAMES)
		var frame_start := Time.get_ticks_usec()
		view.apply_cycle_progress(progress)
		await process_frame
		while Time.get_ticks_usec() - frame_start < 16_667:
			OS.delay_usec(500)
		var sun := view.sun_light().light_color
		var ambient := environment.ambient_light_color
		if frame > 0:
			var sun_step := _distance(sun, previous_sun)
			var ambient_step := _distance(ambient, previous_ambient)
			if sun_step > worst_sun:
				worst_sun = sun_step
				worst_at = progress
			worst_ambient = maxf(worst_ambient, ambient_step)
		previous_sun = sun
		previous_ambient = ambient
		if frame % (FRAMES / THUMBS) == 0:
			var index := frame / (FRAMES / THUMBS)
			var image := viewport.get_texture().get_image()
			image.convert(Image.FORMAT_RGBA8)
			image.resize(thumb_size.x, thumb_size.y, Image.INTERPOLATE_BILINEAR)
			var at := Vector2i((index % (THUMBS / 2)) * thumb_size.x, (index / (THUMBS / 2)) * thumb_size.y)
			strip.blit_rect(image, Rect2i(Vector2i.ZERO, thumb_size), at)
	var renderer := RenderingServer.get_current_rendering_driver_name()
	var path := "%s/ws11_%s_day_sweep%s.png" % [OUTPUT_DIR, renderer, "_legacy" if _legacy else ""]
	var error := strip.save_png(ProjectSettings.globalize_path(path))
	print(
		"WS11_DAY_SWEEP path=%s ok=%s max_sun_step=%.4f at_progress=%.4f max_ambient_step=%.4f"
		% [path, error == OK, worst_sun, worst_at, worst_ambient]
	)
	quit(0 if error == OK else 1)


func _render(view: MapView3D, viewport: SubViewport, progress: float) -> Image:
	for _frame in WARMUP_FRAMES:
		MapViewRuntimeEnvironmentScript.set_ocean_time(6.0)
		view.apply_cycle_progress(progress)
		await process_frame
	var image := viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image


func _environment(view: MapView3D) -> Environment:
	var world_env := view.get_node("ViewEnvironment") as WorldEnvironment
	return world_env.environment


static func _distance(a: Color, b: Color) -> float:
	return maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), absf(a.b - b.b))


func _evening_progress_for(target_deg: float, date: Dictionary) -> float:
	# Bisection between noon and midnight, where the elevation falls monotonically.
	if SkyWeather3D.solar_elevation_degrees(0.5, date) <= target_deg:
		return 0.5
	var lo := 0.5
	var hi := 1.0
	for _i in 40:
		var mid := (lo + hi) * 0.5
		if SkyWeather3D.solar_elevation_degrees(mid, date) > target_deg:
			lo = mid
		else:
			hi = mid
	return (lo + hi) * 0.5


func _open_water_cell(grid: MapTerrainGrid) -> Vector2i:
	# Water cell nearest to the land edge that still has open water around it, so the view
	# away from the sun shows the quay and walls across a strip of sea.
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
