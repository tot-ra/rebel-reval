extends SceneTree

## CO-01 (R-948) coastal ground-material evidence on Kalamaja (reval_harbor_east).
##
## WHY: the beach, mud and meadow bands fill most of the Kalamaja frame, so the
## review needs matched plates of the same authored map before and after the
## ground-material change: the shipped orthographic gameplay camera plus a close
## eye-level framing where grain, relief and tiling are judged.
##
## Requires a rendering-capable run (never --headless):
##   tools/godot_render.sh --script tools/capture_co01_ground_materials.gd -- \
##     --label after --weather clear
##   tools/godot_render.sh --rendering-method mobile --rendering-driver metal \
##     --script tools/capture_co01_ground_materials.gd -- --label after --weather overcast
##
## Output: docs/reports/images/co01_<pose>_<weather>_<renderer>_<label>.png

const MapAuditRegistry := preload("res://scripts/map/map_audit_registry.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")
const SkyWeather3D := preload("res://scripts/map/view3d/sky_weather_3d.gd")

const MAP_ID := "reval_harbor_east"
const OUTPUT_DIR := "res://docs/reports/images"
const VIEWPORT_SIZE := Vector2i(1280, 720)
const WARMUP_FRAMES := 24

## Poses in logic cells of content/maps/reval_harbor_east.rrmap: shore.sand
## (coast_sand) spans rows 34-43, shore.mud rows 44-54, village.grass from 55.
const POSES: Array[Dictionary] = [
	{
		"id": "gameplay",
		"focus": Vector2(64.0, 44.0),
		"coverage": "shipped gameplay camera over the sand, mud and meadow bands",
	},
	{
		"id": "close",
		"eye": Vector2(62.0, 47.5),
		"eye_height": 1.7,
		"target": Vector2(64.0, 39.0),
		"fov": 55.0,
		"coverage": "eye-level framing of the foreshore sand, mud edge and shingle strands",
	},
	{
		"id": "shore_run",
		"eye": Vector2(20.0, 50.0),
		"eye_height": 3.2,
		"target": Vector2(60.0, 38.0),
		"fov": 60.0,
		"coverage": "long view along the shore band to judge repeat/tile grid",
	},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("CO-01 captures need a real renderer; run through tools/godot_render.sh")
		quit(2)
		return
	var args := OS.get_cmdline_user_args()
	var label := _arg_value(args, "--label", "after")
	var weather := _arg_value(args, "--weather", "clear")
	var definitions: Dictionary = MapAuditRegistry.by_id()
	if not definitions.has(MAP_ID):
		push_error("CO-01 map missing from MapAuditRegistry: %s" % MAP_ID)
		quit(1)
		return
	var definition: MapDefinition = definitions[MAP_ID]
	var renderer := _renderer_label()
	for pose: Dictionary in POSES:
		var error := await _capture(definition, pose, label, weather, renderer)
		if error != OK:
			quit(1)
			return
	print("CO01_CAPTURED label=%s weather=%s renderer=%s" % [label, weather, renderer])
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
		# Eye-level perspective is evidence for surface detail; the production
		# camera stays in its authored dimetric pose.
		camera = Camera3D.new()
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = float(pose["fov"])
		camera.near = 0.05
		camera.far = 400.0
		view.add_child(camera)
		camera.global_position = _cell_world(view, definition, pose["eye"], float(pose["eye_height"]))
		camera.look_at(_cell_world(view, definition, pose["target"], 0.0), Vector3.UP)
	camera.current = true

	var sky := view.sky_weather()
	if sky != null:
		view.set_time_of_day(MapView3D.TIME_DAY)
		view.set_weather_time_scale(0.0)
		sky.auto_weather = false
		sky.set_weather(
			SkyWeather3D.WEATHER_OVERCAST if weather == "overcast" else SkyWeather3D.WEATHER_CLEAR
		)
		sky.advance(SkyWeather3D.TRANSITION_SECONDS)
		view.apply_cycle_progress(view.cycle_progress)

	for _frame in WARMUP_FRAMES:
		await process_frame
	var texture := viewport.get_texture()
	if texture == null:
		push_error("CO-01 viewport has no texture for %s" % pose["id"])
		viewport.queue_free()
		await process_frame
		return ERR_CANT_CREATE
	var output := "%s/co01_%s_%s_%s_%s.png" % [OUTPUT_DIR, pose["id"], weather, renderer, label]
	var error := texture.get_image().save_png(ProjectSettings.globalize_path(output))
	if error != OK:
		push_error("Could not save CO-01 capture %s: %s" % [output, error_string(error)])
	else:
		print("CO-01 capture: %s" % output)
	viewport.queue_free()
	await process_frame
	return error
