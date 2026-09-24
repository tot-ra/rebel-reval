extends "res://tests/godot/test_case.gd"

const MODEL_CLIPS: Dictionary = {
  "mart": [
    "Idle",
    "Walking_A",
    "Running_B",
    "Interact",
    "1H_Melee_Attack_Chop"
  ],
  "aita": [
    "Idle",
    "Walking_A",
    "Running_B",
    "Interact",
    "1H_Melee_Attack_Chop"
  ],
  "ellen": [
    "Idle",
    "Walking_A",
    "Running_B",
    "Interact",
    "1H_Melee_Attack_Chop"
  ],
  "watchman": [
    "Idle",
    "Walking_A",
    "Running_B",
    "Interact",
    "1H_Melee_Attack_Chop"
  ],
  "henning": [
    "Idle",
    "Walking_A",
    "Running_B",
    "Interact",
    "1H_Melee_Attack_Chop"
  ],
  "jurgen": [
    "Idle",
    "Walking_A",
    "Running_B",
    "Interact",
    "1H_Melee_Attack_Chop"
  ],
  "kaja": [
    "Idle",
    "Walking_A",
    "Running_B",
    "Interact",
    "1H_Melee_Attack_Chop"
  ],
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

func test_humans_retain_shared_motion_and_attachment_names() -> void:
	for id: String in ["mart", "aita", "ellen", "watchman", "henning", "jurgen", "kaja"]:
		var model := (load("res://assets/storybook/%s/%s.glb" % [id, id]) as PackedScene).instantiate()
		var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var clips := player.get_animation_list()
		clips.erase("RESET")
		assert_eq(clips.size(), 76)
		for bone: String in ["root", "hips", "spine", "chest", "head", "handslot.l", "handslot.r"]:
			assert_true(skeleton.find_bone(bone) >= 0, "%s retains %s" % [id, bone])
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
				assert_eq(String(player.current_animation), "Running_B" if scene.IDS[i] in scene.HUMANS else ("Fly" if scene.IDS[i] in scene.BIRDS else "Run"))
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
	assert_eq(String(scene._players[0].current_animation), "Walking_A")
	scene.free()

func test_all_humans_use_existing_wardrobe_with_fitted_armor_and_hand_props() -> void:
	for id: String in ["mart", "aita", "ellen", "watchman", "henning", "jurgen", "kaja"]:
		var rig := (load("res://assets/storybook/%s/%s.tscn" % [id, id]) as PackedScene).instantiate() as SharedCharacterRig
		Engine.get_main_loop().root.add_child(rig)
		var skeleton := rig.skeleton()
		var player := rig.animation_player()
		var has_kirtle := id in ["aita", "ellen", "kaja"]
		assert_eq((rig.find_child("Clothing_Legs",true,false) as Node3D).visible, not has_kirtle)
		for mesh: MeshInstance3D in rig.find_children("*", "MeshInstance3D", true, false):
			assert_eq(mesh.visibility_range_end, 0.0, "single-tier candidates stay visible at distance")
		rig.play_animation(&"run")
		for kind: String in ["mail", "helmet", "cape"]:
			assert_true(rig.equip_wearable(load("res://assets/storybook/equipment/%s_%s.tres" % [id,kind])))
		assert_true(rig.skeleton() == skeleton and rig.animation_player() == player, "equipment preserves live rig")
		assert_true((rig.find_child("Clothing_Legs",true,false) as Node3D).visible, "mail restores the hose")
		assert_false((rig.find_child("Clothing_Torso",true,false) as Node3D).visible)
		assert_false((rig.find_child("Clothing_Outerwear",true,false) as Node3D).visible)
		assert_false((rig.find_child("Hair_Scalp",true,false) as Node3D).visible)
		for kind: String in ["sword", "hammer"]:
			var prop := rig.equip(&"right_hand",load("res://assets/storybook/equipment/%s.tscn" % kind))
			assert_true(prop != null)
			assert_eq((prop.get_parent() as BoneAttachment3D).bone_name,"handslot.r")
		var shield := rig.equip(&"left_hand",load("res://assets/storybook/equipment/shield.tscn"))
		assert_eq((shield.get_parent() as BoneAttachment3D).bone_name,"handslot.l")
		for clip: StringName in [&"walk", &"run", &"guard", &"sword_attack"]:
			assert_true(rig.play_animation(clip))
			player.advance(0.35)
			assert_true(skeleton.get_bone_global_pose(skeleton.find_bone("handslot.r")).is_finite())
		if has_kirtle:
			var leg_layer := (load("res://assets/storybook/equipment/%s_mail.tres" % id) as CharacterWearable).duplicate() as CharacterWearable
			leg_layer.stable_id = &"wearable.test.leg_coverage"
			leg_layer.slot = "legs"
			leg_layer.covered_meshes = [&"Clothing_Legs"]
			assert_true(rig.equip_wearable(leg_layer))
			assert_false((rig.find_child("Clothing_Legs",true,false) as Node3D).visible, "custom leg gear retains coverage union")
			rig.unequip_wearable(&"legs")
			assert_true((rig.find_child("Clothing_Legs",true,false) as Node3D).visible, "removing leg gear restores hose under mail")
		var wrong := "mart" if id != "mart" else "aita"
		assert_false(rig.equip_wearable(load("res://assets/storybook/equipment/%s_mail.tres" % wrong)))
		assert_true(rig.equipped_wearable(&"torso") != null, "rejected fit preserves armor")
		for slot: StringName in [&"torso", &"head", &"back"]:
			rig.unequip_wearable(slot)
		assert_eq((rig.find_child("Clothing_Legs",true,false) as Node3D).visible, not has_kirtle, "restored kirtle covers hose")
		assert_true((rig.find_child("Clothing_Torso",true,false) as Node3D).visible)
		assert_true((rig.find_child("Clothing_Outerwear",true,false) as Node3D).visible)
		assert_true((rig.find_child("Hair_Scalp",true,false) as Node3D).visible)
		rig.unequip(&"right_hand")
		rig.unequip(&"left_hand")
		assert_true(rig.equipped(&"right_hand") == null and rig.equipped(&"left_hand") == null)
		rig.free()

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

func test_mart_arm_chain_is_shorter_and_does_not_stretch_in_motion() -> void:
	var model := (load("res://assets/storybook/mart/mart.glb") as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(model)
	var skeleton := model.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	var player := model.find_child("AnimationPlayer",true,false) as AnimationPlayer
	var upper := skeleton.find_bone("upperarm.l")
	var lower := skeleton.find_bone("lowerarm.l")
	var wrist := skeleton.find_bone("wrist.l")
	for clip: StringName in [&"Idle", &"Walking_A", &"Running_B", &"Interact", &"1H_Melee_Attack_Chop"]:
		player.play(clip)
		for t: float in [0.0,0.2,0.4,0.6]:
			player.seek(t,true)
			var a := skeleton.get_bone_global_pose(upper).origin
			var b := skeleton.get_bone_global_pose(lower).origin
			var c := skeleton.get_bone_global_pose(wrist).origin
			assert_true(a.distance_to(b)+b.distance_to(c) < 0.48, "Mart arm chain fits adolescent proportions")
	model.free()

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
	scene._set_category(3)
	scene._subject.select(0)
	scene._select_subject(0)
	assert_true(scene._models[0].visible, "selecting a hidden person reveals the correct category")
	scene._set_armor(1)
	assert_true(scene._models[0].equipped_wearable(&"torso") != null, "UI equips through live API")
	scene._set_weapon(2)
	scene._set_shield(true)
	assert_true(scene._models[0].equipped(&"right_hand") != null)
	assert_true(scene._models[0].equipped(&"left_hand") != null)
	scene.free()

func test_review_cases_restore_equipment_and_play_real_clips() -> void:
	var scene := (load("res://scenes/debug/storybook_showcase.tscn") as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(scene)
	for case_index: int in [3, 2, 1, 0, 4, 5]:
		scene._apply_case(case_index)
		for i: int in scene.IDS.size():
			if scene.IDS[i] in scene.HUMANS and case_index < 4:
				var rig: SharedCharacterRig = scene._models[i]
				assert_eq(rig.equipped_wearable(&"torso") != null, case_index == 3)
				assert_eq(rig.equipped(&"left_hand") != null, case_index == 3)
				assert_eq(rig.equipped(&"right_hand") != null, case_index in [1, 3])
				assert_eq(rig.equipped_wearable(&"back") != null, case_index in [2, 3])
				assert_true(scene._players[i].is_playing())
			elif scene.IDS[i] not in scene.HUMANS and scene.IDS[i] not in scene.BIRDS and case_index >= 4:
				assert_eq(String(scene._players[i].current_animation), "Graze" if case_index == 4 else "Alert")
	scene.free()

func test_mammals_have_compact_stance_and_bending_lower_legs() -> void:
	for id: String in ["pig", "dog", "sheep", "goat", "boar", "fox", "hare", "forge_cat"]:
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
