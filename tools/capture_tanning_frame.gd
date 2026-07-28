extends SceneTree

## Reproducible in-engine review capture for the production tanning frame.
## Run with a rendering-capable Godot process:
## godot --path . --script tools/capture_tanning_frame.gd

const TanningFrameModels := preload("res://scripts/map/view3d/map_view_tanning_frame_models.gd")
const OUTPUT := "res://generated/blender/tanning_frame_v1/godot_preview.png"
const VIEWPORT_SIZE := Vector2i(768, 768)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(_build_stage())

	var model_host := Node3D.new()
	model_host.rotation_degrees.y = -12.0
	viewport.add_child(model_host)
	TanningFrameModels.add_model(model_host)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.8
	camera.position = Vector3(2.4, 1.75, 3.0)
	viewport.add_child(camera)
	camera.current = true
	camera.look_at(Vector3(0.0, 0.68, 0.08), Vector3.UP)

	for _frame in 10:
		await process_frame
	var error := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT))
	if error != OK:
		push_error("Could not save tanning frame capture %s: %s" % [OUTPUT, error_string(error)])
		quit(1)
		return
	print("Tanning frame capture: %s" % OUTPUT)
	viewport.queue_free()
	quit(0)


func _build_stage() -> Node3D:
	var stage := Node3D.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.17, 0.22, 0.13)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.65, 0.71, 0.62)
	environment.ambient_light_energy = 0.48
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_color = Color(1.0, 0.86, 0.68)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	stage.add_child(sun)

	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(6.0, 6.0)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.27, 0.34, 0.19)
	floor_material.roughness = 1.0
	floor_mesh.material = floor_material
	var floor_instance := MeshInstance3D.new()
	floor_instance.mesh = floor_mesh
	stage.add_child(floor_instance)
	return stage
