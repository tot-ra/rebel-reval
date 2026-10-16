extends SceneTree

## Town watchman with the pilot spear variant (docs/SYSTEMS/EQUIPMENT_VARIANTS.md,
## R-2003): idle and walk, three-quarter and side, armed through CitizenGear exactly
## as in the city, plus a close-up of the grip hand and the spearhead.
## Requires a rendering run:
##   tools/godot_render.sh --script tools/capture_watch_spear.gd [-- --output-dir=PATH]

const OUTPUT_DIR := "res://docs/reports/images/equipment"
const SPACING := 1.3
## [label, yaw degrees, walk]
const POSES := [
	["idle 3/4", 30.0, false],
	["idle side", 90.0, false],
	["walk 3/4", 30.0, true],
	["walk side", 90.0, true],
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600, 900)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.57, 0.6)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.74)
	viewport.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -25, 0)
	viewport.add_child(sun)
	var rigs: Array[SharedCharacterRig] = []
	for i in POSES.size():
		var pose: Array = POSES[i]
		var scene := load("res://assets/characters/variants/citizen_m_adult_average.tscn") as PackedScene
		var rig := scene.instantiate() as SharedCharacterRig
		viewport.add_child(rig)
		rig.position = Vector3((i - (POSES.size() - 1) * 0.5) * SPACING, 0.0, 0.0)
		rig.rotation_degrees = Vector3(0, pose[1], 0)
		rigs.append(rig)
		var record := {
			"body": "citizen_m_adult_average",
			"cloth": [0.3, 0.3, 0.28],
			"under": [0.22, 0.2, 0.17],
			"wear": ["gambeson", "kettle_hat"],
			"wear_dye": {},
			"duty": {"kit": "watch", "shift": "day"},
		}
		CityCitizens.dye(rig, record)
		CitizenGear.arm(rig, record)
		if pose[2]:
			rig.play_animation(&"walk")
		var label := Label3D.new()
		label.text = pose[0]
		label.font_size = 40
		label.pixel_size = 0.004
		label.position = Vector3(0, -0.12, 0.4)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		rig.add_child(label)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.95
	camera.position = Vector3(0.0, 1.3, 7.0)
	viewport.add_child(camera)
	camera.current = true
	for _frame in 24:
		await process_frame
	var out := OUTPUT_DIR
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--output-dir="):
			out = a.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	_save(viewport, out + "/watch_spear_capture.png")
	# Close-up of the idle three-quarter watchman: kettle hat and spearhead.
	camera.size = 1.0
	camera.position = Vector3(rigs[0].position.x, 1.95, 7.0)
	for _frame in 3:
		await process_frame
	_save(viewport, out + "/watch_spear_closeup.png")
	quit(0)


func _save(viewport: SubViewport, path: String) -> void:
	viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("SAVED ", path)
