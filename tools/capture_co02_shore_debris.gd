extends SceneTree

## CO-02 (R-949) shore debris evidence on Kalamaja (reval_harbor_east).
##
## WHY: the review needs the same cove and spit framings before and after the
## shore debris family lands, in clear noon and in storm, at the shipped
## gameplay camera plus one eye-level framing where stone form, wet crust and
## wrack are judged. "before" plates are captured with the CO-02 scatter hook
## in map_view_mesh_builder_scatter.gd reverted; this tool does not toggle it.
##
## Requires a rendering-capable run (never --headless):
##   tools/godot_render.sh --script tools/capture_co02_shore_debris.gd -- \
##     --label after --weather clear
##   tools/godot_render.sh --rendering-method mobile --rendering-driver metal \
##     --script tools/capture_co02_shore_debris.gd -- --label after --weather storm
##
## The underwater plate uses tools/capture_underwater.gd with --map=reval_harbor_east
## (see docs/reports/co02_shore_debris.md for the exact pose).
##
## Output: docs/reports/images/co02_<pose>_<weather>_<renderer>_<label>.png

const MapAuditRegistry := preload("res://scripts/map/map_audit_registry.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")
const SkyWeather3D := preload("res://scripts/map/view3d/sky_weather_3d.gd")

const MAP_ID := "reval_harbor_east"
const OUTPUT_DIR := "res://docs/reports/images"
const VIEWPORT_SIZE := Vector2i(1280, 720)
const WARMUP_FRAMES := 24

## Poses in logic cells of content/maps/reval_harbor_east.rrmap. shore.coves
## cuts shallow coves at x 97-104 and 41-49 (rows 34-36); the sand spit between
## x 50 and 70 carries the barnacled and large erratics at (49-56, 25-28).
const POSES: Array[Dictionary] = [
	{
		"id": "cove",
		"focus": Vector2(100.0, 35.0),
		"coverage":
		"gameplay camera over the x 97-104 cove: barnacled erratics, wrack line, shingle",
	},
	{
		"id": "spit",
		"focus": Vector2(54.0, 31.0),
		"coverage": "gameplay camera over the spit and the erratics standing off it",
	},
	{
		"id": "close",
		"eye": Vector2(57.0, 37.5),
		"eye_height": 1.7,
		"target": Vector2(53.0, 28.0),
		"fov": 55.0,
		"coverage": "eye-level view from the spit to the crusted erratics, wrack and stones",
	},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("CO-02 captures need a real renderer; run through tools/godot_render.sh")
		quit(2)
		return
	var args := OS.get_cmdline_user_args()
	var label := _arg_value(args, "--label", "after")
	var weather := _arg_value(args, "--weather", "clear")
	var definitions: Dictionary = MapAuditRegistry.by_id()
	if not definitions.has(MAP_ID):
		push_error("CO-02 map missing from MapAuditRegistry: %s" % MAP_ID)
		quit(1)
		return
	var definition: MapDefinition = definitions[MAP_ID]
	var renderer := _renderer_label()
	for pose: Dictionary in POSES:
		var error := await _capture(definition, pose, label, weather, renderer)
		if error != OK:
			quit(1)
			return
	print("CO02_CAPTURED label=%s weather=%s renderer=%s" % [label, weather, renderer])
	quit(0)


static func _arg_value(args: Array, name: String, fallback: String) -> String:
	var index := 0
	while index < args.size():
		if String(args[index]) == name and index + 1 < args.size():
			return String(args[index + 1])
		index += 1
	return fallback


## MapView3D.world_position takes logic (pixel) coordinates; poses are in cells.
static func _cell_world(
	view: MapView3D, definition: MapDefinition, cell: Vector2, height: float
) -> Vector3:
	return view.world_position(cell * float(definition.cell_size), height)


static func _renderer_label() -> String:
	var method := String(RenderingServer.get_current_rendering_method())
	return "compat" if method == "gl_compatibility" else method


static func _weather_id(weather: String) -> StringName:
	match weather:
		"storm":
			return SkyWeather3D.WEATHER_STORM
		"overcast":
			return SkyWeather3D.WEATHER_OVERCAST
	return SkyWeather3D.WEATHER_CLEAR


func _capture(
	definition: MapDefinition, pose: Dictionary, label: String, weather: String, renderer: String
) -> Error:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)

	var grid := MapBuilder.build(definition)
	var view := MapView3D.create(definition, grid, MapView3D.TIME_DAY)
	viewport.add_child(view)

	var camera: Camera3D
	if pose.has("focus"):
		camera = view.view_camera()
		# The shipped runtime zoom, not the whole-map framing of _create_camera().
		camera.size = CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE
		var focus := _cell_world(view, definition, pose["focus"], 0.0)
		camera.position = focus + camera.transform.basis.z * MapView3D.CAMERA_DISTANCE
		camera.look_at(focus, Vector3.UP)
	else:
		# Eye-level perspective is evidence for form and surface; the production
		# camera stays in its authored dimetric pose.
		camera = Camera3D.new()
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = float(pose["fov"])
		camera.near = 0.05
		camera.far = 400.0
		view.add_child(camera)
		camera.global_position = _cell_world(
			view, definition, pose["eye"], float(pose["eye_height"])
		)
		camera.look_at(_cell_world(view, definition, pose["target"], 0.0), Vector3.UP)
	camera.current = true

	var sky := view.sky_weather()
	if sky != null:
		view.set_time_of_day(MapView3D.TIME_DAY)
		view.set_weather_time_scale(0.0)
		sky.auto_weather = false
		sky.set_weather(_weather_id(weather))
		sky.advance(SkyWeather3D.TRANSITION_SECONDS)
		view.apply_cycle_progress(view.cycle_progress)

	for _frame in WARMUP_FRAMES:
		await process_frame
	var texture := viewport.get_texture()
	if texture == null:
		push_error("CO-02 viewport has no texture for %s" % pose["id"])
		viewport.queue_free()
		await process_frame
		return ERR_CANT_CREATE
	var output := "%s/co02_%s_%s_%s_%s.png" % [OUTPUT_DIR, pose["id"], weather, renderer, label]
	var error := texture.get_image().save_png(ProjectSettings.globalize_path(output))
	if error != OK:
		push_error("Could not save CO-02 capture %s: %s" % [output, error_string(error)])
	else:
		print("CO-02 capture: %s" % output)
	viewport.queue_free()
	await process_frame
	return error
