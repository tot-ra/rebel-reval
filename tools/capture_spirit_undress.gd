extends SceneTree

## Review plate for spirit-sight nudity: adults (and a child, who stays dressed) before, in
## sight (front and back) and after sight closes. GPU run:
##   tools/godot_render.sh --resolution 1280x720 --script tools/capture_spirit_undress.gd


func _init() -> void:
	await process_frame
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.25, 0.27, 0.32)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.85)
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40.0, 30.0, 0.0)
	world.add_child(sun)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0.0, 1.0, 6.5)
	var bodies := ["citizen_m_adult_average", "citizen_f_adult_heavy_b", "citizen_m_elder_thin", "citizen_m_child_average"]
	var rigs: Array[SharedCharacterRig] = []
	for i in bodies.size():
		var rig := (load("res://assets/characters/variants/%s.tscn" % bodies[i]) as PackedScene).instantiate() as SharedCharacterRig
		world.add_child(rig)
		rig.position = Vector3(-2.1 + 1.4 * i, 0.0, 0.0)
		rigs.append(rig)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/spirit_undress"))
	for i in 5:
		await process_frame
	root.get_texture().get_image().save_png("res://build/spirit_undress/dressed.png")
	for rig in rigs:
		SpiritUndress.undress(rig)
	for i in 5:
		await process_frame
	root.get_texture().get_image().save_png("res://build/spirit_undress/sight.png")
	for rig in rigs:
		rig.rotation_degrees.y = 180.0
	for i in 5:
		await process_frame
	root.get_texture().get_image().save_png("res://build/spirit_undress/sight_back.png")
	for rig in rigs:
		SpiritUndress.restore(rig)
		rig.rotation_degrees.y = 0.0
	for i in 5:
		await process_frame
	root.get_texture().get_image().save_png("res://build/spirit_undress/restored.png")
	quit()
