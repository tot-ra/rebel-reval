extends "res://tests/godot/test_case.gd"

# Legacy three-LOD wardrobe remains covered; live fitted wardrobe is tested in test_storybook_live_integration.
const HERO := preload("res://assets/characters/shared/shared_character_rig.tscn")
const MART := preload("res://assets/characters/variants/mart.tscn")
const MAIL := preload("res://assets/characters/shared/hero_mail.tres")

func _rig(scene: PackedScene = HERO) -> SharedCharacterRig:
	var rig := scene.instantiate() as SharedCharacterRig
	(Engine.get_main_loop() as SceneTree).root.add_child(rig)
	return rig

func _covered(rig: SharedCharacterRig, prefix: String) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for node: Node in rig.find_children("*", "MeshInstance3D", true, false):
		if CharacterWardrobe._body_mesh_name(node).begins_with(prefix):
			result.append(node as MeshInstance3D)
	return result

func test_outfit_replaces_all_lods_and_restores_the_default_clothes() -> void:
	var rig := _rig()
	var hammer := load("res://assets/characters/shared/hammer.tscn") as PackedScene
	assert_true(rig.equip(&"right_hand", hammer) != null)
	var torso := _covered(rig, "Clothing_Torso")
	assert_eq(torso.size(), 3, "independently replaceable torso in each LOD")
	assert_true(rig.equip_wearable(MAIL))
	assert_eq(rig.equipped_wearable(&"torso").stable_id, &"wearable.kalev_mail")
	for mesh: MeshInstance3D in torso:
		assert_false(mesh.visible, "default tunic cannot reappear at a distance")
	for mesh: MeshInstance3D in _covered(rig, "Clothing_Outerwear"):
		assert_false(mesh.visible, "apron is removed while mail is worn")
	assert_true(rig.has_equipment(), "outfit swaps must retain the held hammer")
	var player := rig.animation_player()
	for animation: StringName in [&"walk", &"run", &"hammer_attack", &"sit_idle"]:
		assert_true(rig.play_animation(animation))
		player.seek(0.3, true)
		assert_eq(rig.animation_player(), player, "outfits reuse the live animation player")
	rig.unequip_wearable(&"torso")
	for mesh: MeshInstance3D in torso:
		assert_true(mesh.visible)
	assert_eq(rig.equipped_wearable(&"torso"), null)
	rig.queue_free()

func test_mismatched_body_and_invalid_replacement_preserve_current_outfit() -> void:
	var mart := _rig(MART)
	var own_torso := mart.equipped_wearable(&"torso")
	assert_false(mart.equip_wearable(MAIL), "sharing bones does not make Kalev's armor fit Mart")
	assert_eq(mart.equipped_wearable(&"torso"), own_torso, "a rejected fit keeps Mart's own tunic")
	var rig := _rig()
	assert_true(rig.equip_wearable(MAIL))
	var invalid := MAIL.duplicate() as CharacterWearable
	invalid.covered_meshes = [&"Clothing_Typo"]
	assert_false(rig.equip_wearable(invalid))
	invalid = MAIL.duplicate() as CharacterWearable
	invalid.scene = preload("res://assets/characters/shared/hammer.tscn")
	assert_false(rig.equip_wearable(invalid), "rigid props cannot be mounted as skinned clothing")
	assert_true(rig.has_garment(&"wearable_torso"))
	assert_eq(rig.equipped_wearable(&"torso"), MAIL)
	rig.queue_free()
	mart.queue_free()

func test_overlapping_coverage_and_per_instance_isolation() -> void:
	var rig := _rig()
	var other := _rig()
	var outer := MAIL.duplicate() as CharacterWearable
	outer.slot = "outerwear"
	outer.stable_id = &"wearable.test_outer"
	assert_true(rig.equip_wearable(MAIL))
	assert_true(rig.equip_wearable(outer))
	rig.unequip_wearable(&"torso")
	for mesh: MeshInstance3D in _covered(rig, "Clothing_Torso"):
		assert_false(mesh.visible, "remaining outer layer still covers this region")
	for mesh: MeshInstance3D in _covered(other, "Clothing_Torso"):
		assert_true(mesh.visible, "equipping one character must not affect another")
	rig.unequip_wearable(&"outerwear")
	for mesh: MeshInstance3D in _covered(rig, "Clothing_Torso"):
		assert_true(mesh.visible)
	rig.queue_free()
	other.queue_free()

