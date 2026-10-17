extends SceneTree

## R-1173 proof plate for the Meshy horse in real Godot materials.
## Row 1: previous horse (optional GLB passed with --before <path>), new horse 3/4, head.
## Row 2: four Walk frames from the side; the mane and tail chains are baked secondary
## motion, so they must differ between frames.
##   tools/godot_render.sh --script tools/capture_horse_v2.gd -- \
##     --before res://build/horse_meshy/donor_horse_v2.glb
## Output: docs/reports/images/horse_v2/horse_v2_plate.png

const OUT := "res://docs/reports/images/horse_v2/"
const MODEL := "res://assets/animals/horse/horse.glb"
const CELL := Vector2i(640, 480)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var before_path := ""
	if "--before" in args:
		before_path = args[args.find("--before") + 1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var plate := Image.create(CELL.x * 4, CELL.y * 2, false, Image.FORMAT_RGBA8)
	plate.fill(Color("1c2226"))
	var shots: Array[Dictionary] = []
	if not before_path.is_empty():
		shots.append({"path": before_path, "view": "q34", "clip": "Idle", "t": 0.0, "label": "before"})
	shots.append({"path": MODEL, "view": "q34", "clip": "Idle", "t": 0.0, "label": "after 3/4"})
	shots.append({"path": MODEL, "view": "head", "clip": "Idle", "t": 0.0, "label": "after head"})
	shots.append({"path": MODEL, "view": "back", "clip": "Idle", "t": 0.0, "label": "after tail"})
	for i in 4:
		shots.append(
			{"path": MODEL, "view": "side", "clip": "Walk", "t": i / 4.0, "label": "walk %d/4" % i}
		)
	for index in shots.size():
		var shot := await _shot(shots[index])
		plate.blit_rect(
			shot, Rect2i(Vector2i.ZERO, CELL), Vector2i(index % 4 * CELL.x, index / 4 * CELL.y)
		)
		shot.save_png(ProjectSettings.globalize_path(OUT + "horse_v2_%d.png" % index))
	plate.save_png(ProjectSettings.globalize_path(OUT + "horse_v2_plate.png"))
	print("plate: ", OUT + "horse_v2_plate.png")
	quit()


func _shot(spec: Dictionary) -> Image:
	var viewport := SubViewport.new()
	viewport.size = CELL
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene := Node3D.new()
	viewport.add_child(scene)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("8fa6b6")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c8d6df")
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	scene.add_child(world)
	# Noon sun with a cool sky fill.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-62, -30, 0)
	sun.light_color = Color("fff3e0")
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	scene.add_child(sun)
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(60, 60)
	var floor_node := MeshInstance3D.new()
	floor_node.mesh = floor_mesh
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("6b6458")
	floor_material.roughness = 1.0
	floor_node.material_override = floor_material
	scene.add_child(floor_node)
	var path := String(spec["path"])
	var model: Node3D
	if path == MODEL:
		model = (load(path) as PackedScene).instantiate() as Node3D
	else:
		# The previous horse lives outside the import tree; load it without importing.
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		assert(document.append_from_file(path, state) == OK)
		model = document.generate_scene(state) as Node3D
	scene.add_child(model)
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	player.play(String(spec["clip"]))
	player.seek(float(spec["t"]) * player.current_animation_length, true)
	player.pause()
	# Unrotated GLB: nose on +Z (runtime MODEL_YAW turns it to -Z), +X is the mane side.
	var views := {
		"q34": [Vector3(3.6, 1.9, 3.4), Vector3(0, 0.95, 0.1)],
		"head": [Vector3(1.5, 1.75, 2.4), Vector3(0, 1.4, 0.95)],
		"back": [Vector3(2.4, 1.6, -3.0), Vector3(0, 0.95, -0.8)],
		"side": [Vector3(5.2, 1.1, 0.1), Vector3(0, 0.9, 0.1)],
	}
	var view: Array = views[String(spec["view"])]
	var camera := Camera3D.new()
	camera.fov = 40
	scene.add_child(camera)
	camera.position = view[0]
	camera.look_at(view[1])
	camera.current = true
	var label := Label.new()
	label.text = String(spec["label"])
	label.position = Vector2(16, CELL.y - 40)
	label.add_theme_font_size_override("font_size", 22)
	viewport.add_child(label)
	for frame in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	viewport.queue_free()
	await process_frame
	return image
