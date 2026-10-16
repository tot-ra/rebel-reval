extends "res://tests/godot/test_case.gd"

## Layered citizen dress (docs/SYSTEMS/CITIZEN_WARDROBE.md, tasks R-1663, R-1667).

const BODY := "citizen_m_adult_sturdy"


func _rig(body: String = BODY) -> SharedCharacterRig:
	var scene := load("res://assets/characters/variants/%s.tscn" % body) as PackedScene
	var rig := scene.instantiate() as SharedCharacterRig
	(Engine.get_main_loop() as SceneTree).root.add_child(rig)
	return rig


func _layer_meshes(rig: SharedCharacterRig, layer: String) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for child: Node in rig.skeleton().get_children():
		var prefix := "Garment_wear_%s_" % layer
		if child is MeshInstance3D and String(child.name).begins_with(prefix):
			found.append(child as MeshInstance3D)
	return found


func test_every_body_layer_exists_and_is_skinned() -> void:
	var bodies := ["citizen_m_adult_average", "citizen_f_adult_average_b"]
	bodies.append("citizen_m_child_average")
	for body: String in bodies:
		var rig := _rig(body)
		for layer: String in ["hood", "veil_over", "keys"]:
			var scene := CitizenWardrobe.layer_scene(body, layer)
			if scene == null:
				continue
			assert_true(
				rig.equip_garment(StringName("probe_" + layer), scene),
				"%s %s is a skinned garment" % [body, layer]
			)
		rig.queue_free()


func test_dress_mounts_and_dyes_the_crown_kit() -> void:
	var rig := _rig()
	var red := Color(0.58, 0.11, 0.09)
	var record := {
		"body": BODY,
		"wear": ["gambeson", "mail_haubergeon", "surcoat", "kettle_hat"],
		"wear_dye": {"surcoat": [red.r, red.g, red.b]},
		"duty": {"kit": "crown"},
	}
	CitizenGear.arm(rig, record)
	for layer: String in record["wear"]:
		assert_true(rig.has_garment(StringName("wear_" + layer)), layer)
	assert_false(rig.has_garment(&"duty_hat"), "fitted kettle hat replaces the shared fallback")
	var surcoat := _layer_meshes(rig, "surcoat")
	assert_false(surcoat.is_empty())
	var dyed := false
	for mesh: MeshInstance3D in surcoat:
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface) as ShaderMaterial
			if material != null and material.resource_name.ends_with("_surcoat"):
				dyed = dyed or int(material.get_shader_parameter(&"dye_slot")) == 1
		var outer: Color = mesh.get_instance_shader_parameter(&"dye_outer")
		dyed = dyed and outer.is_equal_approx(_linear(red))
	assert_true(dyed, "surcoat in the crown's red")
	assert_eq(CitizenWardrobe.dress(rig, record), 4, "dressing twice keeps the same layers")
	rig.queue_free()


func test_missing_layer_is_skipped() -> void:
	var rig := _rig("citizen_f_child_average")
	var record := {"body": "citizen_f_child_average", "wear": ["bascinet"]}
	assert_eq(CitizenWardrobe.dress(rig, record), 0)
	rig.queue_free()


func test_runtime_records_only_wear_fitted_layers() -> void:
	var roster := CitizenRoster.load_default()
	var worn := 0
	for r: Dictionary in roster.residents:
		for entry: String in r.get("wear", []):
			# Entries carry a variant cell, "<layer>@<cell>" (R-2004).
			var layer := entry.get_slice("@", 0)
			worn += 1
			assert_true(
				ResourceLoader.exists(CitizenWardrobe.LAYER_PATH % [r["body"], layer]),
				"%s wears %s" % [r["id"], layer]
			)
	assert_true(worn > 2000, "the crowd is dressed in layers, got %d" % worn)


func _linear(c: Color) -> Color:
	var linear := c.srgb_to_linear()
	linear.a = 1.0
	return linear


## Cloth surface of the base body whose material name ends with `suffix`.
func _body_cloth(rig: SharedCharacterRig, suffix: String) -> Array:
	for child: Node in rig.skeleton().get_children():
		var mesh := child as MeshInstance3D
		if mesh == null or mesh.mesh == null or String(mesh.name).begins_with("Garment_"):
			continue
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface)
			if material != null and material.resource_name.ends_with(suffix):
				return [mesh, material]
	return []


