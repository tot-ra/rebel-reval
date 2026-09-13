extends SceneTree

## Matched production-mesh review; -- before|after selects the output folder.
const OUTPUT := "res://docs/reports/images/vegetation_realism/"
var viewport: SubViewport
var camera: Camera3D
var stage: Node3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var label := args[0] if not args.is_empty() else "after"
	viewport = SubViewport.new()
	viewport.size = Vector2i(1440, 900)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	stage = Node3D.new()
	viewport.add_child(stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("849399")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b4c5cf")
	env.ambient_light_energy = 0.55
	var world := WorldEnvironment.new()
	world.environment = env
	stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -125, 0)
	sun.light_color = Color("fff0d4")
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	stage.add_child(sun)
	var ground := PlaneMesh.new()
	ground.size = Vector2(50, 50)
	var earth := StandardMaterial3D.new()
	earth.albedo_color = Color("454a2f")
	earth.roughness = 1.0
	_add_mesh(ground, earth, Vector3(0, -0.02, 0))
	var species: Array[StringName] = [&"birch", &"oak", &"spruce", &"willow", &"alder"]
	for i in species.size():
		var location := Vector3((i - 2) * 3.4, 0, -1.5)
		_add_mesh(
			MapViewTreeMeshes.wood_mesh(species[i]),
			MapViewMaterials.bark(MapViewTreeSpecies.bark_kind_for(species[i])),
			location
		)
		_add_mesh(
			MapViewTreeMeshes.canopy_mesh(species[i]),
			MapViewMaterials.canopy(MapViewTreeSpecies.canopy_material_kind(species[i])),
			location
		)
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for i in 1800:
		var x := MapViewMeshBuilderMath.hash01(i, 3, 991) * 18.0 - 9.0
		var z := MapViewMeshBuilderMath.hash01(i, 7, 997) * 8.0 - 3.0
		var scale := 0.48 + MapViewMeshBuilderMath.hash01(i, 11, 1009) * 0.65
		transforms.append(
			Transform3D(Basis(Vector3.UP, float(i)).scaled(Vector3.ONE * scale), Vector3(x, 0, z))
		)
		colors.append(
			Color(0.82, 0.98, 0.72).lerp(
				Color(1.08, 1.0, 0.86), MapViewMeshBuilderMath.hash01(i, 13, 1013)
			)
		)
	var grass := MapViewMeshBuilderPrimitives.multi_mesh(
		"Grass",
		MapViewFoliageMeshes.grass_tuft_mesh(),
		transforms,
		colors,
		MapViewMaterials.grass_blades(),
		Vector3.ZERO
	)
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stage.add_child(grass)
	camera = Camera3D.new()
	camera.position = Vector3(9.5, 3.0, 14)
	camera.fov = 52
	stage.add_child(camera)
	camera.look_at(Vector3(0, 1.8, -1))
	camera.current = true
	MapViewMaterials.apply_world_wind(Vector2(0.9, 0.3), 0.22)
	await _capture(label, "stand")
	camera.position = Vector3(0.7, 0.50, 5.3)
	camera.look_at(Vector3(0, 0.25, 2))
	await _capture(label, "grass")
	MapViewMaterials.apply_world_wind(Vector2(0.9, 0.3), 0.0)
	await _capture(label, "calm_a")
	await _capture(label, "calm_b")
	MapViewMaterials.apply_world_wind(Vector2(0.9, 0.3), 0.85)
	await _capture(label, "wind_a")
	for i in 30:
		await process_frame
	await _capture(label, "wind_b")
	# Real district terrain and authored cover, rendered at its actual elevation.
	for child in stage.get_children():
		if child is GeometryInstance3D:
			child.hide()
	var definition := LowerTownSliceDefinition.create()
	var grid := MapBuilder.build(definition)
	var details := MapViewTerrainDetails.build_chunk(definition, grid, Rect2i(7, 73, 9, 14), true)
	var terrain := MapViewMeshBuilderTerrain.build_terrain(definition, grid)
	details.position = Vector3(-11, 0, -79)
	terrain.position = details.position
	stage.add_child(terrain)
	stage.add_child(details)
	camera.position = Vector3(4, 1.0, 6)
	camera.look_at(Vector3(0, 0.1, 0))
	await _capture(label, "district_cover")
	terrain.hide()
	details.hide()
	var bush := MeshInstance3D.new()
	bush.mesh = MapViewBushMeshes.mesh_for(MapViewBushSpecies.ALL_SPECIES[0])
	bush.material_override = MapViewMaterials.canopy(&"leaf")
	stage.add_child(bush)
	camera.position = Vector3(1.2, 0.8, 2.0)
	camera.look_at(Vector3(0, 0.35, 0))
	await _capture(label, "bush_wind_a")
	for frame in 30:
		await process_frame
	await _capture(label, "bush_wind_b")
	# A material with transmission must not become luminous in unlit scenes.
	sun.light_energy = 0.0
	env.ambient_light_energy = 0.0
	env.background_color = Color.BLACK
	await _capture(label, "unlit")
	for entry in MapViewTreeSpecies.ALL_SPECIES:
		print(
			"Canopy triangles ",
			entry,
			": ",
			MapViewTreeMeshes.geometry_stats(entry)["canopy_triangles"]
		)
	stage.queue_free()
	await process_frame
	var live_view := MapView3D.create(definition, grid)
	viewport.add_child(live_view)
	live_view.set_close_camera_mode(true)
	camera = live_view.view_camera()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 65
	var eye := live_view.world_position(Vector2(11, 85) * definition.cell_size)
	camera.position = eye + Vector3(0, 1.65, 0)
	camera.look_at(eye + Vector3(-2, 0.35, -3))
	live_view.update_terrain_detail_focus(camera.position)
	await _capture(label, "district_live")
	viewport.queue_free()
	await process_frame
	quit()


func _add_mesh(mesh: Mesh, material: Material, location: Vector3) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = location
	stage.add_child(instance)


func _capture(label: String, view: String) -> void:
	for frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var directory := ProjectSettings.globalize_path(OUTPUT + label)
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory.path_join(view + ".png")
	var error := viewport.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Vegetation capture failed: %s" % error_string(error))
		quit(1)
	print("Vegetation capture: ", path)
