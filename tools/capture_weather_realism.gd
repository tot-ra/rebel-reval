extends SceneTree

## Reproducible sky plates with the production lighting and weather presenter.
## tools/godot_render.sh --script tools/capture_weather_realism.gd -- --before
const Weather := preload("res://scripts/map/view3d/sky_weather_3d.gd")
const Lighting := preload("res://scripts/map/view3d/map_view_lighting.gd")
const OUTPUT := "res://docs/reports/images/weather_realism/"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Weather plates require a real renderer")
		quit(1)
		return
	if "--town" in OS.get_cmdline_user_args():
		await _capture_town()
		return
	var variant := "before" if "--before" in OS.get_cmdline_user_args() else "after"
	var baseline_shader := "--baseline-shader" in OS.get_cmdline_user_args()
	if baseline_shader:
		variant = "baseline_shader"
	var timings: Array[Dictionary] = []
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT + variant))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), true)
	var world := Node3D.new()
	viewport.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 3, 0)
	camera.fov = 75.0
	camera.look_at(Vector3(0, 12, 35))
	var environment := Environment.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	Lighting.configure_post_process(environment)
	var owner := WorldEnvironment.new()
	owner.environment = environment
	world.add_child(owner)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	world.add_child(sun)
	# Neutral ground and distance markers expose fog/light response without maps.
	for distance: float in [12.0, 35.0, 75.0, 150.0]:
		var marker := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(3, 5, 3)
		marker.mesh = box
		marker.position = Vector3(-8, 2.5, distance)
		world.add_child(marker)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1200, 1200)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.24, 0.28, 0.19)
	ground_material.roughness = 0.92
	ground.material_override = ground_material
	world.add_child(ground)
	for scenario: String in [
		"clear", "cloudy", "overcast", "rain", "storm", "dusk", "night", "minimum"
	]:
		var sky := Weather.new()
		sky.auto_weather = false
		sky.set_process(false)
		world.add_child(sky)
		if scenario == "minimum":
			sky.set_quality_tier(Weather.QUALITY_MINIMUM)
		sky.configure(camera, environment)
		if baseline_shader:
			var shader := Shader.new()
			shader.code = FileAccess.get_file_as_string("res://build/weather_baseline.gdshader")
			(environment.sky.sky_material as ShaderMaterial).shader = shader
		var weather_id := StringName(scenario)
		if scenario in ["dusk", "night", "minimum"]:
			weather_id = Weather.WEATHER_CLOUDY
		sky.set_weather(weather_id)
		sky.advance(Weather.TRANSITION_SECONDS)
		camera.look_at(Vector3(0, 12, 35))
		var progress := 0.5
		if scenario == "dusk":
			progress = 0.79
			camera.look_at(camera.position + Weather.solar_direction(progress) * 35.0)
		elif scenario == "night":
			progress = 0.0
		else:
			camera.look_at(Vector3(0, 12, 35))
		Lighting.apply_cycle_progress(progress, sun, environment, sky, false)
		# Wait for threaded procedural texture generation before deterministic readback.
		var material := environment.sky.sky_material as ShaderMaterial
		for parameter: StringName in [&"cloud_noise", &"cloud_shape"]:
			var texture := material.get_shader_parameter(parameter) as NoiseTexture2D
			if texture.get_image() == null:
				await texture.changed
		for frame in 24:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := OUTPUT + variant + "/" + scenario + ".png"
		var result := viewport.get_texture().get_image().save_png(path)
		if result != OK:
			push_error("Failed to save " + path)
			quit(1)
			return
		print("WEATHER_PLATE ", path)
		var gpu_times: Array[float] = []
		var cpu_times: Array[float] = []
		var frame_times: Array[float] = []
		for frame in 90:
			var frame_start := Time.get_ticks_usec()
			# Exercise live shader uniform/radiance updates as in gameplay.
			sky.advance(1.0 / 60.0)
			await process_frame
			if frame >= 30:
				frame_times.append(float(Time.get_ticks_usec() - frame_start) / 1000.0)
				gpu_times.append(RenderingServer.viewport_get_measured_render_time_gpu(
					viewport.get_viewport_rid()))
				cpu_times.append(RenderingServer.viewport_get_measured_render_time_cpu(
					viewport.get_viewport_rid()))
		gpu_times.sort()
		cpu_times.sort()
		frame_times.sort()
		timings.append({"scenario": scenario,
			"gpu_median_ms": gpu_times[30] if gpu_times[30] > 0.0 else null,
			"gpu_p95_ms": gpu_times[57] if gpu_times[57] > 0.0 else null,
			"cpu_median_ms": cpu_times[30], "frame_median_ms": frame_times[30],
			"frame_p95_ms": frame_times[57],
			"samples": 60})
		sky.free()
	var file := FileAccess.open(OUTPUT + variant + "/timings.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine": Engine.get_version_info()["string"],
		"device": RenderingServer.get_video_adapter_name(), "size": [1280, 720],
		"note": ("Uncapped whole viewport with live clouds; null GPU timing means unavailable; "
			+ "not minimum-hardware certification"),
		"timings": timings}, "\t"))
	viewport.queue_free()
	await process_frame
	quit(0)


func _capture_town() -> void:
	var factory := load("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")
	var definition: MapDefinition = factory.create()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var builder := load("res://scripts/map/map_builder.gd")
	var view_script := load("res://scripts/map/view3d/map_view_3d.gd")
	var view: Node3D = view_script.create(definition, builder.build(definition), &"day")
	viewport.add_child(view)
	var camera: Camera3D = view.view_camera()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 75.0
	camera.position = Vector3(25.5, 18.0, 0.75)
	camera.look_at(Vector3(25.5, 16.0, 35.0))
	var sky: SkyWeather3D = view.sky_weather()
	sky.auto_weather = false
	view.set_weather_time_scale(0.0)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT + "after"))
	for weather: StringName in [Weather.WEATHER_CLEAR, Weather.WEATHER_RAIN]:
		sky.set_weather(weather)
		sky.advance(Weather.TRANSITION_SECONDS)
		view.apply_cycle_progress(0.5)
		for frame in 36:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := OUTPUT + "after/town_" + String(weather) + ".png"
		if viewport.get_texture().get_image().save_png(path) != OK:
			push_error("Failed to save " + path)
			quit(1)
			return
		print("WEATHER_TOWN_PLATE ", path)
	viewport.queue_free()
	await process_frame
	quit(0)
