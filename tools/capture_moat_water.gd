extends SceneTree

## South wall moat evidence on south_quarter (stagnant TERRAIN_WATER look).
##
## WHY: the moat read as clean blue water cut flat by the map edge. Plates show
## the murky olive column, duckweed film and muddy outer bank.
##
## Requires a rendering-capable run (never --headless):
##   tools/godot_render.sh --script tools/capture_moat_water.gd -- --label after
##
## Output: docs/reports/images/moat_water_<pose>_<label>.png

const MapAuditRegistry := preload("res://scripts/map/map_audit_registry.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")
const MapViewRuntime := preload("res://scripts/map/view3d/map_view_runtime.gd")
const TerrainMaterials := preload("res://scripts/map/view3d/map_view_terrain_materials.gd")
const SkyWeather3D := preload("res://scripts/map/view3d/sky_weather_3d.gd")

const MAP_ID := "south_quarter"
const OUTPUT_DIR := "res://docs/reports/images"
const VIEWPORT_SIZE := Vector2i(1280, 720)
const WARMUP_FRAMES := 24

## Cells of content/maps/market_civic_quarter.rrmap: forum.ground (dirt) spans
## 24..68 x 31..66 and forum.wear (mud) 28..64 x 35..59.
const POSES: Array[Dictionary] = [
	{"id": "gameplay", "focus": Vector2(190.0, 92.0), "zoom": 1.0},
	{
		"id": "close",
		"eye": Vector2(190.0, 100.0),
		"eye_height": 2.5,
		"target": Vector2(190.0, 90.0),
		"fov": 55.0,
	},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Ground captures need a real renderer; run through tools/godot_render.sh")
		quit(2)
		return
	var label := _arg_value(OS.get_cmdline_user_args(), "--label", "after")
	var definitions: Dictionary = MapAuditRegistry.by_id()
	if not definitions.has(MAP_ID):
		push_error("Map missing from MapAuditRegistry: %s" % MAP_ID)
		quit(1)
		return
	for pose: Dictionary in POSES:
		if await _capture(definitions[MAP_ID], pose, label) != OK:
			quit(1)
			return
	print("MOAT_WATER_CAPTURED label=%s" % label)
	quit(0)


static func _arg_value(args: Array, name: String, fallback: String) -> String:
	var index := args.find(name)
	if index >= 0 and index + 1 < args.size():
		return String(args[index + 1])
	return fallback


static func _cell_world(
	view: MapView3D, definition: MapDefinition, cell: Vector2, height: float
) -> Vector3:
	return view.world_position(cell * float(definition.cell_size), height)


func _capture(definition: MapDefinition, pose: Dictionary, label: String) -> Error:
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
		var zoom := float(pose["zoom"])
		camera.size = (
			MapViewRuntime.ZOOM_MAX_ORTHOGRAPHIC_SIZE
			if zoom < 0.0
			else CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE * zoom
		)
		var focus := _cell_world(view, definition, pose["focus"], 0.0)
		camera.position = focus + camera.transform.basis.z * MapView3D.CAMERA_DISTANCE
		camera.look_at(focus, Vector3.UP)
	else:
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
		sky.set_weather(SkyWeather3D.WEATHER_CLEAR)
		sky.advance(SkyWeather3D.TRANSITION_SECONDS)
		view.apply_cycle_progress(view.cycle_progress)

	for _frame in WARMUP_FRAMES:
		await process_frame
	var output := "%s/moat_water_%s_%s.png" % [OUTPUT_DIR, pose["id"], label]
	var error := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(output))
	if error != OK:
		push_error("Could not save %s: %s" % [output, error_string(error)])
	else:
		print("Moat capture: %s" % output)
	viewport.queue_free()
	await process_frame
	return error
