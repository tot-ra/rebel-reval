extends "res://tests/godot/test_case.gd"

## Layered citizen dress (docs/SYSTEMS/CITIZEN_WARDROBE.md, tasks R-1663, R-1665, R-1667).

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
		for layer: String in r.get("wear", []):
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
	var layers: Array[String] = [
		"coat_of_plates", "aventail", "great_helm", "mail_chausses", "gauntlets", "order_mantle"
	]
	for layer: String in layers:
		var scene := CitizenWardrobe.layer_scene("citizen_m_adult_sturdy", layer)
		assert_true(scene != null, "%s layer exists" % layer)
		if scene != null:
			var probe := StringName("probe_" + layer)
			assert_true(rig.equip_garment(probe, scene), "%s is skinned" % layer)
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
	var cross_slot := -1
	for mesh: MeshInstance3D in _layer_meshes(rig, "order_mantle"):
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface) as ShaderMaterial
			if material == null:
				continue
			var slot := int(material.get_shader_parameter(&"dye_slot"))
			if material.resource_name.ends_with("_order_mantle"):
				var outer: Color = mesh.get_instance_shader_parameter(&"dye_outer")
				cloth = cloth or (slot == 1 and outer.is_equal_approx(_linear(tint)))
			elif material.resource_name.ends_with("_order_cross"):
				cross_slot = slot
	assert_true(cloth, "white wool takes the dye")
	assert_eq(cross_slot, 0, "the black cross is a separate material that keeps its colour")
	rig.queue_free()


func test_shield_is_carried_on_the_left_hand() -> void:
	var rig := _rig("citizen_m_adult_average")
	var record := {"body": "citizen_m_adult_average", "wear": [], "shield": "order"}
	CitizenGear.arm(rig, record)
	assert_true(rig.equipped(&"left_hand") != null, "order shield on the left hand")
	rig.queue_free()
	for kind: String in ["order", "crown", "field", "plain"]:
		var scene := CitizenShield.scene(kind, Color(0.2, 0.3, 0.5))
		assert_true(scene != null, "%s shield scene" % kind)


func test_women_head_layers_exist_per_outfit() -> void:
	# WD-3: grown women carry the braid and the headscarf as layers; the head cloth is
	# fitted to the Estonian outfit only; elders have the headscarf and no braid.
	for build: String in ["thin", "average", "sturdy", "heavy"]:
		for outfit: String in ["", "_b", "_c", "_d"]:
			var body := "citizen_f_adult_%s%s" % [build, outfit]
			for layer: String in ["braids", "headscarf"]:
				assert_true(ResourceLoader.exists(CitizenWardrobe.LAYER_PATH % [body, layer]), body + " " + layer)
			assert_eq(
				ResourceLoader.exists(CitizenWardrobe.LAYER_PATH % [body, "head_cloth"]),
				outfit == "_d",
				body + " head cloth only with the wrap skirt"
			)
	for body: String in ["citizen_f_elder_thin", "citizen_f_elder_heavy"]:
		assert_true(ResourceLoader.exists(CitizenWardrobe.LAYER_PATH % [body, "headscarf"]), body)
		assert_false(ResourceLoader.exists(CitizenWardrobe.LAYER_PATH % [body, "braids"]), body)


func test_surcoat_and_kirtle_take_two_dyes() -> void:
	var rig := _rig("citizen_f_adult_average_c")
	var record := {
		"id": "t.c", "body": "citizen_f_adult_average_c", "status": "patrician", "trade": "merchant",
		"cloth": [0.42, 0.13, 0.1], "under": [0.17, 0.24, 0.38], "wear": ["braids"],
	}
	CitizenWardrobe.dress(rig, record)
	var surcoat := _body_cloth(rig, "_sideless_surcoat")
	var kirtle := _body_cloth(rig, "_kirtle")
	assert_false(surcoat.is_empty() or kirtle.is_empty(), "surcoat and kirtle are woven cloth")
	if not surcoat.is_empty() and not kirtle.is_empty():
		assert_eq(_grade(surcoat[1]), "scarlet", "rich surcoat in scarlet")
		assert_eq(_grade(kirtle[1]), "broadcloth", "kirtle beneath in broadcloth")
		var under: Color = (kirtle[0] as MeshInstance3D).get_instance_shader_parameter(&"dye_under")
		assert_true(under.is_equal_approx(_linear(Color(0.17, 0.24, 0.38))), "kirtle takes the under dye")
	assert_false(_layer_meshes(rig, "braids").is_empty(), "the braid is mounted")
	rig.queue_free()


func test_wrap_skirt_dyed_shift_stays_linen() -> void:
	var rig := _rig("citizen_f_adult_thin_d")
	var record := {
		"id": "t.d", "body": "citizen_f_adult_thin_d", "status": "servant", "trade": "maid",
		"cloth": [0.3, 0.21, 0.14], "under": [0.2, 0.2, 0.2], "wear": ["head_cloth"],
		"wear_dye": {"head_cloth": [0.88, 0.86, 0.8]},
	}
	CitizenWardrobe.dress(rig, record)
	var skirt := _body_cloth(rig, "_wrap_skirt")
	assert_false(skirt.is_empty(), "wrap skirt is woven cloth")
	if not skirt.is_empty():
		assert_eq(_grade(skirt[1]), "homespun", "poor wool")
		var outer: Color = (skirt[0] as MeshInstance3D).get_instance_shader_parameter(&"dye_outer")
		assert_true(outer.is_equal_approx(_linear(Color(0.3, 0.21, 0.14))), "wrap skirt dyed")
	assert_eq(CitizenWardrobe.dye_slot("citizen_f_adult_thin_d_linen_shift", ""), 0, "shift keeps its linen")
	assert_false(_layer_meshes(rig, "head_cloth").is_empty(), "head cloth mounted")
	rig.queue_free()