func _grade(material: Material) -> String:
	var shader := material as ShaderMaterial
	if shader == null:
		return ""
	var albedo := shader.get_shader_parameter(&"albedo_tex") as Texture2D
	return albedo.resource_path.get_file().get_slice("_albedo", 0)


func test_grade_follows_wealth() -> void:
	var under := [0.2, 0.2, 0.2]
	var rich := {
		"id": "t.rich", "body": BODY, "status": "patrician", "trade": "merchant",
		"cloth": [0.42, 0.13, 0.1], "under": under,
	}
	var poor := {
		"id": "t.poor", "body": BODY, "status": "labourer", "trade": "porter",
		"cloth": [0.46, 0.44, 0.4], "under": under,
	}
	var middling := {
		"id": "t.mid", "body": BODY, "status": "master_craftsman", "trade": "smith",
		"cloth": [0.46, 0.44, 0.4], "under": under,
	}
	var expected := {
		"t.rich": ["scarlet", "linen_fine"],
		"t.poor": ["homespun", "linen_coarse"],
		"t.mid": ["broadcloth", "linen_fine"],
	}
	for record: Dictionary in [rich, poor, middling]:
		var rig := _rig()
		CitizenWardrobe.dress(rig, record)
		var tunic := _body_cloth(rig, "_short_tunic")
		var braies := _body_cloth(rig, "_braies")
		assert_false(tunic.is_empty() or braies.is_empty(), "%s base cloth found" % record["id"])
		assert_eq(_grade(tunic[1]), expected[record["id"]][0], "%s tunic" % record["id"])
		assert_eq(_grade(braies[1]), expected[record["id"]][1], "%s braies" % record["id"])
		var outer: Color = (tunic[0] as MeshInstance3D).get_instance_shader_parameter(&"dye_outer")
		var cloth: Array = record["cloth"]
		assert_true(outer.is_equal_approx(_linear(Color(cloth[0], cloth[1], cloth[2]))), "tunic dyed")
		rig.queue_free()


func test_materials_are_shared_and_wear_is_per_resident() -> void:
	var a := _rig()
	var b := _rig()
	var base := {"body": BODY, "status": "labourer", "wear": ["coif"]}
	CitizenWardrobe.dress(a, base.merged({"id": "t.a", "trade": "labourer"}))
	CitizenWardrobe.dress(b, base.merged({"id": "t.b", "trade": "smith"}))
	var tunic_a := _body_cloth(a, "_short_tunic")
	var tunic_b := _body_cloth(b, "_short_tunic")
	assert_true(tunic_a[1] == tunic_b[1], "one shared material per garment and grade")
	var coif_a := _layer_meshes(a, "coif")[0].get_active_material(0)
	assert_true(coif_a == _layer_meshes(b, "coif")[0].get_active_material(0), "shared layer material")
	var soil_a: Vector4 = (tunic_a[0] as MeshInstance3D).get_instance_shader_parameter(&"wear_soil")
	var soil_b: Vector4 = (tunic_b[0] as MeshInstance3D).get_instance_shader_parameter(&"wear_soil")
	assert_true(soil_a.x > 0.5 and soil_a.y == 0.0, "labourer: muddy hems, no soot")
	assert_true(soil_b.y > 0.5, "smith: soot")
	a.queue_free()
	b.queue_free()


func test_wear_rules() -> void:
	var master := {"id": "x", "status": "master_craftsman"}
	var smith := CitizenWardrobe.wear_of(master.merged({"trade": "smith"}))
	var baker := CitizenWardrobe.wear_of(master.merged({"trade": "baker"}))
	var butcher := CitizenWardrobe.wear_of(master.merged({"trade": "butcher"}))
	var patrician := CitizenWardrobe.wear_of({"id": "x", "status": "patrician", "trade": "merchant"})
	var servant := CitizenWardrobe.wear_of({"id": "x", "status": "servant", "trade": "maid"})
	assert_true(smith[0].y > 0.5 and baker[0].z > 0.5 and butcher[0].w > 0.5, "trade marks")
	assert_true(servant[1].x > 0.4 and servant[1].y > 0.3, "poor wool is patched and faded")
	assert_eq(patrician[1].x, 0.0, "the rich wear no patches")
	assert_true(patrician[0].x < servant[0].x, "the rich keep their hems cleaner")
	var again := {"id": "y", "status": "servant"}
	assert_eq(CitizenWardrobe.wear_of(again), CitizenWardrobe.wear_of(again), "deterministic")
	assert_eq(CitizenWardrobe.grade_of("leather", 0, 0), "leather")
	assert_eq(CitizenWardrobe.grade_of("quilted", 2, 1), "quilted")


