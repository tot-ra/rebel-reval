extends SceneTree

## Close-up capture of the coopered wash tub prop (staves, ear staves, withy hoops,
## washing bat; task R-1190). Run without --headless so the GPU renderer is live:
##   tools/godot_render.sh --script tools/capture_wash_tub_preview.gd

## Shots: front three-quarter, low side view through the ear-stave pole holes,
## and a steep view close to the gameplay camera showing water below the rim.
const SHOTS := {
	"res://build/previews/wash_tub_preview.png":
	[Vector3(1.25, 1.35, 1.55), Vector3(0.0, 0.28, 0.0)],
	"res://build/previews/wash_tub_preview_low.png":
	[Vector3(0.25, 0.55, 1.9), Vector3(0.0, 0.4, 0.0)],
	"res://build/previews/wash_tub_preview_top.png":
	[Vector3(1.4, 2.9, 1.7), Vector3(0.0, 0.3, 0.0)],
}
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

	var tub := MapViewMeshBuilder.build_prop(
		{"id": &"preview_wash_tub", "kind": MapTypes.PROP_KIND_WASH_TUB, "position": Vector2.ZERO},
		MapTypes.DEFAULT_CELL_SIZE
	)
	scene.add_child(tub)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 40.0
	viewport.add_child(camera)
	camera.make_current()

	for output: String in SHOTS:
		var shot: Array = SHOTS[output]
		camera.look_at_from_position(shot[0], shot[1], Vector3.UP)
		for _frame in 20:
			await process_frame
		var image := viewport.get_texture().get_image()
		var error := image.save_png(ProjectSettings.globalize_path(output))
		if error != OK:
			push_error("Wash tub preview failed: %s" % error_string(error))
			quit(1)
			return
		print("WASH_TUB_PREVIEW=%s" % output)
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
