extends SceneTree

## WS-05 evidence: moored hulls stay seated on the FFT sea. Needs a real renderer,
## so run it through the minimized-window wrapper:
##   tools/godot_render.sh --rendering-method mobile --rendering-driver metal \
##     --script tools/capture_ws05_boat_waterline.gd -- --scenario=storm --boat=cog
##
## Options:
##   --scenario=clear|storm   weather preset (day)
##   --boat=cog|landing       merchant_cog_central (deep water) or landing_boat_west
##                            (shallow berth) on reval_harbor_north
## The sea clock advances by the real frame delta so BoatFloat3D's spring runs as in
## play. Writes one contact sheet of 12 moments, 0.5 s apart, after a 6 s settle:
##   docs/reports/images/ws05_<renderer>_<scenario>_<boat>_clip.png

const MapAuditRegistry := preload("res://scripts/map/map_audit_registry.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")
const SkyWeather3D := preload("res://scripts/map/view3d/sky_weather_3d.gd")

const OUTPUT_DIR := "res://docs/reports/images"
const PLATE_SIZE := Vector2i(960, 540)
const FRAME_DELTA := 1.0 / 60.0
const SETTLE_SECONDS := 6.0
const MOMENTS := 12
const MOMENT_STEP := 0.5
const COLUMNS := 4
const BOATS := {
	&"cog": {"prop": &"merchant_cog_central", "ortho": 11.0},
	&"landing": {"prop": &"landing_boat_west", "ortho": 6.0},
}
const WEATHER := {
	&"clear": SkyWeather3D.WEATHER_CLEAR,
	&"storm": SkyWeather3D.WEATHER_STORM,
}
const CAPTURE_DATE := {"day": 21, "month": 6, "year": 1343}

var _scenario := &"clear"
var _boat := &"cog"
var _ocean_time := 3.0


func _initialize() -> void:
	for raw in OS.get_cmdline_user_args():
		var argument := String(raw)
		if argument.begins_with("--scenario="):
			_scenario = StringName(argument.trim_prefix("--scenario="))
		elif argument.begins_with("--boat="):
			_boat = StringName(argument.trim_prefix("--boat="))
		else:
			push_error("WS-05 capture: unknown argument %s" % argument)
			quit(1)
			return
	if not BOATS.has(_boat) or not WEATHER.has(_scenario):
		push_error("WS-05 capture: unsupported boat or scenario")
		quit(1)
		return
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("WS-05 waterline capture needs a real renderer")
		quit(2)
		return
	var definition: MapDefinition = MapAuditRegistry.by_id().get("reval_harbor_north")
	MapViewMaterials.reset()
	var viewport := SubViewport.new()
	viewport.size = PLATE_SIZE
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
	view.set_calendar_date(CAPTURE_DATE)
	view.set_time_of_day(MapView3D.TIME_DAY)
	view.set_weather_time_scale(0.0)
	sky.auto_weather = false
	sky.set_weather(WEATHER[_scenario])
	sky.advance(SkyWeather3D.TRANSITION_SECONDS)
	view.apply_cycle_progress(view.cycle_progress)

	var boat_config: Dictionary = BOATS[_boat]
	var hull := _find_prop(view, StringName(boat_config["prop"]))
	if hull == null:
		push_error("WS-05 capture: prop %s not found" % boat_config["prop"])
		quit(1)
		return
	var floater := hull.get_node_or_null("BoatFloat")
	print(
		"WS05_BOAT prop=%s fft=%s surface=%s" % [
			boat_config["prop"],
			floater.call("uses_fft") if floater != null else false,
			floater.get("_fft_surface") if floater != null else Vector3.ZERO,
		]
	)
	var camera := view.view_camera()
	camera.current = true
	camera.size = float(boat_config["ortho"])
	var target := hull.global_position
	camera.position = target + camera.transform.basis.z * MapView3D.CAMERA_DISTANCE

	var clock := _ocean_time
	var frames: Array[Image] = []
	var elapsed := 0.0
	var next_moment := SETTLE_SECONDS
	while frames.size() < MOMENTS:
		clock += FRAME_DELTA
		elapsed += FRAME_DELTA
		MapViewRuntimeEnvironment.set_ocean_time(clock)
		await process_frame
		if elapsed + 0.0001 >= next_moment:
			var frame := viewport.get_texture().get_image()
			frame.convert(Image.FORMAT_RGBA8)
			frames.append(frame)
			next_moment += MOMENT_STEP
	_save(_contact_sheet(frames))
	quit(0)


func _find_prop(view: Node, prop_id: StringName) -> Node3D:
	for node in view.find_children("*", "Node3D", true, false):
		if node.has_node("BoatFloat") and String(node.name).contains(String(prop_id)):
			return node as Node3D
	for node in view.find_children("*", "Node3D", true, false):
		if node.has_meta(&"prop_id") and StringName(node.get_meta(&"prop_id")) == prop_id:
			return node as Node3D
	return null


func _contact_sheet(frames: Array[Image]) -> Image:
	var tile := frames[0].get_size()
	var rows := ceili(float(frames.size()) / float(COLUMNS))
	var sheet := Image.create_empty(tile.x * COLUMNS, tile.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.BLACK)
	for index in frames.size():
		var origin := Vector2i((index % COLUMNS) * tile.x, (index / COLUMNS) * tile.y)
		sheet.blit_rect(frames[index], Rect2i(Vector2i.ZERO, tile), origin)
	return sheet


func _save(image: Image) -> void:
	var renderer := RenderingServer.get_current_rendering_driver_name()
	var path := "%s/ws05_%s_%s_%s_clip.png" % [OUTPUT_DIR, renderer, _scenario, _boat]
	if image.save_png(ProjectSettings.globalize_path(path)) != OK:
		push_error("WS-05 capture: could not save %s" % path)
		quit(1)
		return
	print("WS05_CAPTURED %s" % path)
