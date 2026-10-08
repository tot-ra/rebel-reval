extends SceneTree

## R-1443: night-sky evidence for round twinkling stars and the Milky Way over
## Reval. Run via tools/godot_render.sh --script tools/capture_night_sky.gd.
## Writes docs/reports/images/night_sky/night_sky.png (three panels) and
## night_sky_twinkle.png (one zoomed field at two twinkle times).
## Cloud coverage is zeroed for evidence only; gameplay weather is untouched.
## A/B flags after `--`: --no-stars, --no-star-points, --no-milky-way,
## --milky-way=<strength>; each adds a suffix to the panel sheet's file name.

const Registry := preload("res://scripts/map/map_audit_registry.gd")
const Builder := preload("res://scripts/map/map_builder.gd")
const View := preload("res://scripts/map/view3d/map_view_3d.gd")
const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")
const Bridge := preload("res://scripts/map/view3d/map_view_bridge.gd")
const SIZE := Vector2i(900, 640)
const OUTPUT_DIR := "res://docs/reports/images/night_sky"
## Any open outdoor map works; the camera looks at the sky.
const MAP_CANDIDATES: Array[String] = ["smithy_courtyard", "lower_town_slice", "reval_harbor_north"]

## Both dates sit near a new moon (1343-04-25 and four lunations later), so the
## Milky Way is not washed out by moonlight.
const SHOTS: Array[Dictionary] = [
	{
		"label": "23 Apr 1343 00:00, north: Milky Way low over the horizon",
		"date": {"day": 23, "month": 4, "year": 1343},
		"progress": 0.0,
		"bearing": Vector3(0.0, 0.0, -1.0),
		"pitch": 22.0,
		"fov": 90.0,
	},
	{
		"label": "21 Aug 1343 23:30, south-east: Cygnus band high",
		"date": {"day": 21, "month": 8, "year": 1343},
		"progress": 0.979,
		"bearing": Vector3(0.6, 0.0, 0.8),
		"pitch": 55.0,
		"fov": 90.0,
	},
	{
		"label": "21 Aug 1343 23:30, zoom on Cygnus (round stars, colours)",
		"date": {"day": 21, "month": 8, "year": 1343},
		"progress": 0.979,
		"bearing": Vector3(0.0, 0.0, 0.0),
		"pitch": 0.0,
		"fov": 28.0,
		"target_star": Vector4(310.358, 45.280, 1.25, 0.09),
	},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Night-sky evidence needs tools/godot_render.sh (GPU renderer)")
		quit(2)
		return
	var maps := Registry.by_id()
	var definition: MapDefinition = null
	for map_id in MAP_CANDIDATES:
		if maps.has(map_id):
			definition = maps[map_id]
			break
	if definition == null:
		push_error("No capture map found among %s" % [MAP_CANDIDATES])
		quit(1)
		return
	var grid := Builder.build(definition)
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var view := View.create(definition, grid, View.TIME_NIGHT)
	viewport.add_child(view)
	view.set_weather_time_scale(0.0)
	view.set_process(false)
	var sky := view.sky_weather()
	sky.auto_weather = false
	sky.set_weather(SkyWeather.WEATHER_CLEAR)
	var camera := view.view_camera()
	camera.current = true
	camera.far = 4000.0
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	var label := Label.new()
	label.position = Vector2(16.0, 14.0)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	viewport.add_child(label)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var sheet := Image.create(SIZE.x * SHOTS.size(), SIZE.y, false, Image.FORMAT_RGBA8)
	var twinkle := Image.create(SIZE.x * 2, SIZE.y, false, Image.FORMAT_RGBA8)
	for index in range(SHOTS.size()):
		var shot: Dictionary = SHOTS[index]
		var date: Dictionary = shot["date"]
		var progress := float(shot["progress"])
		view.set_calendar_date(date)
		view.apply_cycle_progress(progress)
		camera.fov = float(shot["fov"])
		camera.position = (
			Bridge.cell_center_to_world(grid.size_cells / 2, grid.cell_size) + Vector3.UP * 12.0
		)
		camera.look_at(camera.position + _shot_direction(shot, progress, date))
		label.text = String(shot["label"])
		var image := await _render(viewport, sky, 3.0)
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, SIZE), Vector2i(index * SIZE.x, 0))
		if shot.has("target_star"):
			twinkle.blit_rect(image, Rect2i(Vector2i.ZERO, SIZE), Vector2i.ZERO)
			label.text = "same field 0.35 s later (scintillation)"
			var later := await _render(viewport, sky, 3.35)
			twinkle.blit_rect(later, Rect2i(Vector2i.ZERO, SIZE), Vector2i(SIZE.x, 0))
		print("NIGHT_SKY shot=%d sun_y=%.3f moon_y=%.3f phase=%.2f" % [
			index,
			SkyWeather.solar_direction(progress, date).y,
			SkyWeather.lunar_direction(progress, date).y,
			SkyWeather.lunar_phase(date),
		])
	var suffix := ""
	for flag in OS.get_cmdline_user_args():
		suffix += "_" + flag.trim_prefix("--").replace("-", "_")
	var sheet_path := OUTPUT_DIR + "/night_sky%s.png" % suffix
	var error := sheet.save_png(ProjectSettings.globalize_path(sheet_path))
	error = maxi(error, twinkle.save_png(
		ProjectSettings.globalize_path(OUTPUT_DIR + "/night_sky_twinkle.png")
	))
	print("Saved %s (error=%d)" % [OUTPUT_DIR, error])
	viewport.free()
	quit(0 if error == OK else 1)


