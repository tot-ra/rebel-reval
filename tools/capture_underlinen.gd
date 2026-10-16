extends SceneTree

## Linen that shows (task R-2024, docs/SYSTEMS/CITIZEN_WARDROBE.md#linen-that-shows):
## close portraits of the shirt collar and cuffs (men) and the chemise neck and cuffs
## (women) on three ranks each - a poor labourer or servant in sweat-stained or yellowed
## tow, a middling master's household and a rich patrician's in bleached fine linen.
## Each resident gets a head-and-shoulders shot and a wrist shot. Requires a rendering run:
##   tools/godot_render.sh --script tools/capture_underlinen.gd [-- --output-dir=PATH]

const OUTPUT_DIR := "res://docs/reports/images/characters"
const ROW_SPACING := 30.0
const SHOT := Vector2i(480, 560)
## [label, record]; the records are what build_citizen_runtime.py writes.
const RESIDENTS := [
	[
		"poor man",
		{
			"id": "cit.capture.linen_poor_m", "body": "citizen_m_adult_thin", "status": "labourer",
			"trade": "porter", "cloth": [0.46, 0.44, 0.4], "under": [0.36, 0.28, 0.2], "wear": [],
		},
	],
	[
		"middling man",
		{
			"id": "cit.capture.linen_mid_m", "body": "citizen_m_adult_average", "status": "master_craftsman",
			"trade": "cooper", "cloth": [0.32, 0.36, 0.28], "under": [0.22, 0.2, 0.17], "wear": [],
		},
	],
	[
		"rich man",
		{
			"id": "cit.capture.linen_rich_m", "body": "citizen_m_adult_average_b", "status": "patrician",
			"trade": "merchant", "cloth": [0.42, 0.13, 0.1], "under": [0.2, 0.17, 0.15], "wear": [],
		},
	],
	[
		"poor woman",
		{
			"id": "cit.capture.linen_poor_f", "body": "citizen_f_adult_thin", "status": "servant",
			"trade": "", "cloth": [0.44, 0.4, 0.33], "under": [0.36, 0.28, 0.2], "wear": [],
		},
	],
	[
		"middling woman",
		{
			"id": "cit.capture.linen_mid_f", "body": "citizen_f_adult_average_b", "status": "burgher",
			"trade": "", "cloth": [0.22, 0.28, 0.42], "under": [0.22, 0.2, 0.17], "wear": [],
		},
	],
	[
		"rich woman",
		{
			"id": "cit.capture.linen_rich_f", "body": "citizen_f_adult_average_c", "status": "patrician",
			"trade": "", "cloth": [0.45, 0.12, 0.12], "under": [0.2, 0.17, 0.15], "wear": [],
		},
	],
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = SHOT
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.5, 0.52, 0.55)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.62, 0.63, 0.68)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	viewport.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -25, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	viewport.add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 30.0
	viewport.add_child(camera)
	camera.current = true

	var rigs: Array[SharedCharacterRig] = []
	for i in RESIDENTS.size():
		var record: Dictionary = RESIDENTS[i][1]
		var scene := load("res://assets/characters/variants/%s.tscn" % record["body"]) as PackedScene
		var rig := scene.instantiate() as SharedCharacterRig
		viewport.add_child(rig)
		rig.position = Vector3(i * ROW_SPACING, 0.0, 0.0)
		rigs.append(rig)
	for _frame in 4:
		await process_frame
	for i in rigs.size():
		CitizenWardrobe.dress(rigs[i], RESIDENTS[i][1])
	for _frame in 30:
		await process_frame

	var out := OUTPUT_DIR
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--output-dir="):
			out = a.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var neck: Array[Image] = []
	var wrist: Array[Image] = []
	for i in rigs.size():
		var skeleton := rigs[i].skeleton()
		var head := _bone(skeleton, "neck")
		var hand := _bone(skeleton, "wrist.l")
		print("%s: %s" % [RESIDENTS[i][0], _linen_grades(rigs[i])])
		camera.position = head + Vector3(0.12, 0.02, 0.62)
		camera.look_at(head + Vector3(0.0, -0.06, 0.0))
		neck.append(await _grab(viewport))
		camera.position = hand + Vector3(0.05, 0.08, 0.42)
		camera.look_at(hand)
		wrist.append(await _grab(viewport))
	var plate := Image.create(SHOT.x * neck.size(), SHOT.y * 2, false, neck[0].get_format())
	for i in neck.size():
		plate.blit_rect(neck[i], Rect2i(Vector2i.ZERO, SHOT), Vector2i(i * SHOT.x, 0))
		plate.blit_rect(wrist[i], Rect2i(Vector2i.ZERO, SHOT), Vector2i(i * SHOT.x, SHOT.y))
	var path := out + "/citizen_underlinen.jpg"
	plate.save_jpg(ProjectSettings.globalize_path(path), 0.9)
	print("wrote ", path)
	quit(0)


func _grab(viewport: SubViewport) -> Image:
	for _frame in 4:
		await process_frame
	return viewport.get_texture().get_image()


func _bone(skeleton: Skeleton3D, bone: String) -> Vector3:
	var index := skeleton.find_bone(bone)
	return skeleton.global_transform * skeleton.get_bone_global_pose(index).origin


## Grades of the resident's linen surfaces (read off the albedo map) for the log.
func _linen_grades(rig: SharedCharacterRig) -> Array:
	var grades := {}
	for child: Node in rig.skeleton().get_children():
		var mesh := child as MeshInstance3D
		if mesh == null or mesh.mesh == null:
			continue
		for surface in mesh.mesh.get_surface_count():
			var shader := mesh.get_active_material(surface) as ShaderMaterial
			if shader == null:
				continue
			var albedo := shader.get_shader_parameter(&"albedo_tex") as Texture2D
			var grade := albedo.resource_path.get_file().get_slice("_albedo", 0)
			if grade.begins_with("linen"):
				grades[grade] = true
	return grades.keys()
