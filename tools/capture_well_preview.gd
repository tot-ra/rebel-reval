extends SceneTree

## Close-up capture of the 3D well prop (stone ring, windlass, bucket, gabled
## roof). Run without --headless so the GPU renderer is live:
##   godot --path . --script tools/capture_well_preview.gd

const OUTPUT := "res://build/previews/well_preview.png"
const VIEW_SIZE := Vector2i(1024, 1024)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)

	var scene := Node3D.new()
	viewport.add_child(scene)
	_add_environment(scene)

	var well := MapViewMeshBuilder.build_prop(
		{"id": &"preview_well", "kind": MapTypes.PROP_KIND_WELL, "position": Vector2.ZERO},
		MapTypes.DEFAULT_CELL_SIZE
	)
	scene.add_child(well)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 40.0
	# Front three-quarter view from slightly above the curb, matching the angle
	# the dimetric gameplay camera sees the well at.
	camera.position = Vector3(2.4, 2.2, 2.4)
	camera.look_at_from_position(camera.position, Vector3(0.0, 0.85, 0.0), Vector3.UP)
	viewport.add_child(camera)
	camera.make_current()

	for _frame in 20:
		await process_frame
	var image := viewport.get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT))
	if error != OK:
		push_error("Well preview failed: %s" % error_string(error))
		quit(1)
		return
	print("WELL_PREVIEW=%s" % OUTPUT)
	quit(0)


func _add_environment(scene: Node3D) -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color8(96, 100, 104)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color8(180, 184, 190)
	environment.ambient_light_energy = 0.5
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	scene.add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	sun.light_color = Color8(255, 236, 208)
	sun.light_energy = 0.9
	scene.add_child(sun)
