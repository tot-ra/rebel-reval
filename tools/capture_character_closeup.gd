extends SceneTree

## Close-up proportion audit for the shared character rig. Renders the rig at
## portrait distance from the gameplay isometric angle plus front/profile
## turnaround views so silhouette changes can be judged before the gameplay
## scale hides them. Requires a rendering-capable run (no --headless):
## godot --path . --script tools/capture_character_closeup.gd \
##   [-- --output-dir=PATH --scene=res://path/to/rig.tscn]

const KALEV_SCENE := preload("res://assets/characters/kalev/kalev.tscn")
const DEFAULT_OUTPUT_DIR := "res://docs/reports/images/characters"
const VIEWPORT_SIZE := Vector2i(720, 900)
const FIGURE_HEIGHT := 2.0

const VIEWS: Array[Dictionary] = [
	{"slug": "iso_idle", "animation": &"idle", "yaw_degrees": 0.0, "camera": "iso"},
	{"slug": "front_idle", "animation": &"idle", "yaw_degrees": 0.0, "camera": "front"},
	{"slug": "profile_idle", "animation": &"idle", "yaw_degrees": 90.0, "camera": "front"},
	{"slug": "iso_walk", "animation": &"walk", "yaw_degrees": 0.0, "camera": "iso"},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_dir := _output_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(_build_stage())

	var scene: PackedScene = KALEV_SCENE
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--scene="):
			scene = load(argument.trim_prefix("--scene=")) as PackedScene
	var rig: SharedCharacterRig = scene.instantiate()
	viewport.add_child(rig)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = FIGURE_HEIGHT * 1.35
	viewport.add_child(camera)
	camera.current = true

	for view: Dictionary in VIEWS:
		rig.rotation_degrees = Vector3(0.0, view["yaw_degrees"], 0.0)
		rig.play_animation(view["animation"], 0.0)
		_place_camera(camera, view["camera"])
		# Let the pose settle mid-stride instead of at the clip's first frame.
		for _frame in 20:
			await process_frame
		var output := "%s/closeup_%s.png" % [output_dir, view["slug"]]
		var error := viewport.get_texture().get_image().save_png(
			ProjectSettings.globalize_path(output)
		)
		if error != OK:
			push_error("Could not save close-up %s: %s" % [output, error_string(error)])
			quit(1)
			return
		print("Character close-up: %s" % output)

	viewport.queue_free()
	quit(0)


func _place_camera(camera: Camera3D, kind: String) -> void:
	var focus := Vector3(0.0, FIGURE_HEIGHT * 0.5, 0.0)
	if kind == "iso":
		# Matches the gameplay camera direction from the showcase scene.
		camera.position = focus + Vector3(20.0, 15.0, 20.0).normalized() * 12.0
	else:
		camera.position = focus + Vector3(0.0, 0.0, 12.0)
	camera.look_at(focus, Vector3.UP)


func _build_stage() -> Node3D:
	var stage := Node3D.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.035, 0.047, 0.047)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.604, 0.678, 0.741)
	environment.ambient_light_energy = 0.42
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
	floor_mesh.size = Vector2(30.0, 30.0)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.106, 0.125, 0.122)
	floor_material.roughness = 1.0
	floor_mesh.material = floor_material
	var floor_instance := MeshInstance3D.new()
	floor_instance.mesh = floor_mesh
	stage.add_child(floor_instance)
	return stage


func _output_dir() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="):
			return argument.trim_prefix("--output-dir=")
	return DEFAULT_OUTPUT_DIR
