extends SceneTree
## Reproducible GL Compatibility review of the actual imported bird assets.

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.size = Vector2i(1800, 1040)
	var args := OS.get_cmdline_user_args()
	var flight_review := "--flight-sheet" in args
	var motion_review := "--motion-sheet" in args
	var ids: Array[String] = ["robin", "hooded_crow", "gull", "hen", "duck", "gull"]
	var titles: Array[String] = ["EUROPEAN ROBIN", "HOODED CROW", "GULL", "HEN", "MALLARD", "GULL / FLIGHT"]
	if motion_review:
		ids.fill("gull")
		titles = ["REST", "TAKEOFF", "WINGS RAISED", "WINGS LOWERED", "GLIDE", "LANDING"]
	var clips: Array[String] = ["Idle", "TakeOff", "Fly", "Fly", "Glide", "Land"]
	var times: Array[float] = [0, 1.0, 0.25, 0.75, 0, 1.0]
	for i: int in ids.size():
		var view := SubViewport.new()
		view.size = Vector2i(600, 520)
		view.own_world_3d = true
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_COLOR
		env.environment.background_color = Color("25303a")
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color("c4d5e1")
		env.environment.ambient_light_energy = 0.5
		view.add_child(env)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-40, -35, 0)
		light.light_energy = 1.1
		view.add_child(light)
		var fill := DirectionalLight3D.new()
		fill.rotation_degrees = Vector3(-20, 150, 0)
		fill.light_color = Color("9cbedb")
		fill.light_energy = 0.45
		view.add_child(fill)
		var model := (load("res://assets/storybook/%s/%s.glb" % [ids[i], ids[i]]) as PackedScene).instantiate() as Node3D
		view.add_child(model)
		var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var flying := flight_review or motion_review or i == 5
		player.play(clips[i] if motion_review else ("Glide" if flying else "Idle"))
		player.advance(times[i] if motion_review else 0.0)
		player.pause()
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = (1.35 if ids[i] == "robin" else 2.4) if flying else (0.67 if i == 0 else 1.2)
		var target := Vector3(0, (0.6 if ids[i] == "robin" else 0.78) if flying else (0.25 if i == 0 else 0.43), 0)
		camera.position = target + Vector3(1.3, 2.7 if flight_review or motion_review else 0.55, 1.8)
		view.add_child(camera)
		camera.look_at(target)
		var texture := TextureRect.new()
		texture.texture = view.get_texture()
		texture.position = Vector2((i % 3) * 600, (i / 3) * 520)
		texture.size = Vector2(600, 520)
		root.add_child(texture)
		var label := Label.new()
		label.text = titles[i]
		label.position = texture.position + Vector2(24, 22)
		label.add_theme_font_size_override("font_size", 21)
		root.add_child(label)
	for frame: int in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var output := "res://docs/reports/images/bird_realism/after.png"
	for arg: String in args:
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	root.get_texture().get_image().save_png(output)
	quit()