## Evidence only: clear the cloud deck so the whole star field is visible, and
## pin the twinkle clock so the capture is reproducible.
func _render(viewport: SubViewport, sky: Node, twinkle_time: float) -> Image:
	for _frame in range(30):
		sky._current["coverage"] = 0.0
		sky.set_process(false)
		sky._material.set_shader_parameter(&"star_twinkle_time", twinkle_time)
		var args := OS.get_cmdline_user_args()
		# A/B baselines: the same sky without the R-1443 stars and/or Milky Way.
		if "--no-stars" in args or "--no-star-points" in args:
			sky._material.set_shader_parameter(&"star_gain", 0.0)
		if "--no-stars" in args or "--no-milky-way" in args:
			sky._material.set_shader_parameter(&"milky_way_strength", 0.0)
		for arg in args:
			if arg.begins_with("--milky-way="):
				sky._material.set_shader_parameter(
					&"milky_way_strength", float(arg.trim_prefix("--milky-way="))
				)
		await process_frame
		await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


func _shot_direction(shot: Dictionary, progress: float, date: Dictionary) -> Vector3:
	if shot.has("target_star"):
		return _star_direction(shot["target_star"], progress, date)
	var bearing: Vector3 = (shot["bearing"] as Vector3).normalized()
	var pitch := deg_to_rad(float(shot["pitch"]))
	return (bearing * cos(pitch) + Vector3.UP * sin(pitch)).normalized()


## Inverse of equatorial_uv() in sky_weather_3d.gdshader for one catalog star.
func _star_direction(star: Vector4, progress: float, date: Dictionary) -> Vector3:
	var precessed := SkyWeather.precess_equatorial(star, 2000.0, SkyWeather.SKY_EPOCH_YEAR)
	var hour_angle := SkyWeather.sidereal_angle_for_progress(progress, date) - deg_to_rad(precessed.x)
	var dec := deg_to_rad(precessed.y)
	var lat := deg_to_rad(SkyWeather.OBSERVER_LATITUDE_DEGREES)
	var up := sin(lat) * sin(dec) + cos(lat) * cos(dec) * cos(hour_angle)
	var north := cos(lat) * sin(dec) - sin(lat) * cos(dec) * cos(hour_angle)
	var east := -cos(dec) * sin(hour_angle)
	return Vector3(east, up, -north).normalized()
