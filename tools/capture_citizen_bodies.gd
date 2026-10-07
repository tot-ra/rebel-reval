extends SceneTree

## Lineup of the blank citizen bodies (docs/SYSTEMS/CITIZENS.md): every body of
## tools/assets/realistic_humans/citizen_bodies.py side by side at its real stature,
## front and three-quarter, for judging build, belly, bust and age by eye.
## Requires a rendering run:
##   tools/godot_render.sh --script tools/capture_citizen_bodies.gd [-- --output-dir=PATH]

const OUTPUT_DIR := "res://docs/reports/images/characters"
const BODIES: Array[String] = [
	"citizen_m_child_average", "citizen_f_child_average",
	"citizen_m_adult_thin", "citizen_m_adult_average", "citizen_m_adult_sturdy", "citizen_m_adult_heavy",
	"citizen_f_adult_thin", "citizen_f_adult_average", "citizen_f_adult_sturdy", "citizen_f_adult_heavy",
	"citizen_m_elder_thin", "citizen_m_elder_heavy", "citizen_f_elder_thin", "citizen_f_elder_heavy",
]
const SPACING := 1.25


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(2400, 760)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.57, 0.6)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.78)
	viewport.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -25, 0)
	viewport.add_child(sun)
	var rigs: Array[SharedCharacterRig] = []
	for i in BODIES.size():
		var rig := (load("res://assets/characters/variants/%s.tscn" % BODIES[i]) as PackedScene).instantiate() as SharedCharacterRig
		viewport.add_child(rig)
		rig.position = Vector3((i - (BODIES.size() - 1) * 0.5) * SPACING, 0.0, 0.0)
		rigs.append(rig)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.5
	camera.position = Vector3(0.0, 1.0, 6.0)
	viewport.add_child(camera)
	camera.current = true
	for _frame in 6:
		await process_frame
	var out := OUTPUT_DIR
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--output-dir="):
			out = a.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(out + "/citizen_bodies_front.png"))
	for rig in rigs:
		rig.rotation_degrees = Vector3(0, 60, 0)
	for _frame in 3:
		await process_frame
	viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(out + "/citizen_bodies_angle.png"))
	quit(0)