func test_garments_share_skinning_materials_and_readability_layers() -> void:
	var rig := _rig()
	rig.add_visual_layer(7)
	rig.set_occlusion_ghost(true)
	assert_true(rig.equip_wearable(MAIL))
	var mounted := 0
	for child: Node in rig.skeleton().get_children():
		if not child is MeshInstance3D or not String(child.name).begins_with("Garment_wearable_torso_"):
			continue
		var mesh := child as MeshInstance3D
		mounted += 1
		assert_eq(mesh.get_node(mesh.skeleton), rig.skeleton())
		assert_true(mesh.skin != null)
		assert_true(mesh.get_layer_mask_value(7))
		assert_true(mesh.material_overlay != null)
		assert_true(mesh.get_surface_override_material(0) != null)
	assert_eq(mounted, 3, "torso and two fitted sleeves")
	rig.queue_free()

func test_variant_can_spawn_with_a_fitted_outfit() -> void:
	var rig := HERO.instantiate() as SharedCharacterRig
	rig.variant = rig.variant.duplicate() as CharacterVariant
	rig.variant.wearables = [MAIL]
	(Engine.get_main_loop() as SceneTree).root.add_child(rig)
	assert_eq(rig.equipped_wearable(&"torso"), MAIL)
	for mesh: MeshInstance3D in _covered(rig, "Clothing_Torso"):
		assert_false(mesh.visible, "late-installed LODs inherit initial outfit coverage")
	assert_eq(_covered(rig, "Clothing_Torso").size(), 3)
	rig.queue_free()

func test_headwear_hides_hair_without_hiding_the_face_or_beard() -> void:
	var rig := _rig()
	assert_true(rig.equip_wearable(preload("res://assets/characters/shared/hero_hat_wearable.tres")))
	var hair := _covered(rig, "Hair_Scalp")
	assert_eq(hair.size(), 3)
	for mesh: MeshInstance3D in hair:
		assert_false(mesh.visible)
	for prefix: String in ["Character_Head", "Hair_Beard"]:
		for mesh: MeshInstance3D in _covered(rig, prefix):
			assert_true(mesh.visible, "hat must preserve the face and beard")
	rig.unequip_wearable(&"head")
	for mesh: MeshInstance3D in hair:
		assert_true(mesh.visible)
	rig.queue_free()

func test_body_fit_uses_geometry_not_character_identity() -> void:
	var rig := HERO.instantiate() as SharedCharacterRig
	rig.variant = rig.variant.duplicate() as CharacterVariant
	rig.variant.stable_id = &"char.new_identity_same_body"
	(Engine.get_main_loop() as SceneTree).root.add_child(rig)
	assert_true(rig.lod_mesh_count(1) > 0, "new identities retain their body's distant LODs")
	assert_true(rig.lod_mesh_count(2) > 0)
	assert_eq(rig.body_basename(), "heroic_humanoid")
	assert_true(rig.equip_wearable(MAIL), "data-only identities can share fitted clothing")
	var mart := MART.instantiate() as SharedCharacterRig
	mart.variant = mart.variant.duplicate() as CharacterVariant
	mart.variant.stable_id = &"char.kalev"
	(Engine.get_main_loop() as SceneTree).root.add_child(mart)
	assert_eq(mart.lod_mesh_count(1), 0, "Replacement body has no legacy LODs")
	assert_eq(mart.lod_mesh_count(2), 0)
	assert_eq(mart.body_basename(), "mart")
	assert_false(mart.equip_wearable(MAIL), "an identity change cannot override physical fit")
	rig.queue_free()
	mart.queue_free()
