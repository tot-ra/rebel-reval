extends "res://tests/godot/test_case.gd"

func _rig() -> SharedCharacterRig:
	var rig := (load("res://assets/characters/kalev/kalev.tscn") as PackedScene).instantiate() as SharedCharacterRig
	(Engine.get_main_loop() as SceneTree).root.add_child(rig)
	return rig

func test_realistic_materials_keep_portable_pbr_maps_and_skinning() -> void:
	var rig := _rig()
	var found: Dictionary = {}
	for mesh: MeshInstance3D in rig.get_node("Model").find_children("*", "MeshInstance3D", true, false):
		if not (String(mesh.name).begins_with("Clothing_") or String(mesh.name).begins_with("Anatomy_") or String(mesh.name).begins_with("Hair_") or mesh.name == &"Character_Head"):
			continue
		assert_true(mesh.skin != null, "All hero sections must deform with the shared skeleton")
		for index: int in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(index) as BaseMaterial3D
			if material == null or not material.resource_name.begins_with("kalev_") or material.resource_name == "kalev_sclera":
				continue
			found[material.resource_name] = true
			assert_true(material.albedo_texture != null, "Portable albedo: " + material.resource_name)
			assert_true(material.normal_enabled and material.normal_texture != null, "Portable normals: " + material.resource_name)
			assert_true(material.roughness_texture != null, "Portable roughness: " + material.resource_name)
			assert_eq(material.roughness_texture_channel, BaseMaterial3D.TEXTURE_CHANNEL_GREEN)
	for required: String in ["kalev_skin", "kalev_hair", "kalev_wool", "kalev_apron", "kalev_boot"]:
		assert_true(found.has(required), "Realism material is live: " + required)
	rig.free()

func test_hero_equipment_swaps_preserve_identity_motion_and_restore_coverage() -> void:
	var rig := _rig()
	var player := rig.animation_player()
	var skin := rig.skeleton()
	var torso := rig.get_node("Model").find_child("Clothing_Torso", true, false) as MeshInstance3D
	var hair := rig.get_node("Model").find_child("Hair_Scalp", true, false) as MeshInstance3D
	for kind: String in ["mail", "helmet", "cape"]:
		assert_true(rig.equip_wearable(load("res://assets/storybook/equipment/kalev_%s.tres" % kind)))
	assert_false(torso.visible)
	assert_false(hair.visible)
	assert_false(rig.equip_wearable(load("res://assets/storybook/equipment/mart_mail.tres")), "Reject a different body fit without removing current armour")
	assert_eq(rig.equipped_wearable(&"torso").fitted_body, "kalev")
	for prop: String in ["hammer", "sword"]:
		assert_true(rig.equip(&"right_hand", load("res://assets/storybook/equipment/%s.tscn" % prop)) != null)
		for clip: StringName in [&"idle", &"walk", &"run", &"hammer_attack", &"sword_attack", &"guard"]:
			assert_true(rig.play_animation(clip, 0.0))
			player.seek(0.3, true)
			assert_eq(rig.animation_player(), player)
			assert_eq(rig.skeleton(), skin)
	for slot: StringName in [&"torso", &"head", &"back"]:
		rig.unequip_wearable(slot)
	assert_true(torso.visible)
	assert_true(hair.visible)
	assert_eq(rig.variant_id(), &"char.kalev")
	rig.free()
