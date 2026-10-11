extends SceneTree

const OUTPUT := "res://docs/reports/images/view3d/doors/historical_door_closeup.png"
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
	_add_door(scene)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 43.0
	camera.position = Vector3(2.65, 1.72, 4.45)
	camera.look_at_from_position(camera.position, Vector3(0.0, 1.28, 0.0), Vector3.UP)
	viewport.add_child(camera)
	camera.make_current()

	for _frame in 12:
		await process_frame
	var image := viewport.get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT))
	if error != OK:
		push_error("Door preview failed: %s" % error_string(error))
		quit(1)
		return
	print("DOOR_PREVIEW=%s" % OUTPUT)
	quit(0)


func _add_environment(scene: Node3D) -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color8(92, 88, 80)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color8(185, 196, 204)
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	scene.add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	sun.light_color = Color8(255, 224, 188)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	scene.add_child(sun)

	var fill := OmniLight3D.new()
	fill.position = Vector3(-2.2, 1.9, 2.6)
	fill.light_color = Color8(178, 204, 232)
	fill.light_energy = 1.8
	fill.omni_range = 6.0
	scene.add_child(fill)


func _add_door(scene: Node3D) -> void:
	var door := Node3D.new()
	door.name = "HistoricDoorPreview"
	scene.add_child(door)
	MapViewDoorBuilder.add_leaf(door, "Panel", "", 1.5, 2.5, 0.11, Transform3D.IDENTITY, 1343)
	MapViewDoorBuilder.add_frame(door, "", 1.5, 2.5, 0.13, 0.19, Transform3D.IDENTITY, 1343)
	MapViewMeshBuilderPrimitives.box(door, "Threshold", Vector3(1.78, 0.09, 0.34), Vector3(0.0, 0.045, 0.01), &"stone")

	var wall_material := MapViewMaterials.wall_surface_for_size(&"plaster", Color8(189, 174, 142), Vector3(1.6, 3.25, 0.24))
	_add_box(scene, "WallLeft", Vector3(1.55, 3.25, 0.24), Vector3(-1.69, 1.625, -0.12), wall_material)
	_add_box(scene, "WallRight", Vector3(1.55, 3.25, 0.24), Vector3(1.69, 1.625, -0.12), wall_material)
	_add_box(scene, "WallHead", Vector3(1.76, 0.49, 0.24), Vector3(0.0, 3.005, -0.12), wall_material)

	var timber := MapViewMaterials.role_for_size(&"timber", Vector3(4.9, 0.12, 0.12))
	_add_box(scene, "WallBeam", Vector3(4.9, 0.12, 0.12), Vector3(0.0, 2.83, 0.035), timber)
	var floor_material := MapViewMaterials.role_for_size(&"wood", Vector3(5.2, 0.10, 4.0))
	_add_box(scene, "Floor", Vector3(5.2, 0.10, 4.0), Vector3(0.0, -0.05, 1.15), floor_material)


func _add_box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
