extends SceneTree

## Review plate for soul-light alignment: one adult with its aura, the perspective
## camera orbiting from the left, the front and the right at close range. The lights
## must stay on the same bones in every shot (no parallax slide). GPU run:
##   tools/godot_render.sh --resolution 720x960 --script tools/capture_spirit_aura_parallax.gd


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
	camera.fov = 60.0
	world.add_child(camera)
	var scene := load("res://assets/characters/variants/citizen_m_adult_average.tscn") as PackedScene
	var rig := scene.instantiate() as SharedCharacterRig
	world.add_child(rig)
	var profile := SpiritAuraProfile.new()
	for light: StringName in profile.levels.keys():
		profile.levels[light] = 3
	var view := SpiritAuraView.new()
	rig.add_child(view)
	view.bind(rig, profile)
	view.set_tier(SpiritAuraView.Tier.FULL)
	view.set_fade(1.0)
	# Optional `-- <tag>` names the output folder (e.g. before / after a shader change).
	var args := OS.get_cmdline_user_args()
	var out := "res://build/spirit_aura_parallax/%s" % (args[0] if not args.is_empty() else "current")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	for shot: Array in [["left", -55.0], ["front", 0.0], ["right", 55.0]]:
		var yaw := deg_to_rad(float(shot[1]))
		camera.position = Vector3(sin(yaw) * 1.8, 1.5, cos(yaw) * 1.8)
		camera.look_at(Vector3(0.0, 1.1, 0.0))
		for i in 5:
			await process_frame
		root.get_texture().get_image().save_png("%s/%s.png" % [out, shot[0]])
	quit()
