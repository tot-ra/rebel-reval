extends SceneTree

## Visual review captures for Kalamaja net-yard wind animation on reval_harbor_east.
## Saves orthographic gameplay-angle stills for clear, coastal, and storm wind.
## Run: /Applications/Godot.app/Contents/MacOS/Godot --path . --script tools/capture_harbor_east_fishing_net_wind.gd

const HarborEastDefinition := preload("res://scripts/map/definitions/outdoor/reval_harbor_east_definition.gd")
const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")
const OUTPUT_DIR := "res://docs/reports/images/view3d/harbor_east_fishing_nets"
const VIEWPORT_SIZE := Vector2i(1280, 720)
const NET_YARD_FOCUS := Vector3(58.0, 0.8, 54.5)
const FRAME_COUNT := 4
const FRAME_GAP_SECONDS := 0.55

const WEATHER_SHOTS: Array[Dictionary] = [
	{"name": "clear", "weather": SkyWeather.WEATHER_CLEAR},
	{"name": "coastal", "weather": SkyWeather.WEATHER_CLOUDY},
	{"name": "storm", "weather": SkyWeather.WEATHER_RAIN},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var definition := HarborEastDefinition.create()
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var view := MapView3D.create(definition, MapBuilder.build(definition), MapView3D.TIME_DAY)
	viewport.add_child(view)
	_focus_gameplay_camera(view.view_camera())

	var sky: SkyWeather3D = view.sky_weather()
	sky.auto_weather = false

	for shot in WEATHER_SHOTS:
		sky.set_weather(shot["weather"] as StringName)
		await _settle_weather(view, sky, 6.5)
		for frame_index in FRAME_COUNT:
			for _warmup in 3:
				await process_frame
			var output := "%s/%s_%02d.png" % [OUTPUT_DIR, shot["name"], frame_index]
			var error := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(output))
			if error != OK:
				push_error("Could not save harbor net capture %s: %s" % [output, error_string(error)])
				quit(1)
				return
			print("Harbor net wind capture: %s (wind=%.2f)" % [output, sky.wind_strength()])
			await create_timer(FRAME_GAP_SECONDS).timeout

	viewport.queue_free()
	quit(0)


func _focus_gameplay_camera(camera: Camera3D) -> void:
	camera.rotation_degrees = Vector3(MapView3D.CAMERA_PITCH_DEGREES, MapView3D.CAMERA_YAW_DEGREES, 0.0)
	camera.size = 11.5
	camera.position = NET_YARD_FOCUS + camera.transform.basis.z * 16.0
	camera.current = true


func _settle_weather(view: MapView3D, sky: SkyWeather3D, seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.0:
		var step := minf(remaining, 0.1)
		sky.advance(step)
		MapViewMaterials.apply_world_wind(sky.wind_direction_xz(), sky.wind_strength())
		remaining -= step
		await process_frame
