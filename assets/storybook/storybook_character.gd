extends SharedCharacterRig
## Reuse the game's equipment, garment and animation APIs for the live grounded models.
## They currently ship one mesh tier, so never hide it for an absent LOD or
## accidentally load the older production bodies with matching basenames.

func _configure_lod0_visibility() -> void:
	for mesh: MeshInstance3D in $Model.find_children("*", "MeshInstance3D", true, false):
		mesh.visibility_range_begin = 0.0
		mesh.visibility_range_end = 0.0

func _install_distance_lods() -> void:
	pass

func _ready() -> void:
	super._ready()
	_sync_kirtle_coverage()

func equip_wearable(wearable: CharacterWearable) -> bool:
	var accepted := super.equip_wearable(wearable)
	_sync_kirtle_coverage()
	return accepted

func unequip_wearable(slot: StringName) -> void:
	super.unequip_wearable(slot)
	_sync_kirtle_coverage()

func _sync_kirtle_coverage() -> void:
	if body_basename() not in ["aita", "ellen", "kaja"]:
		return
	var outerwear := $Model.find_child("Clothing_Outerwear", true, false) as MeshInstance3D
	var hose := $Model.find_child("Clothing_Legs", true, false) as MeshInstance3D
	if outerwear != null and hose != null:
		# The long kirtle covers the entire hose. Omit that hidden underlayer
		# during stride/attack poses; removing the kirtle for mail restores it.
		var covered_by_gear := false
		for slot: String in CharacterWardrobe.SLOTS:
			var wearable := equipped_wearable(StringName(slot))
			if wearable == null:
				continue
			for prefix: StringName in wearable.covered_meshes:
				if "Clothing_Legs".begins_with(String(prefix)):
					covered_by_gear = true
		hose.visible = not outerwear.visible and not covered_by_gear

func _apply_variant() -> void:
	if variant == null:
		return
	_apply_material_stack($Model, variant.material_tint)
	if _skeleton == null:
		return
	if variant.equipment != null:
		var held := variant.equipment
		if held.resource_path == "res://assets/characters/shared/hammer.tscn":
			held = load("res://assets/storybook/equipment/hammer.tscn") as PackedScene
		elif held.resource_path == "res://assets/characters/shared/sword.tscn":
			held = load("res://assets/storybook/equipment/sword.tscn") as PackedScene
		equip(&"right_hand", held)
	# Legacy flags remain supported, with a body-fitted replacement instead of
	# binding hero-sized garments to Mart or another incompatible rest skeleton.
	if variant.show_cape:
		equip_wearable(load("res://assets/storybook/equipment/%s_cape.tres" % body_basename()))
	if variant.show_hat:
		equip_wearable(load("res://assets/storybook/equipment/%s_helmet.tres" % body_basename()))
	for wearable: CharacterWearable in variant.wearables:
		equip_wearable(wearable)

func equip_garment(garment_id: StringName, scene: PackedScene) -> bool:
	if garment_id in [&"cape", &"hat"] and scene == GARMENT_SCENES[garment_id]:
		var kind := "cape" if garment_id == &"cape" else "helmet"
		return equip_wearable(load("res://assets/storybook/equipment/%s_%s.tres" % [body_basename(), kind]))
	return super.equip_garment(garment_id, scene)

func has_garment(garment_id: StringName) -> bool:
	if garment_id in [&"cape", &"hat"]:
		return equipped_wearable(&"back" if garment_id == &"cape" else &"head") != null
	return super.has_garment(garment_id)

func unequip_garment(garment_id: StringName) -> void:
	if garment_id in [&"cape", &"hat"]:
		unequip_wearable(&"back" if garment_id == &"cape" else &"head")
		return
	super.unequip_garment(garment_id)
