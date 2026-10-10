extends SceneTree

## R-1516 review plates for district-map puddle decals (MapView3D): the same basins
## after rain, baked into drought crust, and soaking back under the first rain.
## Builds a small all-mud test district so many puddles sit in one frame, forces the
## ground state on the view's SkyWeather3D and freezes the weather clock.
##   tools/godot_render.sh --script tools/capture_puddle_drought.gd [-- --base=dirt]
## Output: build/puddle_drought/<state>_<camera>.png

const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")
const OUTPUT_DIR := "res://build/puddle_drought"
const VIEWPORT_SIZE := Vector2i(1280, 720)
const MAP_CELLS := 24
## [state, puddle_wetness, ground_dryness]
const STATES := [
	["rain", 0.8, 0.0],
	["dry", 0.0, 0.3],
	["drought", 0.0, 1.0],
	["early_drought", 0.0, 0.62],
]
## [name, eye offset from map centre, look-at height]
const CAMERAS := [
	["game", Vector3(0.0, 9.0, 7.5)],
	["low", Vector3(0.0, 1.7, 3.2)],
	["close", Vector3(0.4, 1.1, 1.2)],
]

var _base := MapTypes.TERRAIN_MUD


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--base=dirt":
			_base = MapTypes.TERRAIN_DIRT
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Puddle drought plates need a real renderer (tools/godot_render.sh)")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var definition := _definition()
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var view := MapView3D.create(definition, MapBuilder.build(definition), MapView3D.TIME_DAY)
	viewport.add_child(view)
	var camera := Camera3D.new()
	camera.fov = 55.0
	viewport.add_child(camera)
	camera.make_current()
	for frame in 6:
		await process_frame
	var sky: SkyWeather = view._sky_weather
	sky.auto_weather = false
	sky.time_scale = 0.0
	sky.set_weather(SkyWeather.WEATHER_CLEAR)
	sky.advance(SkyWeather.TRANSITION_SECONDS + 1.0)
	var centre := Vector3(MAP_CELLS * 0.5, 0.0, MAP_CELLS * 0.5)
	for state: Array in STATES:
		sky._puddle_wetness = float(state[1])
		sky._ground_dryness = float(state[2])
		for shot: Array in CAMERAS:
			# The close shot frames the puddle nearest the map centre.
			var target := _nearest_puddle(view, centre) if shot[0] == "close" else centre
			camera.position = target + (shot[1] as Vector3)
			camera.look_at(target, Vector3.UP)
			for frame in 6:
				await process_frame
			camera.make_current()
			await RenderingServer.frame_post_draw
			var path := "%s/%s_%s.png" % [OUTPUT_DIR, state[0], shot[0]]
			viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
			print("puddle drought plate: ", path)
	quit(0)


func _nearest_puddle(view: MapView3D, centre: Vector3) -> Vector3:
	var best := centre
	var best_distance := INF
	for chunk in view.get_node("Scatter").get_children():
		var puddles := chunk.get_node_or_null("Puddles") as MultiMeshInstance3D
		if puddles == null:
			continue
		for index in puddles.multimesh.instance_count:
			var at := puddles.global_transform * puddles.multimesh.get_instance_transform(index).origin
			if at.distance_to(centre) < best_distance:
				best_distance = at.distance_to(centre)
				best = at
	return best


func _definition() -> MapDefinition:
	var definition := MapDefinition.new()
	definition.map_id = &"puddle_drought_capture"
	definition.location = &"loc.puddle_drought_capture"
	definition.scope = &"prototype"
	definition.palette = &"clean_painted"
	definition.fingerprint = "puddle_drought_capture"
	definition.size_cells = Vector2i(MAP_CELLS, MAP_CELLS)
	definition.cell_size = 32
	definition.base_terrain = _base
	definition.player_spawn = Vector2(MAP_CELLS * 16, MAP_CELLS * 16)
	return definition
