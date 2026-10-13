extends "res://tests/godot/test_case.gd"

## Clothing strip prototype: pick a layer by ray, pull it off, redress, refuse minors
## (docs/SYSTEMS/CLOTHING_STRIP.md).


func _rig(variant: String) -> SharedCharacterRig:
	var scene := load("res://assets/characters/variants/%s.tscn" % variant) as PackedScene
	var rig := scene.instantiate() as SharedCharacterRig
	(Engine.get_main_loop() as SceneTree).root.add_child(rig)
	return rig


func _centre_ray(rig: SharedCharacterRig, slot: String) -> Array[Vector3]:
	for child: Node in rig.skeleton().get_children():
		var mesh := child as MeshInstance3D
		if mesh != null and String(mesh.name).begins_with("Garment_wearable_%s_" % slot):
			# Aim high in the box: the apron's smaller box sits over the gown's middle.
			var box := mesh.get_aabb()
			var centre := (
				mesh.global_transform
				* (
					box.get_center() + Vector3(0.0, box.size.y * 0.4, 0.0)
					if slot == "torso"
					else box.get_center()
				)
			)
			return [centre + Vector3(0.0, 0.0, 5.0), Vector3(0.0, 0.0, -1.0)]
	return []


func test_pick_strip_and_redress() -> void:
	var rig := _rig("aita")
	var strip := ClothingStrip.new()
	strip.register(rig)
	for slot in ["torso", "outerwear", "head", "feet"]:
		assert_true(rig.equipped_wearable(StringName(slot)) != null, "aita wears %s" % slot)
		var ray := _centre_ray(rig, slot)
		assert_false(ray.is_empty(), "%s garment mesh is mounted" % slot)
		var hit := strip.pick(ray[0], ray[1])
		assert_eq(hit.get("slot"), StringName(slot), "ray through the %s box picks it" % slot)
	assert_true(strip.strip(rig, &"outerwear"), "apron comes off")
	assert_true(rig.equipped_wearable(&"outerwear") == null, "apron is gone")
	assert_true(rig.equipped_wearable(&"torso") != null, "gown stays")
	assert_false(strip.strip(rig, &"outerwear"), "nothing left to strip in that slot")
	strip.redress_all()
	assert_true(rig.equipped_wearable(&"outerwear") != null, "redress puts the apron back")
	strip.free()
	rig.queue_free()


func test_minors_and_hero_are_refused() -> void:
	for variant in ["citizen_m_child_average", "apprentice"]:
		var rig := _rig(variant)
		var strip := ClothingStrip.new()
		strip.register(rig)
		assert_false(strip.strip(rig, &"torso"), "%s is never stripped" % variant)
		assert_true(
			strip.pick(Vector3(0, 1, 5), Vector3(0, 0, -1)).is_empty(),
			"%s is not pickable" % variant
		)
		strip.free()
		rig.queue_free()


func test_bare_body_drag_shows_the_nude_twin_and_redress_restores() -> void:
	var rig := _rig("citizen_f_adult_average")
	if not SpiritUndress.eligible(rig):
		rig.queue_free()
		return
	var strip := ClothingStrip.new()
	strip.register(rig)
	var ray_origin := rig.global_position + Vector3(0.0, 1.0, 5.0)
	var hit := strip.pick(ray_origin, Vector3(0.0, 0.0, -1.0))
	assert_eq(
		hit.get("slot"),
		ClothingStrip.BODY_SLOT,
		"a ray through the torso with no layer picks the body"
	)
	assert_true(strip.strip(rig, ClothingStrip.BODY_SLOT), "body drag undresses")
	assert_true(SpiritUndress.is_undressed(rig), "nude twin is mounted")
	assert_false(strip.strip(rig, ClothingStrip.BODY_SLOT), "already bare")
	strip.redress_all()
	assert_false(SpiritUndress.is_undressed(rig), "redress restores the outfit")
	strip.free()
	rig.queue_free()
