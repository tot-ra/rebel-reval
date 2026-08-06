extends SceneTree

## Close-up render of the P2-024 street dog production GLB (medieval_dog.glb).
## Reuses the P0-118 reference stage lighting. Run with a rendering-capable
## Godot process (headless hits the dummy renderer):
## /Applications/Godot.app/Contents/MacOS/Godot --path . \
##   --rendering-driver metal --script tools/capture_dog_closeup.gd

const MammalSpecies := preload("res://scripts/map/view3d/map_view_mammal_species.gd")
const MedievalAnimalModels := preload("res://scripts/map/view3d/map_view_medieval_animal_models.gd")

const OUTPUT := "res://build/previews/dog_closeup.png"
const VIEWPORT_SIZE := Vector2i(1600, 900)


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

	# Three views of the same dog: front-left 3/4, profile, and rear 3/4 so the
	# muzzle, ears, legs, and raised tail are all reviewable in one plate.
	var views: Array[Vector3] = [
		Vector3(-8.0, -28.0, 0.0),
		Vector3(-6.0, 90.0, 0.0),
		Vector3(-8.0, 208.0, 0.0),
	]
	for index in views.size():
		var dog := _dog_instance(views[index])
		dog.position = Vector3((float(index) - 1.0) * 1.1, 0.0, 0.0)
		viewport.add_child(dog)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.35
	camera.position = Vector3(0.0, 0.42, 6.0)
	viewport.add_child(camera)
	camera.current = true
	camera.look_at(Vector3(0.0, 0.30, 0.0), Vector3.UP)

	for _frame in 8:
		await process_frame
	var error := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT))
	if error != OK:
		push_error("Could not save dog closeup %s: %s" % [OUTPUT, error_string(error)])
		quit(1)
		return
	print("Dog closeup: %s" % OUTPUT)
	viewport.queue_free()
	quit(0)


func _dog_instance(view_rotation_degrees: Vector3) -> Node3D:
	var root_3d := Node3D.new()
	root_3d.name = "Dog"
	var model := MedievalAnimalModels.add_model(root_3d, MammalSpecies.SPECIES_DOG)
	assert(model != null, "medieval_dog.glb must be imported before the closeup capture")
	model.rotation_degrees = view_rotation_degrees
	return root_3d


func _build_stage() -> Node3D:
	var stage := Node3D.new()
	stage.name = "ReferenceStage"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("20282b")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d7e0df")
	environment.ambient_light_energy = 0.62
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42.0, -34.0, 0.0)
	key.light_color = Color("ffe0b4")
	key.light_energy = 1.1
	key.shadow_enabled = true
	stage.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(22.0, 148.0, 0.0)
	fill.light_color = Color("9bbac8")
	fill.light_energy = 0.48
	stage.add_child(fill)

	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var plane := PlaneMesh.new()
	plane.size = Vector2(8.0, 4.0)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("4a4a44")
	ground_material.roughness = 0.95
	ground.material_override = ground_material
	stage.add_child(ground)
	return stage
