extends SceneTree

## ADR 0045 review plates for snowfall (fine / flakes / heavy) on a winter date.
## Builds a small mud district and drives a snow emitter by hand so each look
## is framed on its own.
##   tools/godot_render.sh --script tools/capture_snowfall.gd
## Output: build/snowfall/<kind>_<camera>.png

const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")
const OUTPUT_DIR := "res://build/snowfall"
const VIEWPORT_SIZE := Vector2i(1280, 720)
const MAP_CELLS := 24
## [kind, intensity, wind, slant]
const KINDS := [
	["fine", 0.3, 0.1, Vector2(0.05, 0.0)],
	["flakes", 0.55, 0.2, Vector2(0.05, 0.0)],
	["heavy", 0.95, 0.7, Vector2(0.35, 0.1)],
]
const CAMERAS := [
	["game", Vector3(0.0, 9.0, 7.5)],
	["low", Vector3(0.0, 1.7, 3.2)],
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Snowfall plates need a real renderer (tools/godot_render.sh)")
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
	sky.set_calendar_date({"day": 15, "month": 1, "year": 1343})
	sky.set_weather(SkyWeather.WEATHER_OVERCAST)
	sky.advance(SkyWeather.TRANSITION_SECONDS + 1.0)
	sky.set_process(false)
	var snow = preload("res://scripts/map/view3d/snowfall_3d.gd").new()
	snow.configure(2200)
	view.add_child(snow)
	var centre := Vector3(MAP_CELLS * 0.5, 0.0, MAP_CELLS * 0.5)
	for kind: Array in KINDS:
		for shot: Array in CAMERAS:
			camera.position = centre + (shot[1] as Vector3)
			camera.look_at(centre, Vector3.UP)
			camera.make_current()
			snow.visible = true
			snow.update_snowfall(float(kind[1]), float(kind[2]), kind[3], 1.0)
			snow.global_position = snow.emitter_position(
				camera.global_position, -camera.global_transform.basis.z, kind[3], snow.EMIT_HEIGHT
			)
			# Frames can outrun the clock in a minimized window, so simulate one
			# full lifetime up front instead of waiting for the volume to fill.
			snow.preprocess = snow.lifetime
			snow.restart()
			for frame in 8:
				await process_frame
			await RenderingServer.frame_post_draw
			var path := "%s/%s_%s.png" % [OUTPUT_DIR, kind[0], shot[0]]
			viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
			print("snowfall plate: ", path)
	quit(0)


func _definition() -> MapDefinition:
	var definition := MapDefinition.new()
	definition.map_id = &"snowfall_capture"
	definition.location = &"loc.snowfall_capture"
	definition.scope = &"prototype"
	definition.palette = &"clean_painted"
	definition.fingerprint = "snowfall_capture"
	definition.size_cells = Vector2i(MAP_CELLS, MAP_CELLS)
	definition.cell_size = 32
	definition.base_terrain = MapTypes.TERRAIN_MUD
	definition.player_spawn = Vector2(MAP_CELLS * 16, MAP_CELLS * 16)
	return definition