func test_every_grade_set_loads() -> void:
	for grade: String in CitizenWardrobe.GRADE_TILE:
		for kind: String in ["albedo", "normal", "orm"]:
			var path := "%s%s_%s_512.png" % [CitizenWardrobe.TEXTILE_DIR, grade, kind]
			assert_true(ResourceLoader.exists(path), path)
	assert_true(ResourceLoader.exists(CitizenWardrobe.WEAR_MASK))


func test_armour_range_layers_are_skinned() -> void:
	var rig := _rig("citizen_m_adult_sturdy")
	var layers := [
		"coat_of_plates", "aventail", "great_helm", "mail_chausses", "gauntlets", "order_mantle"
	]
	for layer: String in layers:
		var scene := CitizenWardrobe.layer_scene("citizen_m_adult_sturdy", layer)
		assert_true(scene != null, "%s layer exists" % layer)
		if scene != null:
			assert_true(rig.equip_garment(StringName("probe_" + layer), scene), "%s is skinned" % layer)
	rig.queue_free()


func test_order_mantle_keeps_its_cross_black_when_dyed() -> void:
	var rig := _rig("citizen_m_adult_average")
	var tint := Color(0.5, 0.6, 0.7)
	var record := {
		"body": "citizen_m_adult_average",
		"wear": ["order_mantle"],
		"wear_dye": {"order_mantle": [tint.r, tint.g, tint.b]},
	}
	CitizenWardrobe.dress(rig, record)
	var cloth := false
	var cross_untouched := false
	# Woven cloth (R-1667): the dye is the mesh's `dye_outer` instance uniform and
	# `dye_slot` says which surface takes it; the cross keeps its baked colour.
	for mesh: MeshInstance3D in _layer_meshes(rig, "order_mantle"):
		var outer: Color = mesh.get_instance_shader_parameter(&"dye_outer")
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface) as ShaderMaterial
			if material == null:
				continue
			var slot := int(material.get_shader_parameter(&"dye_slot"))
			if material.resource_name.ends_with("_order_mantle"):
				cloth = cloth or (slot == 1 and outer.is_equal_approx(_linear(tint)))
			elif material.resource_name.ends_with("_order_cross"):
				cross_untouched = slot == 0
	assert_true(cloth, "white wool takes the dye")
	assert_true(cross_untouched, "the black cross is a separate undyed material")
	rig.queue_free()


func test_shield_is_carried_on_the_left_hand() -> void:
	var rig := _rig("citizen_m_adult_average")
	CitizenGear.arm(rig, {"body": "citizen_m_adult_average", "wear": [], "shield": "order"})
	assert_true(rig.equipped(&"left_hand") != null, "order shield on the left hand")
	rig.queue_free()
	for kind: String in ["order", "crown", "field", "plain"]:
		assert_true(CitizenShield.scene(kind, Color(0.2, 0.3, 0.5)) != null, "%s shield scene" % kind)


## R-2003: the watch carries the pipeline spear variant, mounted by its grip socket.
func test_watch_carries_the_spear_variant() -> void:
	var rig := _rig("citizen_m_adult_average")
	CitizenGear.arm(rig, {"body": "citizen_m_adult_average", "wear": [], "duty": {"kit": "watch"}})
	var spear := rig.equipped(&"right_hand")
	assert_true(spear != null, "watch spear in the right hand")
	if spear != null:
		assert_eq(spear.scene_file_path, "res://assets/props/weapons/spear/variants/spear_p1_w1.glb")
		var butt := spear.get_node_or_null("socket_butt") as Node3D
		var tip := spear.get_node_or_null("socket_tip") as Node3D
		assert_true(butt != null and tip != null, "butt and tip sockets exported")
		if butt != null and tip != null:
			# Real size: a 2.1-2.4 m watch spear, origin at the grip between butt and tip.
			assert_true(butt.position.y < 0.0 and tip.position.y > 0.0, "origin at the grip")
			var length := tip.position.y - butt.position.y
			assert_true(length > 2.1 and length < 2.4, "spear length %.2f m" % length)
	rig.queue_free()
