extends SceneTree

## Forum prop/vegetation evidence on market_civic_quarter.
##
## WHY: a grass tuft from the view-only vegetation scatter grew straight through
## the `civic_well_wash_tub` basin. Scatter now skips cells claimed by solid
## props (`MapViewMeshBuilderPrimitives.prop_cell_rects`), and these eye-level
## plates show the forum's solid props standing on clear ground.
##
## The camera targets are read from the map definition, so a prop that moves
## keeps its plate instead of silently framing empty dirt.
##
## Requires a rendering-capable run (never --headless):
##   tools/godot_render.sh --script tools/capture_forum_prop_vegetation.gd
##
## Output: docs/reports/images/forum_prop_vegetation_<prop id>.png

const MapAuditRegistry := preload("res://scripts/map/map_audit_registry.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")
const SkyWeather3D := preload("res://scripts/map/view3d/sky_weather_3d.gd")

const MAP_ID := "market_civic_quarter"
const OUTPUT_DIR := "res://docs/reports/images"
const VIEWPORT_SIZE := Vector2i(1280, 720)
const WARMUP_FRAMES := 24

## Props to frame, with the eye offset in cells from the prop and the eye height
## in metres. A low eye is what exposed the tuft in the first place.
const SHOTS: Array[Dictionary] = [
	# The tub is authored without a rect (anchor cell 30,37); the well goods
	# pallet carries one, so the two plates cover both exclusion branches.
	{"prop": &"civic_well_wash_tub", "eye_offset": Vector2(-3.5, 3.5), "eye_height": 1.2},
	{"prop": &"civic_well_goods", "eye_offset": Vector2(-4.5, 4.5), "eye_height": 1.6},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Forum captures need a real renderer; run through tools/godot_render.sh")
		quit(2)
		return
	var definitions: Dictionary = MapAuditRegistry.by_id()
	if not definitions.has(MAP_ID):
		push_error("Map missing from MapAuditRegistry: %s" % MAP_ID)
		quit(1)
		return
	var definition: MapDefinition = definitions[MAP_ID]
	for shot: Dictionary in SHOTS:
		var found: Variant = _prop_cell(definition, shot["prop"])
		if found == null:
			push_error("Prop missing from %s: %s" % [MAP_ID, shot["prop"]])
			quit(1)
			return
		var target: Vector2 = found
		if await _capture(definition, shot, target) != OK:
			quit(1)
			return
	print("FORUM_PROP_VEGETATION_CAPTURED")
	quit(0)


## Cell-space centre of a prop. Prop footprints and positions are authored in
## logic units (cell * cell_size), so divide before offsetting the eye in cells.
static func _prop_cell(definition: MapDefinition, prop_id: StringName) -> Variant:
	var cell_size := float(definition.cell_size)
	for prop: Dictionary in definition.props:
		if prop.get("id", &"") != prop_id:
			continue
		if prop.get("footprint") is Rect2:
			var footprint: Rect2 = prop["footprint"]
			return (footprint.position + footprint.size * 0.5) / cell_size
		if prop.get("position") is Vector2:
			return prop["position"] / cell_size
	return null


static func _cell_world(
	view: MapView3D, definition: MapDefinition, cell: Vector2, height: float
) -> Vector3:
	return view.world_position(cell * float(definition.cell_size), height)


func _capture(definition: MapDefinition, shot: Dictionary, target: Vector2) -> Error:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)

	var grid := MapBuilder.build(definition)
	var view := MapView3D.create(definition, grid, MapView3D.TIME_DAY)
	viewport.add_child(view)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 50.0
	camera.near = 0.05
	camera.far = 400.0
	view.add_child(camera)
	var eye_offset: Vector2 = shot["eye_offset"]
	camera.global_position = _cell_world(
		view, definition, target + eye_offset, float(shot["eye_height"])
	)
	camera.look_at(_cell_world(view, definition, target, 0.35), Vector3.UP)
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
	var output := "%s/forum_prop_vegetation_%s.png" % [OUTPUT_DIR, shot["prop"]]
	var error := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(output))
	if error != OK:
		push_error("Could not save %s: %s" % [output, error_string(error)])
	else:
		print("Forum capture: %s (target cell %s)" % [output, target])
	viewport.queue_free()
	await process_frame
	return error
