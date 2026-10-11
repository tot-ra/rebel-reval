extends SceneTree

## Engine evidence for the authored bird replacements (P0-218).
## Godot --path . --script tools/capture_authored_birds.gd
## Renders every named clip of each replaced species with the runtime import
## chain, so alpha-masked feather cards and the plumage shader are exercised.
const SPECIES: Array[String] = ["hen"]
const CLIPS: Array[String] = ["Idle", "Walk", "Peck", "Fly"]
const CLIP_TIME: Dictionary = {"Idle": 0.0, "Walk": 0.13, "Peck": 0.5, "Fly": 0.25}
const OUT := "res://docs/reports/images/authored_birds/"
const TILE := Vector2i(600, 450)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for species in SPECIES:
		var plate := Image.create(TILE.x * CLIPS.size(), TILE.y, false, Image.FORMAT_RGBA8)
		for index in CLIPS.size():
			var shot := await _capture(species, CLIPS[index])
			var shot_path := "%s%s_%s.png" % [OUT, species, CLIPS[index].to_lower()]
			shot.save_png(ProjectSettings.globalize_path(shot_path))
			plate.blit_rect(shot, Rect2i(Vector2i.ZERO, TILE), Vector2i(index * TILE.x, 0))
		plate.save_png(ProjectSettings.globalize_path("%s%s_plate.png" % [OUT, species]))
	print("Authored bird capture complete")
	quit()


func _capture(species: String, clip: String) -> Image:
	var viewport := SubViewport.new()
	viewport.size = TILE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene := Node3D.new()
	viewport.add_child(scene)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("242d32")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c5d6dd")
	environment.ambient_light_energy = 0.65
	var world := WorldEnvironment.new()
	world.environment = environment
	scene.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -35, 0)
	sun.light_color = Color("fff0d9")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	scene.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(10, 130, 0)
	fill.light_color = Color("a4c6dc")
	fill.light_energy = 0.40
	scene.add_child(fill)

	var packed := load("res://assets/storybook/%s/%s.glb" % [species, species]) as PackedScene
	var model := packed.instantiate() as Node3D
	scene.add_child(model)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	var player := players[0] as AnimationPlayer
	assert(player.has_animation(clip), "%s is missing %s" % [species, clip])
	player.play(clip)
	player.seek(player.get_animation(clip).length * float(CLIP_TIME[clip]), true)
	player.pause()

	var floor_node := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(40, 40)
	floor_node.mesh = floor_mesh
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("303a40")
	floor_material.roughness = 1.0
	floor_node.material_override = floor_material
	scene.add_child(floor_node)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	scene.add_child(camera)
	camera.current = true
	var label := Label.new()
	label.text = "%s / %s" % [species, clip]
	label.position = Vector2(22, 410)
	label.add_theme_font_size_override("font_size", 22)
	viewport.add_child(label)

	for frame in 4:
		await process_frame
	# Frame the deformed skin, not the bind pose, so posed clips stay centred.
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var box := mesh.global_transform * mesh.bake_mesh_from_current_skeleton_pose().get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	var center := bounds.get_center()
	var span := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	camera.size = span * 1.25
	camera.position = center + Vector3(1.65, 0.57, 2.6) * span
	camera.look_at(center)

	await process_frame
	await RenderingServer.frame_post_draw
	var shot := viewport.get_texture().get_image()
	shot.convert(Image.FORMAT_RGBA8)
	viewport.queue_free()
	await process_frame
	return shot
