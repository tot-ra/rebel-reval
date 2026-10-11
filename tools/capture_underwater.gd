extends SceneTree

## WS-13 underwater view captures. One shot per process, on a real renderer only (never
## --headless). Run through the minimized-window wrapper:
##   tools/godot_render.sh --rendering-method mobile --rendering-driver metal \
##     --script tools/capture_underwater.gd -- --shot=under_horizontal
##   tools/godot_render.sh --script tools/capture_underwater.gd -- --shot=under_up --suffix=gl
##
## Shots (map defaults to reval_harbor_north, output docs/reports/images/ws13_<shot>[_suffix].png):
##   under_horizontal  UNDER, level view towards the nearest quay/bank, clear day
##   under_up          UNDER, looking straight up (Snell's window), clear day
##   under_sun         UNDER, facing the refracted sun, SUN_PITCH_BELOW degrees under it (shafts)
##   straddle          lens on the surface, level view (waterline split), clear day
##   under_night       as under_horizontal at night
##   under_storm       as under_horizontal in a storm
##   dip               10 s dip in and out; saves an 8-frame contact sheet (wet lens, no flicker)
##   overview          the untouched orthographic gameplay view (pixel parity before/after)
##
## Overrides: --map=<id> --pos=x,y,z --look=x,y,z --time=day|night --weather=<id> --out=<path>
##   --param=name:value[;name:value] sets float uniforms on the pass (e.g. shafts:0) for A/B plates
##   --bench=<frames> renders 1920x1080 with vsync off and prints the mean frame time with
##     and without the pass quad (wall clock; SubViewport GPU timers read 0 on this Mac)
##
## WS-13b: open-sea cells have a real rendered basin (MapViewMeshBuilderConfig.SEA_BASIN_DEPTH),
## so UNDER shots sit about a metre under the surface, never closer than BED_CLEARANCE to the
## rendered bed. Rivers and ponds keep the ~9 mm film; there the camera falls back to hugging
## the surface. Shader TIME is frozen (near-zero time rollover) for every still shot so
## reruns are pixel-comparable.

