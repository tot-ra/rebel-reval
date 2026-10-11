extends SceneTree

## Matched original/new assets with actual Godot materials and deformed poses.
## Godot --path . --script tools/capture_animal_realism.gd -- [--before] [--walk]
const SPECIES: Array[String] = ["forge_cat", "sheep", "dog", "pig", "goat", "boar", "fox", "hare", "rat"]
const OUT := "res://docs/reports/images/animal_realism/"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var candidate := "--candidate" in OS.get_cmdline_user_args()
	var legs_before := "--legs-before" in OS.get_cmdline_user_args()
	var before := "--before" in OS.get_cmdline_user_args() or legs_before
	var side := "--side" in OS.get_cmdline_user_args()
	var front := "--front" in OS.get_cmdline_user_args()
	var walking := "--walk" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var plate := Image.create(1800, 1350, false, Image.FORMAT_RGBA8)
	var index := 0
	for species in SPECIES:
		if candidate and not FileAccess.file_exists("res://build/animal_redo/candidates/" + species + ".glb"):
			continue
		var viewport := SubViewport.new()
		viewport.size = Vector2i(600, 450)
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
		# GLTFDocument also loads ignored before assets without changing imports.
		var path := ("res://build/animal_redo/candidates/" if candidate else "res://build/animal_realism/legs_before/" if legs_before else "res://build/animal_realism/before/" if before else "res://assets/storybook/%s/" % species) + species + ".glb"
		var model: Node3D
		if before or candidate:
			var document := GLTFDocument.new()
			var state := GLTFState.new()
			assert(document.append_from_file(path, state) == OK)
			model = document.generate_scene(state) as Node3D
		else:
			var packed := load(path) as PackedScene
			assert(packed != null)
			model = packed.instantiate() as Node3D
		scene.add_child(model)
		var bounds := AABB()
		var first := true
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			var box := mesh.global_transform * mesh.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
		var center := bounds.get_center()
		var span := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = span * 1.18
		scene.add_child(camera)
		camera.position = center + (Vector3(3, .015, 0) if side else Vector3(0, .06, 3) if front else Vector3(1.65, .57, 2.6)) * span
		camera.look_at(center)
		camera.current = true
		var floor_mesh := PlaneMesh.new()
		floor_mesh.size = Vector2(span * 100, span * 100)
		var floor_node := MeshInstance3D.new()
		floor_node.mesh = floor_mesh
		var floor_material := StandardMaterial3D.new()
		floor_material.albedo_color = Color("303a40")
		floor_material.roughness = 1.0
		floor_node.material_override = floor_material
		scene.add_child(floor_node)
		var players := model.find_children("*", "AnimationPlayer", true, false)
		if not players.is_empty():
			var player := players[0] as AnimationPlayer
			if player.has_animation("Walk" if walking else "Idle"):
				player.play("Walk" if walking else "Idle")
				player.seek(.42 if walking else 0.0, true)
				player.pause()
		var label := Label.new()
		label.text = species.replace("_", " ").capitalize() + (" / walk" if walking else "")
		label.position = Vector2(22, 410)
		label.add_theme_font_size_override("font_size", 22)
		viewport.add_child(label)
		for frame in 4:
			await process_frame
		# Authored rigs can retain bind-space bounds far from the posed body.
		# Frame actual skinned geometry so the rat's upright idle stays grounded.
		first = true
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			var posed := mesh.bake_mesh_from_current_skeleton_pose()
			var box := mesh.global_transform * posed.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
		center = bounds.get_center()
		span = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
		camera.size = span * 1.18
		camera.position = center + (Vector3(3, .015, 0) if side else Vector3(0, .06, 3) if front else Vector3(1.65, .57, 2.6)) * span
		camera.look_at(center)
		await process_frame
		await RenderingServer.frame_post_draw
		var shot := viewport.get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		var prefix := "candidate" if candidate else "legs_before" if legs_before else "before" if before else "after"
		var suffix := ("_side" if side else "_front" if front else "") + ("_walk" if walking else "")
		shot.save_png(ProjectSettings.globalize_path(OUT + prefix + "_" + species + suffix + ".png"))
		plate.blit_rect(shot, Rect2i(0, 0, 600, 450), Vector2i(index % 3 * 600, index / 3 * 450))
		index += 1
		viewport.queue_free()
		await process_frame
	plate.save_png(ProjectSettings.globalize_path(OUT + ("candidate" if candidate else "legs_before" if legs_before else "before" if before else "after") + ("_side" if side else "_front" if front else "") + ("_walk" if walking else "") + "_plate.png"))
	print("Animal realism capture complete")
	quit()
