extends "res://tests/godot/test_case.gd"

const MODEL_CLIPS: Dictionary = {
  "forge_cat": [
    "Sleep", "Groom", "Stretch",
    "Idle",
    "Walk",
    "LookAround",
    "Run",
    "Graze",
    "Alert"
  ],
  "sheep": [
    "Idle",
    "Walk",
    "LookAround",
    "Run",
    "Graze",
    "Alert"
  ],
  "dog": [
    "Idle",
    "Walk",
    "LookAround",
    "Run",
    "Graze",
    "Alert"
  ],
  "pig": [
    "Idle",
    "Walk",
    "LookAround",
    "Run",
    "Graze",
    "Alert"
  ],
  "goat": [
    "Idle",
    "Walk",
    "LookAround",
    "Run",
    "Graze",
    "Alert"
  ],
  "boar": [
    "Idle",
    "Walk",
    "LookAround",
    "Run",
    "Graze",
    "Alert"
  ],
  "fox": [
    "Idle",
    "Walk",
    "LookAround",
    "Run",
    "Graze",
    "Alert"
  ],
  "hare": [
    "Idle",
    "Walk",
    "LookAround",
    "Run",
    "Graze",
    "Alert"
  ],
  "rat": [
    "Idle",
    "Walk",
    "LookAround",
    "Run",
    "Graze",
    "Alert"
  ],
  "robin": [
    "Idle",
    "Hop",
    "Fly",
    "Peck",
    "TakeOff",
    "Glide",
    "Land"
  ],
  "hooded_crow": [
    "Idle",
    "Hop",
    "Fly",
    "Peck",
    "TakeOff",
    "Glide",
    "Land"
  ],
  "gull": [
    "Idle",
    "Hop",
    "Fly",
    "Peck",
    "TakeOff",
    "Glide",
    "Land"
  ],
  "hen": [
    "Idle",
    "Hop",
    "Fly",
    "Peck",
    "TakeOff",
    "Glide",
    "Land"
  ],
  "duck": [
    "Idle",
    "Hop",
    "Fly",
    "Peck",
    "TakeOff",
    "Glide",
    "Land"
  ]
}

func test_imported_models_have_skinned_meshes_and_playable_clips() -> void:
	for id: String in MODEL_CLIPS:
		var packed := load("res://assets/storybook/%s/%s.glb" % [id, id]) as PackedScene
		assert_true(packed != null, "%s imports" % id)
		var model := packed.instantiate() as Node3D
		Engine.get_main_loop().root.add_child(model)
		var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		assert_true(skeleton.get_bone_count() >= 7)
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			assert_true(mesh.skin != null, "%s mesh has skin" % id)
			assert_true(mesh.mesh.get_surface_count() > 0)
			assert_true(mesh.get_aabb().size.is_finite())
		for clip: String in MODEL_CLIPS[id]:
			assert_true(player.has_animation(clip), "%s/%s exists" % [id, clip])
			player.play(clip)
			player.advance(0.0)
			var poses: Array[Transform3D] = []
			for bone: int in skeleton.get_bone_count():
				poses.append(skeleton.get_bone_pose(bone))
			player.advance(0.37)
			var moved := false
			for bone: int in skeleton.get_bone_count():
				var pose := skeleton.get_bone_pose(bone)
				assert_true(pose.is_finite(), "%s/%s finite pose" % [id, clip])
				moved = moved or not pose.is_equal_approx(poses[bone])
			assert_true(moved, "%s/%s drives imported skeleton" % [id, clip])
		model.free()

func test_bird_pigmentation_and_pbr_survive_godot_import() -> void:
	for id: String in ["robin", "hooded_crow", "gull", "hen", "duck"]:
		var model := (load("res://assets/storybook/%s/%s.glb" % [id, id]) as PackedScene).instantiate()
		var found_plumage := false
		for instance: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			for surface: int in instance.mesh.get_surface_count():
				var material := instance.mesh.surface_get_material(surface) as ShaderMaterial
				assert_true(material != null, "%s: renderer-correct import material" % id)
				if material == null:
					continue
				assert_eq(material.shader.resource_path, "res://assets/storybook/bird_plumage.gdshader")
				var colors: PackedColorArray = instance.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
				assert_true(not colors.is_empty(), "%s: pigmentation survives import" % id)
				if material.resource_name == "Bird plumage":
					found_plumage = true
					for parameter: StringName in [&"albedo_map", &"normal_map", &"roughness_map"]:
						assert_true(material.get_shader_parameter(parameter) is Texture2D, "%s: %s is embedded" % [id, parameter])
					assert_true(float(material.get_shader_parameter("normal_strength")) > 0.0)
		assert_true(found_plumage)
		model.free()

