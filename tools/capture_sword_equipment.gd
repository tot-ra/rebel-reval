extends SceneTree

## Reproducible sword acceptance plates. Run with a rendering-capable Godot
## process (no --headless):
## godot --path . --script tools/capture_sword_equipment.gd

const KALEV_SCENE := preload("res://assets/characters/kalev/kalev.tscn")
const SWORD_SCENE := preload("res://assets/characters/shared/sword.tscn")
const OUTPUT_DIR := "res://docs/reports/images/combat"
const CLOSEUP_SIZE := Vector2i(1440, 900)
const GAMEPLAY_SIZE := Vector2i(1440, 810)
const ATTACK_SAMPLE_SEC := 0.38


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await _capture_closeup()
	await _capture_gameplay()
	quit(0)


func _capture_closeup() -> void:
	var viewport := _make_viewport(CLOSEUP_SIZE)
	var camera := _make_camera(viewport, 3.0, Vector3(6.0, 4.0, 8.0), Vector3(0.0, 1.0, 0.0))
	var screen_right := camera.global_transform.basis.x.normalized()
	var idle := _make_sword_rig(viewport, &"idle", 0.0)
	idle.position = screen_right * -0.86
	var attack := _make_sword_rig(viewport, &"sword_attack", ATTACK_SAMPLE_SEC)
	attack.position = screen_right * 0.86
	_add_labels(viewport, "PLAIN CRUCIFORM SWORD - GRIP AND CLEARANCE", [
		{"text": "IDLE / HANDSLOT.R", "x": 170.0},
		{"text": "DIAGONAL SLASH", "x": 880.0},
	])
	await _save_after_frames(viewport, "%s/sword_closeup_idle_attack.png" % OUTPUT_DIR)


func _capture_gameplay() -> void:
	var viewport := _make_viewport(GAMEPLAY_SIZE)
	_make_camera(viewport, 7.4, Vector3(9.0, 8.0, 11.0), Vector3(0.0, 0.8, 0.0))
	var attack := _make_sword_rig(viewport, &"sword_attack", ATTACK_SAMPLE_SEC)
	attack.position = Vector3(-0.45, 0.0, 0.0)
	var target := _make_target()
	target.position = Vector3(1.15, 0.0, 0.15)
	viewport.add_child(target)
	_add_labels(viewport, "GAMEPLAY SCALE - SWORD LIGHT ATTACK", [
		{"text": "66 PX REACH  |  11 SLASH  |  7 STAMINA", "x": 390.0},
	])
	await _save_after_frames(viewport, "%s/sword_gameplay_attack.png" % OUTPUT_DIR)


func _make_viewport(size: Vector2i) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(_build_stage())
	return viewport


func _make_camera(
	viewport: SubViewport, size: float, position: Vector3, focus: Vector3
) -> Camera3D:
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = size
	camera.position = position
	viewport.add_child(camera)
	camera.current = true
	camera.look_at(focus, Vector3.UP)
	return camera


func _make_sword_rig(
	viewport: SubViewport, animation: StringName, sample_sec: float
) -> SharedCharacterRig:
	var rig := KALEV_SCENE.instantiate() as SharedCharacterRig
	viewport.add_child(rig)
	var sword := rig.equip(&"right_hand", SWORD_SCENE)
	if sword == null:
		push_error("Sword capture could not mount sword on handslot.r")
		return rig
	rig.play_animation(animation, 0.0)
	if sample_sec > 0.0:
		rig.animation_player().seek(sample_sec, true)
	return rig


func _make_target() -> Node3D:
	var target := Node3D.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.38, 0.20, 0.13)
	material.roughness = 0.96
	var post_mesh := CylinderMesh.new()
	post_mesh.material = material
	post_mesh.top_radius = 0.22
	post_mesh.bottom_radius = 0.27
	post_mesh.height = 1.35
	post_mesh.radial_segments = 12
	var post := MeshInstance3D.new()
	post.position.y = 0.675
	post.mesh = post_mesh
	target.add_child(post)
	var cap_mesh := CylinderMesh.new()
	cap_mesh.material = material
	cap_mesh.top_radius = 0.42
	cap_mesh.bottom_radius = 0.42
	cap_mesh.height = 0.14
	cap_mesh.radial_segments = 12
	var cap := MeshInstance3D.new()
	cap.position.y = 1.35
	cap.mesh = cap_mesh
	target.add_child(cap)
	return target


func _save_after_frames(viewport: SubViewport, output: String) -> void:
	for _frame in 6:
		await process_frame
	var error := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(output))
	if error != OK:
		push_error("Could not save sword capture %s: %s" % [output, error_string(error)])
		quit(1)
		return
	print("Sword equipment capture: %s" % output)
	viewport.queue_free()
	await process_frame


func _add_labels(viewport: SubViewport, title: String, captions: Array[Dictionary]) -> void:
	var layer := CanvasLayer.new()
	viewport.add_child(layer)
	var header := Label.new()
	header.text = title
	header.position = Vector2(32.0, 24.0)
	header.add_theme_font_size_override("font_size", 28)
	header.add_theme_color_override("font_color", Color(1.0, 0.83, 0.53))
	layer.add_child(header)
	for caption: Dictionary in captions:
		var label := Label.new()
		label.text = String(caption["text"])
		label.position = Vector2(float(caption["x"]), float(viewport.size.y) - 62.0)
		label.add_theme_font_size_override("font_size", 20)
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