const MapAuditRegistry := preload("res://scripts/map/map_audit_registry.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapTypesContract := preload("res://scripts/map/map_types.gd")
const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")
const SkyWeather3D := preload("res://scripts/map/view3d/sky_weather_3d.gd")
const MeshConfig := preload("res://scripts/map/view3d/map_view_mesh_builder_config.gd")
const MeshTerrain := preload("res://scripts/map/view3d/map_view_mesh_builder_terrain.gd")

const VIEWPORT_SIZE := Vector2i(1280, 720)
const WARMUP_FRAMES := 16
const OUTPUT_PREFIX := "res://docs/reports/images/ws13_"
const SHOTS: Array[String] = [
	"under_horizontal", "under_up", "under_sun", "straddle", "under_night", "under_storm", "dip",
	"overview"
]
## Shafts scatter forward (HG g = 0.75) and only hold their shape when the view runs
## close to the refracted sun ray, so the shot faces it, pitched this far below it.
const SUN_PITCH_BELOW := 20.0
const WATER_IOR := 1.333
## Camera depth under the rest surface for UNDER shots (world units, ~1 m).
const UNDER_DEPTH := 1.2
## Closest the UNDER camera may get to the rendered bed; thin-film water falls back to
## FILM_DEPTH (the WS-13 pose) because its bed is only millimetres down.
const BED_CLEARANCE := 0.35
const FILM_DEPTH := 0.0025
## Metres of basin need depth precision; only the thin-film fallback needs a tiny near plane.
const NEAR_PLANE := 0.01
const FILM_NEAR_PLANE := 0.0004
const FAR_PLANE := 240.0
const DIP_SECONDS := 10.0
const DIP_SHEET_FRAMES := 8
## Dip path: surface -> under -> air twice. Down goes a hand's depth into the basin;
## up clears the crest band (wave_height) so the lens really leaves the water.
const DIP_DEPTH := 0.12
const DIP_RISE := 0.06

var _args: Dictionary = {}


func _initialize() -> void:
	_args = _parse(OS.get_cmdline_user_args())
	if _args.has("error"):
		push_error(String(_args["error"]))
		quit(1)
		return
	call_deferred("_run")


static func _parse(raw: Array) -> Dictionary:
	var args := {"map": "reval_harbor_north", "shot": "", "suffix": ""}
	for item in raw:
		var text := String(item)
		if not text.begins_with("--") or not text.contains("="):
			return {"error": "WS-13 capture: unknown argument %s" % text}
		var key := text.substr(2, text.find("=") - 2)
		args[key] = text.substr(text.find("=") + 1)
	if not SHOTS.has(String(args["shot"])):
		return {"error": "WS-13 capture: --shot must be one of %s" % str(SHOTS)}
	return args


static func _vec3(text: String) -> Vector3:
	var parts := text.split(",")
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("WS-13 captures need a real renderer; run through tools/godot_render.sh")
		quit(2)
		return
	var definitions := MapAuditRegistry.by_id()
	var map_id := String(_args["map"])
	if not definitions.has(map_id):
		push_error("WS-13 capture: unknown map %s" % map_id)
		quit(1)
		return
	var shot := String(_args["shot"])
	var time_of_day := StringName(_args.get("time", "night" if shot == "under_night" else "day"))
	var weather := StringName(_args.get("weather", "storm" if shot == "under_storm" else "clear"))
	if shot != "dip":
		# Engine.time_scale does not stop shader TIME. A near-zero rollover pins TIME at ~0
		# (the renderer wraps it every frame), so reruns and before/after plates compare.
		Engine.time_scale = 0.0
		ProjectSettings.set_setting("rendering/limits/time/time_rollover_secs", 0.000001)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080) if _args.has("bench") else VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)
	var definition: MapDefinition = definitions[map_id]
	var grid := MapBuilder.build(definition)
	var view := MapView3D.create(definition, grid, time_of_day)
	viewport.add_child(view)
	var camera := view.view_camera()
	camera.current = true
	var sky := view.sky_weather()
	view.set_time_of_day(time_of_day)
	view.set_weather_time_scale(0.0)
	sky.auto_weather = false
	sky.set_weather(weather)
	sky.advance(SkyWeather3D.TRANSITION_SECONDS)
	view.apply_cycle_progress(view.cycle_progress)

	var surface_y := -MeshConfig.WATER_RECESS + MeshConfig.WATER_SURFACE_LIFT
	var pose := _default_pose(definition, grid, surface_y)
	# The live tide moves the surface; take the height the pass itself will use.
	if view.has_method(&"underwater_pass"):
		var probe: Dictionary = view._underwater_probe(Vector2(pose["pos"].x, pose["pos"].z))
		if not probe.is_empty():
			surface_y = float(probe["surface_y"])
			pose = _default_pose(definition, grid, surface_y)
	var position: Vector3 = _vec3(String(_args["pos"])) if _args.has("pos") else pose["pos"]
	var target: Vector3 = _vec3(String(_args["look"])) if _args.has("look") else pose["look"]
	if shot == "under_up" and not _args.has("look"):
		target = position + Vector3(0.0005, 1.0, 0.0)
	if shot == "straddle" and not _args.has("pos"):
		position.y = surface_y
		target.y = surface_y
	if shot != "overview":
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 70.0
		camera.near = FILM_NEAR_PLANE if bool(pose.get("film", false)) else NEAR_PLANE
		camera.far = FAR_PLANE
		camera.look_at_from_position(position, target, Vector3.UP)
		# The memory-fog overlay blurs by distance from the (absent) player; it is a
		# gameplay overlay for the top-down view and would smear these lens plates.
		var fog := view.get_node_or_null("FogOfWar") as Node3D
		if fog != null:
			fog.visible = false

	var pass_node = view.underwater_pass() if view.has_method(&"underwater_pass") else null
	if pass_node != null and _args.has("param"):
		for pair in String(_args["param"]).split(";"):
			var kv := pair.split(":")
			pass_node.pass_material().set_shader_parameter(StringName(kv[0]), float(kv[1]))
	for _frame in WARMUP_FRAMES:
		await process_frame
	if shot == "under_sun" and pass_node != null and not _args.has("look"):
		# The pass mirrors the water's sun direction (towards the light) every frame.
		var sun: Vector3 = pass_node.pass_material().get_shader_parameter(&"sun_direction")
		var azimuth := Vector3(sun.x, 0.0, sun.z).normalized()
		# Snell: the zenith angle shrinks by the IOR under water.
		var zenith_air := acos(clampf(sun.normalized().y, -1.0, 1.0))
		var zenith_water := asin(clampf(sin(zenith_air) / WATER_IOR, -1.0, 1.0))
		var pitch := PI * 0.5 - zenith_water - deg_to_rad(SUN_PITCH_BELOW)
		target = position + azimuth * cos(pitch) + Vector3.UP * sin(pitch)
		camera.look_at_from_position(position, target, Vector3.UP)
		for _frame in WARMUP_FRAMES:
			await process_frame

	if _args.has("bench") and pass_node != null:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		var frames := int(_args["bench"])
		var with_pass := await _mean_frame_ms(frames)
		# Detach the quad so the pass costs nothing while its state machine keeps running.
		var quad: Node = pass_node.get_node("UnderwaterQuad")
		pass_node.remove_child(quad)
		var without_pass := await _mean_frame_ms(frames)
		pass_node.add_child(quad)
		print(
			"WS13_BENCH shot=%s state=%d with_pass_ms=%.3f without_pass_ms=%.3f pass_ms=%.3f" % [
				shot, pass_node.state, with_pass, without_pass, with_pass - without_pass
			]
		)
		quit(0)
		return

	var image: Image
	if shot == "dip":
		image = await _dip_sheet(viewport, camera, view, position, target, surface_y)
	else:
		image = viewport.get_texture().get_image()
	var out := String(_args.get("out", ""))
	if out.is_empty():
		var suffix := String(_args["suffix"])
		out = OUTPUT_PREFIX + shot + ("_" + suffix if not suffix.is_empty() else "") + ".png"
	var out_path := ProjectSettings.globalize_path(out) if out.begins_with("res://") else out
	var error := image.save_png(out_path)
	if error != OK:
		push_error("WS-13 capture: could not save %s (%s)" % [out, error_string(error)])
		quit(1)
		return
	print(
		"WS13_CAPTURED shot=%s out=%s state=%s pos=%s look=%s renderer=%s" % [
			shot, out, str(pass_node.state) if pass_node != null else "none", str(position),
			str(target), RenderingServer.get_current_rendering_method()
		]
	)
	MapView3D._strip_geometry_materials(view)
	viewport.queue_free()
	await process_frame
	quit(0)