func test_showcase_group_controls_switch_all_models_and_pause() -> void:
	var scene := (load("res://scenes/debug/storybook_showcase.tscn") as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(scene)
	for group: int in range(4):
		scene._play_group(group)
		for i: int in scene._players.size():
			var player: AnimationPlayer = scene._players[i]
			assert_true(player.is_playing())
			if group == 3:
				assert_eq(String(player.current_animation), "Fly" if scene.IDS[i] in scene.BIRDS else "Run")
	scene._toggle_pause()
	for player: AnimationPlayer in scene._players:
		assert_eq(player.speed_scale, 0.0)
	scene._toggle_pause()
	for player: AnimationPlayer in scene._players:
		assert_eq(player.speed_scale, 1.0)
	var event := InputEventKey.new()
	event.keycode = KEY_2
	event.pressed = true
	scene._unhandled_input(event)
	assert_eq(String(scene._players[0].current_animation), "Walk")
	scene.free()

func test_birds_spread_articulated_wings_and_complete_flight_sequence() -> void:
	var scene := (load("res://scenes/debug/storybook_showcase.tscn") as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(scene)
	for i: int in scene.IDS.size():
		if scene.IDS[i] not in scene.BIRDS:
			continue
		var skeleton := scene._models[i].find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
		var player: AnimationPlayer = scene._players[i]
		player.play("Idle"); player.advance(0)
		var left := skeleton.find_bone("WingTip.L")
		var right := skeleton.find_bone("WingTip.R")
		var folded := absf((skeleton.get_bone_global_pose(left) * Vector3(0,0.2,0)).x - (skeleton.get_bone_global_pose(right) * Vector3(0,0.2,0)).x)
		player.play("Fly"); player.advance(0.15)
		var spread := absf((skeleton.get_bone_global_pose(left) * Vector3(0,0.2,0)).x - (skeleton.get_bone_global_pose(right) * Vector3(0,0.2,0)).x)
		assert_true(spread > folded * 1.4, "%s unfolds wings for flight" % scene.IDS[i])
		assert_eq(player.get_animation("TakeOff").loop_mode, Animation.LOOP_NONE)
		assert_eq(player.get_animation("Land").loop_mode, Animation.LOOP_NONE)
	scene._start_flight()
	for expected: String in ["TakeOff", "Fly", "Glide", "Land", "Idle"]:
		for i: int in scene.IDS.size():
			if scene.IDS[i] in scene.BIRDS:
				assert_eq(String(scene._players[i].current_animation), expected)
		if expected != "Idle":
			scene._advance_flight(2.01)
	assert_true(scene._flight_time < 0)
	scene.free()

func test_flight_restart_and_manual_controls_restore_positions() -> void:
	var scene := (load("res://scenes/debug/storybook_showcase.tscn") as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(scene)
	var original: Vector3 = scene._models[scene.IDS.find("robin")].position
	scene._start_flight()
	scene._advance_flight(3.0)
	assert_false(scene._models[scene.IDS.find("robin")].position.is_equal_approx(original))
	scene._start_flight()
	assert_true(scene._models[scene.IDS.find("robin")].position.is_equal_approx(original))
	scene._advance_flight(3.0)
	scene._play_group(0)
	assert_true(scene._models[scene.IDS.find("robin")].position.is_equal_approx(original))
	assert_true(scene._flight_time < 0)
	scene._set_category(1)
	scene._subject.select(scene.IDS.find("robin"))
	scene._select_subject(0)
	assert_true(scene._models[scene.IDS.find("robin")].visible, "selecting a hidden subject reveals the correct category")
	scene.free()

func test_review_cases_play_real_animal_clips() -> void:
	var scene := (load("res://scenes/debug/storybook_showcase.tscn") as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(scene)
	for case_index: int in [0, 1]:
		scene._apply_case(case_index)
		for i: int in scene.IDS.size():
			if scene.IDS[i] not in scene.BIRDS:
				assert_eq(String(scene._players[i].current_animation), "Graze" if case_index == 0 else "Alert")
	scene.free()

func test_mammals_have_compact_stance_and_bending_lower_legs() -> void:
	for id: String in ["pig", "dog", "sheep", "goat", "boar", "fox", "hare", "forge_cat", "cow", "cow_holstein"]:
		var model := (load("res://assets/storybook/%s/%s.glb" % [id, id]) as PackedScene).instantiate()
		Engine.get_main_loop().root.add_child(model)
		var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var body := skeleton.get_bone_global_rest(skeleton.find_bone("Body")).origin
		if id in ["pig", "dog", "sheep"]:
			assert_true(body.y < 0.50, "%s has a lowered body and shorter legs" % id)
		for side: String in ["LF", "RF", "LB", "RB"]:
			var shin := skeleton.find_bone("Shin." + side)
			assert_true(shin >= 0)
			player.play("Run")
			player.seek(0, true)
			var before := skeleton.get_bone_pose(shin)
			player.seek(0.32 if side in ["LF", "RB"] else 0.65, true)
			assert_false(skeleton.get_bone_pose(shin).is_equal_approx(before), "%s/%s lower leg bends" % [id, side])
		model.free()
