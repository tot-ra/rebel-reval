extends SceneTree

## R-2297 proof plate for the Meshy domestic goose in real Godot materials.
## Row 1: previous procedural goose (optional GLB passed with --before <path>), new goose
## 3/4, head, and beside a hen for scale. Row 2: three Walk frames from the side and Peck.
## The new goose goes through the runtime loader, so MODEL_SCALE, MODEL_YAW and the bird
## plumage import script all apply.
##   tools/godot_render.sh --script tools/capture_goose_v2.gd -- \
##     --before res://build/goose_meshy/goose_before.glb
## Output: docs/reports/images/goose_v2/goose_v2_plate.png

const Models := preload("res://scripts/map/view3d/map_view_medieval_animal_models.gd")
const MammalSpecies := preload("res://scripts/map/view3d/map_view_mammal_species.gd")
const OUT := "res://docs/reports/images/goose_v2/"
const CELL := Vector2i(640, 480)
const BEFORE_SCALE := 0.45


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
	shots.append({"view": "q34", "clip": "Idle", "t": 0.0, "label": "after 3/4"})
	shots.append({"view": "head", "clip": "Idle", "t": 0.0, "label": "after head"})
	shots.append({"view": "hen", "clip": "Idle", "t": 0.0, "label": "beside a hen"})
	for i in 3:
		shots.append({"view": "side", "clip": "Walk", "t": i / 3.0, "label": "walk %d/3" % i})
	shots.append({"view": "side", "clip": "Peck", "t": 0.4, "label": "peck"})
	for index in shots.size():
		var shot := await _shot(shots[index])
		plate.blit_rect(
			shot, Rect2i(Vector2i.ZERO, CELL), Vector2i(index % 4 * CELL.x, index / 4 * CELL.y)
		)
	plate.save_png(ProjectSettings.globalize_path(OUT + "goose_v2_plate.png"))
	print("plate: ", OUT + "goose_v2_plate.png")
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
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_color = Color("fff3e0")
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	scene.add_child(sun)
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(40, 40)
	var floor_node := MeshInstance3D.new()
	floor_node.mesh = floor_mesh
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("4d5a32")
	floor_material.roughness = 1.0
	floor_node.material_override = floor_material
	scene.add_child(floor_node)
	var host := Node3D.new()
	scene.add_child(host)
	var model: Node3D
	if spec.has("path"):
		# The previous goose lives outside the import tree; load it without importing.
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		assert(document.append_from_file(String(spec["path"]), state) == OK)
		model = document.generate_scene(state) as Node3D
		model.scale *= BEFORE_SCALE
		host.add_child(model)
	else:
		model = Models.add_model(host, MammalSpecies.SPECIES_GOOSE)
	if String(spec["view"]) == "hen":
		var hen_host := Node3D.new()
		hen_host.position = Vector3(0.75, 0.0, 0.1)
		hen_host.rotation_degrees.y = 30.0
		scene.add_child(hen_host)
		Models.add_model(hen_host, MammalSpecies.SPECIES_CHICKEN)
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	player.play(String(spec["clip"]))
	player.seek(float(spec["t"]) * player.current_animation_length, true)
	player.pause()
	# Runtime-loaded geese face -Z (bill first); the camera targets are in host space.
	var views := {
		"q34": [Vector3(-1.25, 0.85, -1.35), Vector3(0, 0.33, -0.05)],
		"head": [Vector3(-0.55, 0.75, -0.85), Vector3(0, 0.55, -0.2)],
		"hen": [Vector3(0.2, 0.9, -2.1), Vector3(0.4, 0.3, 0.0)],
		"side": [Vector3(-2.1, 0.5, 0.0), Vector3(0, 0.33, 0.0)],
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
