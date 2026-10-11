extends SceneTree

## Close-up capture of the 3D well prop (limestone shaft, windlass, tin bucket, board
## roof). Run without --headless so the GPU renderer is live:
##   tools/godot_render.sh --script tools/capture_well_preview.gd

## Extra shots: low front view for the windlass/rope, and a steep view close to
## the gameplay camera that shows the depth of the shaft mouth.
const SHOTS := {
	"res://build/previews/well_preview.png": [Vector3(2.4, 2.2, 2.4), Vector3(0.0, 0.85, 0.0)],
	"res://build/previews/well_preview_low.png": [Vector3(0.3, 1.0, 2.7), Vector3(0.0, 1.0, 0.0)],
	"res://build/previews/well_preview_top.png": [Vector3(0.2, 2.5, 2.6), Vector3(0.0, 0.7, 0.0)],
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

	var well := MapViewMeshBuilder.build_prop(
		{"id": &"preview_well", "kind": MapTypes.PROP_KIND_WELL, "position": Vector2.ZERO},
		MapTypes.DEFAULT_CELL_SIZE
	)
	scene.add_child(well)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 40.0
	viewport.add_child(camera)
	camera.make_current()

	# The first shot is a front three-quarter view from slightly above the curb,
	# matching the angle the dimetric gameplay camera sees the well at.
	for output: String in SHOTS:
		var shot: Array = SHOTS[output]
		camera.look_at_from_position(shot[0], shot[1], Vector3.UP)
		for _frame in 20:
			await process_frame
		var image := viewport.get_texture().get_image()
		var error := image.save_png(ProjectSettings.globalize_path(output))
		if error != OK:
			push_error("Well preview failed: %s" % error_string(error))
			quit(1)
			return
		print("WELL_PREVIEW=%s" % output)
	# Orthographic shot: the gameplay map camera is orthographic, which takes a
	# separate branch in map_view_well_shaft.gdshader.
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.4
	camera.look_at_from_position(Vector3(4.0, 4.4, 4.0), Vector3(0.0, 0.8, 0.0), Vector3.UP)
	for _frame in 20:
		await process_frame
	var ortho_output := "res://build/previews/well_preview_ortho.png"
	var ortho_error := viewport.get_texture().get_image().save_png(
		ProjectSettings.globalize_path(ortho_output)
	)
	if ortho_error != OK:
		push_error("Well preview failed: %s" % error_string(ortho_error))
		quit(1)
		return
	print("WELL_PREVIEW=%s" % ortho_output)
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
