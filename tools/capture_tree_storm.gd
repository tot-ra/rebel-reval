extends SceneTree

## R-1433 repeatable GPU proof: same pine mesh/camera, frozen shader times.
## Run with tools/godot_render.sh --script tools/capture_tree_storm.gd.


func _initialize() -> void:
	await process_frame
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 720)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.55, 0.64, 0.73)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.8, 0.85, 0.9)
	viewport.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -35, 0)
	viewport.add_child(sun)
	var species := &"pine"
	var scale := CityVegetationBuilder.species_scale(species, 1.0) * 1.8
	var wood := MapViewTreeMeshes.city_wood_mesh(
		species, scale, CityVegetationBuilder.trunk_factor(species, scale)
	)
	var materials: Array[ShaderMaterial] = []
	var meshes: Array[Mesh] = [wood, MapViewTreeMeshes.city_canopy_near_mesh(species, scale)]
	var sources: Array[ShaderMaterial] = [
		MapViewMaterials.bark_plate_wind(MapViewTreeSpecies.bark_plate_for(species), species),
		MapViewMaterials.canopy_for_species(species),
	]
	for i in 2:
		var material := sources[i].duplicate() as ShaderMaterial
		var shader := Shader.new()
		shader.code = sources[i].shader.code.replace(
			"void vertex()", "uniform float capture_time = 0.0;\nvoid vertex()"
		).replace("TIME", "capture_time")
		material.shader = shader
		materials.append(material)
		var instance := MeshInstance3D.new()
		instance.mesh = meshes[i]
		instance.material_override = material
		instance.scale = Vector3.ONE * scale
		instance.extra_cull_margin = 12.0
		viewport.add_child(instance)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(100, 100)
	ground.mesh = plane
	viewport.add_child(ground)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 23.0
	camera.position = Vector3(0, 9, 38)
	viewport.add_child(camera)
	camera.look_at(Vector3(0, 9, 0))
	var sheet := Image.create(2560, 720, false, Image.FORMAT_RGB8)
	var times := [0.0, 1.0, 4.0, 9.0]
	for i in 4:
		MapViewMaterials.apply_world_wind(Vector2.RIGHT, 0.04 if i == 0 else 0.70)
		for material in materials:
			material.set_shader_parameter("capture_time", times[i])
		for frame in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		image.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(image, Rect2i(0, 0, 640, 720), Vector2i(i * 640, 0))
		image.save_png("res://build/scratch/tree_storm_%d.png" % i)
	sheet.save_png("res://build/scratch/tree_storm_sheet.png")
	print("R-1433 capture: calm, storm t=1/4/9s; 18m pine, wind +X, strength 0.70")
	quit()
