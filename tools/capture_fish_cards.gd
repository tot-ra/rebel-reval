extends SceneTree
## Card renders of the in-game fish models (docs/FAUNA/fish/*.md): the actual
## CityFish mesh and runtime shader, three-quarter and side view per species.
## Run: tools/godot_render.sh --script tools/capture_fish_cards.gd
## Optional: -- --out=res://docs/FAUNA/images

const VIEW := Vector2i(640, 420)
const SPECIES: Array[Dictionary] = [
	{"id": "herring", "perch": false},
	{"id": "perch", "perch": true},
]


func _initialize() -> void:
	call_deferred("_capture")


func _view(perch: bool, eye: Vector3) -> SubViewport:
	var view := SubViewport.new()
	view.size = VIEW
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("33454f")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("c8d8e2")
	env.environment.ambient_light_energy = 0.55
	view.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50, 25, 0)
	key.light_energy = 1.2
	view.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, 160, 0)
	fill.light_color = Color("a9c6dc")
	fill.light_energy = 0.5
	view.add_child(fill)
	var fish := MeshInstance3D.new()
	fish.mesh = CityFish.species_mesh(perch)
	fish.material_override = CityFish._species_material(
		CityFish.PERCH_ALBEDO if perch else CityFish.HERRING_ALBEDO, 0.0 if perch else 1.0
	)
	view.add_child(fish)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 0.95
	view.add_child(camera)
	var target := Vector3(-0.12, 0.02, 0.0)
	camera.position = target + eye
	camera.look_at(target)
	return view


func _capture() -> void:
	var out := "res://docs/FAUNA/images"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	# Compose from the SubViewports directly: the minimized render window does
	# not give the root viewport its requested size.
	RenderingServer.global_shader_parameter_set(&"ocean_time", 0.0)
	for s: Dictionary in SPECIES:
		var views: Array[SubViewport] = [
			_view(s["perch"], Vector3(0.9, 1.25, 1.3)), _view(s["perch"], Vector3(0.0, 0.0, 2.0))
		]
		for frame in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		var sheet := Image.create(VIEW.x * 2, VIEW.y, false, Image.FORMAT_RGB8)
		for i in views.size():
			var shot := views[i].get_texture().get_image()
			shot.convert(Image.FORMAT_RGB8)
			sheet.blit_rect(shot, Rect2i(Vector2i.ZERO, VIEW), Vector2i(VIEW.x * i, 0))
			views[i].queue_free()
		var path := "%s/fish_%s_3d.jpg" % [out, s["id"]]
		sheet.save_jpg(path, 0.9)
		print("captured ", path)
		await process_frame
	quit()