## A level view from a water cell towards the nearest dry cell (quay or bank), starting a
## few cells out so the foundation fills the middle of the frame.
func _default_pose(definition: MapDefinition, grid: MapTerrainGrid, surface_y: float) -> Dictionary:
	var best_water := Vector2i(-1, -1)
	var best_dry := Vector2i(-1, -1)
	for y in grid.size_cells.y:
		for x in grid.size_cells.x:
			var cell := Vector2i(x, y)
			if not MapTypesContract.WATER_TERRAINS.has(grid.get_terrain(cell)):
				continue
			var dry := _dry_ahead(grid, cell, 6)
			if dry.x >= 0:
				best_water = cell
				best_dry = dry
				break
		if best_water.x >= 0:
			break
	var bed_y := MeshTerrain.view_bed_height(
		definition, Vector2(best_water.x + 0.5, best_water.y + 0.5)
	)
	var eye_y := maxf(surface_y - UNDER_DEPTH, bed_y + BED_CLEARANCE)
	var film := eye_y >= surface_y - FILM_DEPTH
	if film:
		eye_y = surface_y - FILM_DEPTH
	var from := Vector3(best_water.x + 0.5, eye_y, best_water.y + 0.5)
	var to := Vector3(best_dry.x + 0.5, eye_y, best_dry.y + 0.5)
	return {"pos": from, "look": to, "film": film}


## First dry cell exactly `distance` cells away along an axis with water all the way.
func _dry_ahead(grid: MapTerrainGrid, cell: Vector2i, distance: int) -> Vector2i:
	for step: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var clear := true
		for index in range(1, distance):
			if not MapTypesContract.WATER_TERRAINS.has(grid.get_terrain(cell + step * index)):
				clear = false
				break
		var end := cell + step * distance
		var terrain := grid.get_terrain(end)
		if clear and terrain != &"" and not MapTypesContract.WATER_TERRAINS.has(terrain):
			return end
	return Vector2i(-1, -1)


## Moves the camera through the surface for DIP_SECONDS of real frames and tiles
## DIP_SHEET_FRAMES evenly spaced frames into one sheet (4 x 2, half size).
func _dip_sheet(
	viewport: SubViewport, camera: Camera3D, _view: Node, position: Vector3, target: Vector3,
	surface_y: float
) -> Image:
	var tile := VIEWPORT_SIZE / 2
	var sheet := Image.create(tile.x * 4, tile.y * 2, false, Image.FORMAT_RGBA8)
	var start_ms := Time.get_ticks_msec()
	var next_tile := 0
	var forward := (target - position).normalized()
	while next_tile < DIP_SHEET_FRAMES:
		await process_frame
		# Real time, like the pass's own frame delta, so the wet-lens timer and the sheet agree.
		var elapsed := float(Time.get_ticks_msec() - start_ms) / 1000.0
		var phase := elapsed / DIP_SECONDS * TAU * 2.0
		var eye := position
		var wave := sin(phase)
		eye.y = surface_y - wave * DIP_DEPTH if wave > 0.0 else surface_y - wave * DIP_RISE
		camera.look_at_from_position(eye, eye + forward, Vector3.UP)
		if elapsed >= DIP_SECONDS * float(next_tile) / float(DIP_SHEET_FRAMES):
			var frame := viewport.get_texture().get_image()
			frame.resize(tile.x, tile.y, Image.INTERPOLATE_BILINEAR)
			frame.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(
				frame, Rect2i(Vector2i.ZERO, tile),
				Vector2i((next_tile % 4) * tile.x, (next_tile / 4) * tile.y)
			)
			next_tile += 1
	return sheet


func _mean_frame_ms(frames: int) -> float:
	for _warm in 30:
		await process_frame
	var start := Time.get_ticks_usec()
	for _frame in frames:
		await process_frame
	return float(Time.get_ticks_usec() - start) / 1000.0 / float(frames)
