extends SceneTree

## Renders the four authored presentation phases for light and charged hammer
## attacks. Run with a rendering-capable Godot process (no --headless):
## godot --path . --script tools/capture_hammer_attack_phases.gd

const KALEV_SCENE := preload("res://assets/characters/kalev/kalev.tscn")
const OUTPUT_DIR := "res://docs/reports/images/combat"
const VIEWPORT_SIZE := Vector2i(1440, 720)
const PHASE_LABELS: Array[String] = [
	"ANTICIPATION",
	"ACCELERATION",
	"CONTACT / HIT-STOP",
	"FOLLOW-THROUGH",
]
const CAPTURES: Array[Dictionary] = [
	{
		"slug": "hammer_attack_light_phases",
		"title": "LIGHT - 1H CHOP",
		"animation": &"hammer_attack",
		"times": [0.14, 0.28, 0.36, 0.62],
	},
	{
		"slug": "hammer_attack_charged_phases",
		"title": "CHARGED - 2H CHOP",
		"animation": &"hammer_charged_attack",
		"times": [0.22, 0.43, 0.55, 0.82],
	},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for capture: Dictionary in CAPTURES:
		await _capture(capture)
	quit(0)


func _capture(capture: Dictionary) -> void:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(_build_stage())

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.2
	viewport.add_child(camera)
	camera.current = true
	camera.position = Vector3(6.0, 4.5, 8.0)
	camera.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)
	var screen_right := camera.global_transform.basis.x.normalized()

	var times: Array = capture["times"]
	for index in times.size():
		var rig := KALEV_SCENE.instantiate() as SharedCharacterRig
		rig.position = screen_right * (-3.6 + float(index) * 2.4)
		viewport.add_child(rig)
		rig.play_animation(capture["animation"], 0.0)
		rig.sync_action_presentation(capture["animation"], float(times[index]))
	_add_labels(viewport, String(capture["title"]))

	for _frame in 4:
		await process_frame
	var output := "%s/%s.png" % [OUTPUT_DIR, capture["slug"]]
	var error := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(output))
	if error != OK:
		push_error("Could not save hammer phase capture %s: %s" % [output, error_string(error)])
		quit(1)
		return
	print("Hammer attack phase capture: %s" % output)
	viewport.queue_free()
	await process_frame


func _add_labels(viewport: SubViewport, title: String) -> void:
	var layer := CanvasLayer.new()
	viewport.add_child(layer)
	var header := Label.new()
	header.text = title
	header.position = Vector2(32.0, 24.0)
	header.add_theme_font_size_override("font_size", 28)
	header.add_theme_color_override("font_color", Color(1.0, 0.83, 0.53))
	layer.add_child(header)
	for index in PHASE_LABELS.size():
		var label := Label.new()
		label.text = "%d  %s" % [index + 1, PHASE_LABELS[index]]
		label.position = Vector2(float(index) * 360.0 + 24.0, 662.0)
		label.add_theme_font_size_override("font_size", 19)
		label.add_theme_color_override("font_color", Color(0.94, 0.94, 0.90))
		layer.add_child(label)


func _build_stage() -> Node3D:
	var stage := Node3D.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.035, 0.047, 0.047)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.60, 0.68, 0.74)
	environment.ambient_light_energy = 0.44
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_color = Color(1.0, 0.86, 0.68)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	stage.add_child(sun)
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(24.0, 16.0)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.106, 0.125, 0.122)
	floor_material.roughness = 1.0
	floor_mesh.material = floor_material
	var floor_instance := MeshInstance3D.new()
	floor_instance.mesh = floor_mesh
	stage.add_child(floor_instance)
	return stage
