extends SceneTree

## Review plate for village window variants (docs/SYSTEMS/COTTAGE_WINDOWS.md): a row
## of log/plank cottages and one stone house, each with its own seeded look.
##   tools/godot_render.sh --script tools/capture_cottage_windows.gd
## Output: build/windows/cottage_windows.png

const OUTPUT := "res://build/windows/cottage_windows.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/windows"))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(2000, 800)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.6, 0.7, 0.8)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.72, 0.75)
	var we := WorldEnvironment.new()
	we.environment = env
	viewport.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 25, 0)
	viewport.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(120, 40)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.32, 0.4, 0.2)
	ground.material_override = gm
	viewport.add_child(ground)
	# Plate A: every rural style on one log wall, plus the stone surround.
	var shell := CityBuildingBuilder.Shell.new()
	var styles: Array[StringName] = [
		&"plain",
		&"platband",
		&"gable_cap",
		&"shutters_open",
		&"shutters_closed",
		&"slit",
		&"surround"
	]
	var wall_len := 2.6 * styles.size()
	shell.quad(
		"wall:log",
		Vector3(0, 0, 0),
		Vector3(wall_len, 0, 0),
		Vector3(wall_len, 3, 0),
		Vector3(0, 3, 0),
		Color.WHITE
	)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in styles.size():
		var look := {
			"rural": true,
			"trim": CityWindows.TRIM_PAINTS[i % CityWindows.TRIM_PAINTS.size()],
			"shutter": CityWindows.SHUTTER_PAINTS[i % CityWindows.SHUTTER_PAINTS.size()],
			"style": styles[i],
			"panes": 1 + i % 3,
		}
		CityWindows.add_window(
			shell,
			Vector2(1.3 + 2.6 * i, 0),
			Vector2(1, 0),
			Vector2(0, 1),
			1.0,
			0.58,
			styles[i],
			look,
			0.5
		)
	var inst := MeshInstance3D.new()
	inst.mesh = shell.to_mesh(CityBuildingBuilder.material_for_key)
	viewport.add_child(inst)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.current = true
	camera.look_at_from_position(Vector3(9.1, 1.6, 7.5), Vector3(9.1, 1.5, 0), Vector3.UP)
	camera.fov = 70
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT))
	print("captured ", OUTPUT)
	quit(0)
