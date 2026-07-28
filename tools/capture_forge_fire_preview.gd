extends SceneTree

## Close-up capture of the smithy furnace hearth fire (flame tongues, sparks,
## smoke, ember bed). Run without --headless so the GPU renderer is live:
##   godot --path . --script tools/capture_forge_fire_preview.gd

const OUTPUT := "res://build/previews/forge_fire_preview.png"
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

	var furnace := MapViewMeshBuilder.build_prop(
		{"id": &"forge_furnace", "kind": MapTypes.PROP_KIND_FURNACE, "position": Vector2.ZERO},
		MapTypes.DEFAULT_CELL_SIZE
	)
	scene.add_child(furnace)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 38.0
	# Firebox mouth faces +Z; frame it close so flame tongues fill the view.
	camera.position = Vector3(0.6, 1.05, 3.1)
	camera.look_at_from_position(camera.position, Vector3(0.0, 0.75, 0.5), Vector3.UP)
	viewport.add_child(camera)
	camera.make_current()

	# Let the particle systems develop full motion before the capture.
	for _frame in 45:
		await process_frame
	var image := viewport.get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT))
	if error != OK:
		push_error("Forge fire preview failed: %s" % error_string(error))
		quit(1)
		return
	print("FORGE_FIRE_PREVIEW=%s" % OUTPUT)
	quit(0)


func _add_environment(scene: Node3D) -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	# Dusk-gray room so the emissive fire reads like it does indoors.
	environment.background_color = Color8(38, 36, 34)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color8(120, 128, 138)
	environment.ambient_light_energy = 0.35
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	scene.add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	sun.light_color = Color8(255, 224, 188)
	sun.light_energy = 0.6
	scene.add_child(sun)
