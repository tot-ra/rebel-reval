extends SceneTree
## Rendering-capable visual regression of the live hero and its wardrobe.
## Godot --path . --script tools/capture_kalev_realism.gd

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var output := "res://docs/reports/images/characters/realism_after"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="):
			output = arg.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1000, 1100)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.035, 0.045, 0.055)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.78, 0.88)
	environment.ambient_light_energy = 0.45
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	viewport.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-32, -35, 0)
	key.light_color = Color(1.0, 0.90, 0.79)
	key.light_energy = 1.0
	key.shadow_enabled = true
	viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 140, 0)
	fill.light_color = Color(0.65, 0.76, 1.0)
	fill.light_energy = 0.65
	viewport.add_child(fill)
	var rig := (load("res://assets/characters/kalev/kalev.tscn") as PackedScene).instantiate() as SharedCharacterRig
	viewport.add_child(rig)
	rig.get_node("HealthRing").hide()
	rig.unequip(&"right_hand")
	rig.unequip_wearable(&"back")
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	viewport.add_child(camera)
	camera.current = true
	var shots: Array[Dictionary] = [
		{"name":"portrait", "yaw":0.0, "portrait":true},
		{"name":"portrait_three_quarter", "yaw":30.0, "portrait":true},
		{"name":"portrait_profile", "yaw":90.0, "portrait":true},
		{"name":"work_front", "yaw":0.0},
		{"name":"work_back", "yaw":180.0},
		{"name":"walk", "yaw":25.0, "clip":&"walk", "time":0.45},
		{"name":"run", "yaw":25.0, "clip":&"run", "time":0.35},
		{"name":"forge", "yaw":25.0, "clip":&"hammer_attack", "time":0.34, "weapon":"hammer"},
		{"name":"armour", "yaw":20.0, "armour":true, "weapon":"sword"},
		{"name":"armour_guard", "yaw":20.0, "armour":true, "weapon":"sword", "clip":&"guard", "time":0.3},
		{"name":"restored", "yaw":0.0},
	]
	for shot: Dictionary in shots:
		for slot: StringName in [&"torso", &"head", &"back"]:
			rig.unequip_wearable(slot)
		for slot: StringName in [&"right_hand", &"left_hand"]:
			rig.unequip(slot)
		if shot.get("armour", false):
			for kind: String in ["mail", "helmet", "cape"]:
				if not rig.equip_wearable(load("res://assets/storybook/equipment/kalev_%s.tres" % kind)):
					push_error("Kalev wardrobe capture failed")
					quit(1)
					return
			rig.equip(&"left_hand", load("res://assets/storybook/equipment/shield.tscn"))
		if shot.has("weapon"):
			rig.equip(&"right_hand", load("res://assets/storybook/equipment/%s.tscn" % shot.weapon))
		rig.rotation_degrees.y = shot.yaw
		rig.play_animation(shot.get("clip", &"idle"), 0.0)
		rig.animation_player().seek(shot.get("time", 0.0), true)
		rig.animation_player().pause()
		rig.skeleton().force_update_all_bone_transforms()
		var focus := Vector3(0, 1.0, 0)
		camera.size = 2.3
		if shot.get("portrait", false):
			var skeleton := rig.skeleton()
			focus = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("head")).origin
			focus.y += 0.15
			camera.size = 0.56
		camera.position = focus + Vector3(0, 0, 8)
		camera.look_at(focus)
		for frame in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var result := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(output.path_join(shot.name + ".png")))
		if result != OK:
			quit(1)
			return
		print("Kalev realism capture: ", shot.name)
	viewport.queue_free()
	quit(0)
