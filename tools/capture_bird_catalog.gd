extends SceneTree
## Actual runtime catalogue geometry, identical camera fitting before and after.
const Species := preload("res://scripts/map/view3d/map_view_bird_species.gd")
const Meshes := preload("res://scripts/map/view3d/map_view_bird_meshes.gd")

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	root.size = Vector2i(1800, 1040)
	var page := 0
	var flying := false
	var stroke := -1.0
	var output := "res://docs/reports/images/bird_catalog_realism/after_0.png"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--page="):
			page = int(arg.trim_prefix("--page="))
		if arg.begins_with("--stroke="):
			stroke = float(arg.trim_prefix("--stroke="))
			flying = true
		if arg == "--flight":
			flying = true
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	for i in 6:
		var species: StringName = Species.ALL_SPECIES[page * 6 + i]
		var view := SubViewport.new()
		view.size = Vector2i(600, 520)
		view.own_world_3d = true
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.background_color = Color("25303a")
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color = Color("c4d5e1")
		environment.environment.ambient_light_energy = 0.5
		view.add_child(environment)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-40, -35, 0)
		light.light_energy = 1.1
		view.add_child(light)
		var fill := DirectionalLight3D.new()
		fill.rotation_degrees = Vector3(-20, 150, 0)
		fill.light_energy = 0.45
		view.add_child(fill)
		var bounds: AABB
		if stroke >= 0:
			var actor := Node3D.new()
			view.add_child(actor)
			var flight := preload("res://scripts/map/view3d/map_view_bird_flight.gd").new()
			flight._install_species_rig(actor, species)
			flight._apply_wing_pose(actor, stroke)
			var first := true
			for model: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
				var box: AABB = model.global_transform * model.mesh.get_aabb()
				bounds = box if first else bounds.merge(box)
				first = false
			flight.free()
		else:
			var model := MeshInstance3D.new()
			model.mesh = Meshes.mesh_for(species, Species.POSE_GLIDING if flying else Species.POSE_STANDING)
			view.add_child(model)
			bounds = model.mesh.get_aabb()
		var target := bounds.get_center()
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = maxf(bounds.size.y, maxf(bounds.size.x, bounds.size.z)) * 1.3
		camera.position = target + Vector3(1.5, 2.5 if flying else 0.65, -1.8) * camera.size
		view.add_child(camera)
		camera.look_at(target)
		var texture := TextureRect.new()
		texture.texture = view.get_texture()
		texture.position = Vector2((i % 3) * 600, (i / 3) * 520)
		texture.size = Vector2(600, 520)
		root.add_child(texture)
		var label := Label.new()
		label.z_index = 10
		label.text = String(species).replace("_", " ").to_upper()
		label.position = texture.position + Vector2(24, 22)
		label.add_theme_font_size_override("font_size", 21)
		root.add_child(label)
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	root.get_texture().get_image().save_png(output)
	quit()
