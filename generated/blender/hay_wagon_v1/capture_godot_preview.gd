extends SceneTree

## Evidence-only in-engine render for the composite hay wagon. It uses the same
## orthographic pitch and yaw as MapView3D so wheel stance and load fit are visible.

const OUTPUT_PATH := "res://generated/blender/hay_wagon_v1/godot_preview.png"
const VIEWPORT_SIZE := Vector2i(960, 640)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("8bb47a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("dbe5d2")
	environment.ambient_light_energy = 0.75
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	viewport.add_child(world_environment)

	var stage := Node3D.new()
	viewport.add_child(stage)

	var ground := MeshInstance3D.new()
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(8.0, 8.0)
	ground.mesh = ground_mesh
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("719b60")
	ground_material.roughness = 1.0
	ground.material_override = ground_material
	stage.add_child(ground)

	var prop := MapViewMeshBuilder.build_prop(
		{
			"id": &"evidence.hay_wagon",
			"kind": MapTypes.PROP_KIND_HAY_WAGON,
			"position": Vector2.ZERO,
		},
		MapTypes.DEFAULT_CELL_SIZE
	)
	stage.add_child(prop)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	sun.light_color = Color("f3e5c6")
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	stage.add_child(sun)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.rotation_degrees = Vector3(MapView3D.CAMERA_PITCH_DEGREES, MapView3D.CAMERA_YAW_DEGREES, 0.0)
	camera.size = 3.2
	camera.position = Vector3(0.0, 0.56, 0.0) + camera.transform.basis.z * 6.0
	camera.current = true
	stage.add_child(camera)

	for frame in 6:
		await process_frame
	var image := viewport.get_texture().get_image()
	var absolute_path := ProjectSettings.globalize_path(OUTPUT_PATH)
	var error := image.save_png(absolute_path)
	if error != OK:
		push_error("Could not save hay wagon Godot preview: %s" % error_string(error))
		quit(1)
		return

	var metrics := _mesh_metrics(prop)
	print("HAY_WAGON_METRICS=%s" % JSON.stringify(metrics))
	print("HAY_WAGON_GODOT_PREVIEW=%s" % OUTPUT_PATH)
	quit(0)


func _mesh_metrics(prop: Node3D) -> Dictionary:
	var bounds := AABB()
	var first := true
	var triangles := 0
	var surfaces := 0
	var material_ids: Dictionary = {}
	for child in prop.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var child_bounds := mesh_instance.global_transform * mesh_instance.get_aabb()
		bounds = child_bounds if first else bounds.merge(child_bounds)
		first = false
		for surface_index in mesh_instance.mesh.get_surface_count():
			surfaces += 1
			var index_count: int = mesh_instance.mesh.surface_get_array_index_len(surface_index)
			var vertex_count: int = mesh_instance.mesh.surface_get_array_len(surface_index)
			triangles += (index_count if index_count > 0 else vertex_count) / 3
			var material := mesh_instance.material_override
			if material == null:
				material = mesh_instance.mesh.surface_get_material(surface_index)
			if material != null:
				material_ids[material.get_instance_id()] = true
	return {
		"dimensions_m": [bounds.size.x, bounds.size.y, bounds.size.z],
		"ground_min_y": bounds.position.y,
		"materials": material_ids.size(),
		"mesh_instances": prop.find_children("*", "MeshInstance3D", true, false).size(),
		"surfaces": surfaces,
		"triangles": triangles,
	}
