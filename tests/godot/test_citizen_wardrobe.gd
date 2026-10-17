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


## Fitted layers are shipped once per body shape (task R-2212).
func test_outfit_variants_share_their_shape_layers() -> void:
	assert_eq(
		CitizenWardrobe.layer_path("citizen_f_adult_thin_c", "headscarf"),
		"res://assets/characters/realistic/shapes/citizen_f_adult_thin/layers/headscarf.glb"
	)
	assert_eq(
		CitizenWardrobe.layer_body("citizen_m_adult_sturdy_b", "surcoat"),
		"citizen_m_adult_sturdy_b",
		"a layer that sits over the baked tunic stays with its outfit"
	)
	assert_eq(CitizenWardrobe.layer_body("kalev", "hood"), "kalev", "other bodies keep their own folder")
	assert_true(
		CitizenWardrobe.layer_scene("citizen_m_adult_sturdy_b", "coif")
		== CitizenWardrobe.layer_scene("citizen_m_adult_sturdy", "coif"),
		"the two outfits load one scene"
	)


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
				ResourceLoader.exists(CitizenWardrobe.layer_path(r["body"], layer)),
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
		"id": "t.rich",
		"body": BODY,
		"status": "patrician",
		"trade": "merchant",
		"cloth": [0.42, 0.13, 0.1],
		"under": under,
	}
	var poor := {
		"id": "t.poor",
		"body": BODY,
		"status": "labourer",
		"trade": "porter",
		"cloth": [0.46, 0.44, 0.4],
		"under": under,
	}
	var middling := {
		"id": "t.mid",
		"body": BODY,
		"status": "master_craftsman",
		"trade": "smith",
		"cloth": [0.46, 0.44, 0.4],
		"under": under,
	}
	var expected := {
		"t.rich": ["scarlet", "linen_fine"],
		"t.poor": ["homespun", "linen_coarse_w2"],
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
		assert_true(
			outer.is_equal_approx(_linear(Color(cloth[0], cloth[1], cloth[2]))), "tunic dyed"
		)
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
	assert_true(
		coif_a == _layer_meshes(b, "coif")[0].get_active_material(0), "shared layer material"
	)
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
	var patrician := CitizenWardrobe.wear_of(
		{"id": "x", "status": "patrician", "trade": "merchant"}
	)
	var servant := CitizenWardrobe.wear_of({"id": "x", "status": "servant", "trade": "maid"})
	assert_true(smith[0].y > 0.5 and baker[0].z > 0.5 and butcher[0].w > 0.5, "trade marks")
	assert_true(servant[1].x > 0.4 and servant[1].y > 0.3, "poor wool is patched and faded")
	assert_eq(patrician[1].x, 0.0, "the rich wear no patches")
	assert_true(patrician[0].x < servant[0].x, "the rich keep their hems cleaner")
	var again := {"id": "y", "status": "servant"}
	assert_eq(CitizenWardrobe.wear_of(again), CitizenWardrobe.wear_of(again), "deterministic")
	assert_eq(CitizenWardrobe.grade_of("leather", 0, 0), "leather")
	assert_eq(CitizenWardrobe.grade_of("quilted", 2, 1), "quilted")


func test_poor_linen_is_worn_and_rich_linen_fine() -> void:
	assert_eq(CitizenWardrobe.linen_grade({"id": "a", "status": "labourer"}), "linen_coarse_w2")
	assert_eq(CitizenWardrobe.linen_grade({"id": "a", "status": "servant"}), "linen_coarse_w2")
	var seen := {}
	for i in 30:
		seen[CitizenWardrobe.linen_grade({"id": "p%d" % i, "status": "free_commoner"})] = true
	assert_eq(seen.size(), 2, "commoners roll yellowed or sweat-stained")
	var again := {"id": "p7", "status": "apprentice"}
	assert_eq(
		CitizenWardrobe.linen_grade(again), CitizenWardrobe.linen_grade(again), "deterministic"
	)
	assert_eq(CitizenWardrobe.grade_of("linen", 1, 0), "linen_fine")
	assert_eq(CitizenWardrobe.grade_of("linen", 2, 0), "linen_fine")


func test_every_grade_set_loads() -> void:
	for grade: String in CitizenWardrobe.GRADE_TILE:
		for kind: String in ["albedo", "normal", "orm"]:
			var maps: String = (
				grade if kind == "albedo" else CitizenWardrobe.GRADE_BASE.get(grade, grade)
			)
			var path := "%s%s_%s_512.png" % [CitizenWardrobe.TEXTILE_DIR, maps, kind]
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
			assert_true(
				rig.equip_garment(StringName("probe_" + layer), scene), "%s is skinned" % layer
			)
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
		assert_true(
			CitizenShield.scene(kind, Color(0.2, 0.3, 0.5)) != null, "%s shield scene" % kind
		)


## R-2003: the watch carries the pipeline spear variant, mounted by its grip socket.
func test_watch_carries_the_spear_variant() -> void:
	var rig := _rig("citizen_m_adult_average")
	CitizenGear.arm(rig, {"body": "citizen_m_adult_average", "wear": [], "duty": {"kit": "watch"}})
	var spear := rig.equipped(&"right_hand")
	assert_true(spear != null, "watch spear in the right hand")
	if spear != null:
		assert_eq(
			spear.scene_file_path, "res://assets/props/weapons/spear/variants/spear_p1_w1.glb"
		)
		var butt := spear.get_node_or_null("socket_butt") as Node3D
		var tip := spear.get_node_or_null("socket_tip") as Node3D
		assert_true(butt != null and tip != null, "butt and tip sockets exported")
		if butt != null and tip != null:
			# Real size: a 2.1-2.4 m watch spear, origin at the grip between butt and tip.
			assert_true(butt.position.y < 0.0 and tip.position.y > 0.0, "origin at the grip")
			var length := tip.position.y - butt.position.y
			assert_true(length > 2.1 and length < 2.4, "spear length %.2f m" % length)
	rig.queue_free()


## R-2019: one fitted aketon, its variant cell picks cover, dye, patches and sweat.
func _aketon(cell: String, post: String = "gate.viru") -> Array:
	var rig := _rig("citizen_m_adult_average")
	var record := {
		"id": "t.aketon." + cell,
		"body": "citizen_m_adult_average",
		"status": "soldier",
		"wear": ["gambeson@" + cell],
		"duty": {"kit": "watch", "post": post},
	}
	CitizenWardrobe.dress(rig, record)
	var meshes := _layer_meshes(rig, "gambeson")
	return [rig, meshes[0] if not meshes.is_empty() else null]


func _surface(mesh: MeshInstance3D, suffix: String) -> ShaderMaterial:
	for surface in mesh.mesh.get_surface_count():
		var material := mesh.get_active_material(surface) as ShaderMaterial
		if material != null and material.resource_name.ends_with(suffix):
			return material
	return null


func test_aketon_variant_looks() -> void:
	var looks := {}
	for cell: String in ["p1_w0", "p1_w1", "p1_w2", "p2_w0", "p3_w0"]:
		looks[cell] = _aketon(cell)
	for cell: String in looks:
		assert_true(looks[cell][1] != null, "%s aketon mounted" % cell)
	if looks.values().any(func(pair: Array) -> bool: return pair[1] == null):
		return
	var linen := _surface(looks["p1_w1"][1], "_gambeson")
	assert_eq(_grade(linen), "quilted", "town munition: linen canvas")
	assert_eq(
		linen.get_shader_parameter(&"patch_cell"), CitizenWardrobe.QUILT_PATCH, "channel patches"
	)
	assert_eq(
		_grade(_surface(looks["p3_w0"][1], "_gambeson")), "quilted_silk", "knight: silk cover"
	)
	var undyed: Color = (looks["p1_w1"][1] as MeshInstance3D).get_instance_shader_parameter(
		&"dye_outer"
	)
	var dyed: Color = (looks["p2_w0"][1] as MeshInstance3D).get_instance_shader_parameter(
		&"dye_outer"
	)
	assert_eq(undyed.a, 0.0, "p1 stays undyed")
	assert_eq(dyed.a, 1.0, "p2 is dyed")
	# Bindings and hems take the cloth's dye too.
	assert_eq(
		int(_surface(looks["p2_w0"][1], "_gambeson_binding").get_shader_parameter(&"dye_slot")), 1
	)
	var new_age: Vector4 = (looks["p1_w0"][1] as MeshInstance3D).get_instance_shader_parameter(
		&"wear_age"
	)
	var old_age: Vector4 = (looks["p1_w2"][1] as MeshInstance3D).get_instance_shader_parameter(
		&"wear_age"
	)
	assert_eq(new_age.x, 0.0, "new issue has no patches")
	assert_true(old_age.x > 0.4 and old_age.w > new_age.w, "battered issue: patched and sweated")
	for pair: Array in looks.values():
		(pair[0] as Node).queue_free()


func test_aketon_dye_is_shared_by_a_post() -> void:
	var a := _aketon("p2_w1", "patrol.pikk")
	var b := _aketon("p2_w1", "patrol.pikk")
	if a[1] != null and b[1] != null:
		var dye_a: Color = (a[1] as MeshInstance3D).get_instance_shader_parameter(&"dye_outer")
		var dye_b: Color = (b[1] as MeshInstance3D).get_instance_shader_parameter(&"dye_outer")
		assert_true(dye_a.is_equal_approx(dye_b), "one store, one dye")
	assert_eq(CitizenWardrobe.padded_dye("gambeson", "p1_w1", {}), [], "munition undyed")
	assert_eq(CitizenWardrobe.padded_dye("hood", "p2_w0", {"id": "x"}), [], "only padded layers")
	(a[0] as Node).queue_free()
	(b[0] as Node).queue_free()


func test_aketon_layer_has_collar_and_lacing() -> void:
	var pair := _aketon("p1_w1")
	var mesh := pair[1] as MeshInstance3D
	assert_true(mesh != null)
	if mesh != null:
		assert_true(_surface(mesh, "_gambeson_lace") != null, "laced front")
		# The standing collar rises above the shoulders' neckline: highest vertex near the jaw.
		var top := -INF
		for v: Vector3 in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			top = maxf(top, v.y)
		assert_true(top > 1.4, "standing collar, top %.2f m" % top)
	(pair[0] as Node).queue_free()


## Men's tunics (task R-2023): the base tunic's variant cell, its wear and its buttons.
func test_tunic_cell_follows_wealth_and_trade() -> void:
	for i in 40:
		var poor := CitizenWardrobe.tunic_cell(
			{"id": "t.p%d" % i, "sex": "m", "status": "servant", "trade": "maid"}
		)
		var middling := CitizenWardrobe.tunic_cell(
			{"id": "t.m%d" % i, "sex": "m", "status": "master_craftsman", "trade": "joiner"}
		)
		var rich := CitizenWardrobe.tunic_cell(
			{"id": "t.r%d" % i, "sex": "m", "status": "patrician", "trade": "merchant"}
		)
		assert_true(poor in ["p1_w1", "p1_w2"], "poor homespun, worn: %s" % poor)
		assert_true(middling in ["p2_w0", "p2_w1"], "middling broadcloth: %s" % middling)
		assert_eq(rich, "p3_w0", "rich scarlet, kept fresh")
	var porter := {"id": "t.porter", "sex": "m", "status": "labourer", "trade": "porter"}
	assert_eq(CitizenWardrobe.tunic_cell(porter), "p1_w2", "a porter wears his tunic out")
	assert_eq(
		CitizenWardrobe.tunic_cell({"id": "t.w", "sex": "f", "status": "servant"}), "", "gowns"
	)


func test_tunic_wear_and_buttons() -> void:
	var body := "citizen_m_adult_average"
	var porter := {
		"id": "t.porter",
		"body": body,
		"sex": "m",
		"status": "labourer",
		"trade": "porter",
		"cloth": [0.46, 0.44, 0.4],
		"under": [0.2, 0.2, 0.2],
	}
	var patrician := porter.merged(
		{"id": "t.rich", "status": "patrician", "trade": "merchant"}, true
	)
	for record: Dictionary in [porter, patrician]:
		var rig := _rig(body)
		CitizenWardrobe.dress(rig, record)
		var tunic := _body_cloth(rig, "_short_tunic")
		var mesh := tunic[0] as MeshInstance3D
		var surface := -1
		for s in mesh.mesh.get_surface_count():
			if mesh.mesh.surface_get_material(s).resource_name.ends_with("_short_tunic"):
				surface = s
		var format: int = mesh.mesh.surface_get_format(surface)
		assert_true(format & Mesh.ARRAY_FORMAT_TEX_UV2 != 0, "tunic carries its wear UV2")
		var buttons := _body_cloth(rig, CitizenWardrobe.TUNIC_BUTTONS)
		var cloth: Vector4 = mesh.get_instance_shader_parameter(&"wear_cloth")
		var age: Vector4 = mesh.get_instance_shader_parameter(&"wear_age")
		if record["id"] == "t.porter":
			assert_true(buttons.is_empty(), "p1: sleeve buttons hidden")
			assert_eq(cloth.x, 1.0, "w2: elbows rubbed through")
			assert_true(cloth.y == 1.0 and age.x >= 0.45, "w2: frayed and patched")
		else:
			assert_false(buttons.is_empty(), "p3: pewter buttons at the wrist")
			assert_true(cloth.y == 0.0 and age.x == 0.0, "w0: clean edges, no patches")
		rig.queue_free()


## R-2028: every hood has a liripipe; the dags on the hem show on p3 only.
func test_hood_dags_show_on_prestige_three() -> void:
	var body := "citizen_m_adult_average"
	for cell: String in ["p1_w1", "p3_w0"]:
		var rig := _rig(body)
		var record := {
			"id": "t.hood." + cell,
			"body": body,
			"sex": "m",
			"status": "burgher",
			"cloth": [0.4, 0.4, 0.4],
			"under": [0.2, 0.2, 0.2],
			"wear": ["hood@" + cell],
		}
		CitizenWardrobe.dress(rig, record)
		var shown := 0
		var hidden := 0
		for node: Node in rig.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			if mesh.mesh == null or not String(mesh.name).contains("hood"):
				continue
			for s in mesh.mesh.get_surface_count():
				var source := mesh.mesh.surface_get_material(s)
				if source == null or not source.resource_name.ends_with(CitizenWardrobe.HOOD_DAGS):
					continue
				if mesh.get_surface_override_material(s) == CitizenWardrobe.hidden_material():
					hidden += 1
				else:
					shown += 1
		if cell == "p3_w0":
			assert_true(shown > 0 and hidden == 0, "p3 hood shows its dags")
		else:
			assert_true(hidden > 0 and shown == 0, "p1 hood hides its dags")
		rig.queue_free()


## R-2022: surcoat and Order mantle grades and wear follow the variant cell, not the purse.
## Women's headwear (task R-2029): every head layer mounts on the bodies that carry it and its
## linen takes the grade of its wearer's purse: coarse tow (w1 yellowed, w2 sweat-stained) for the
## poor, bleached fine linen for everyone better off.
func test_womens_headwear_mounts_with_linen_grades() -> void:
	var cases := [
		[
			"citizen_f_adult_sturdy_d",
			"head_cloth",
			"servant",
			["linen_coarse_w1", "linen_coarse_w2"]
		],
		["citizen_f_elder_thin", "headscarf", "servant", ["linen_coarse_w1", "linen_coarse_w2"]],
		["citizen_f_adult_heavy_b", "veil_over", "master_craftsman", ["linen_fine"]],
		["citizen_f_elder_heavy", "wimple", "patrician", ["linen_fine"]],
		["citizen_f_adult_average_c", "barbette", "patrician", ["linen_fine"]],
	]
	for case: Array in cases:
		var rig := _rig(case[0])
		var record := {
			"id": "t.women." + String(case[1]),
			"body": case[0],
			"sex": "f",
			"status": case[2],
			"cloth": [0.3, 0.3, 0.3],
			"under": [0.2, 0.2, 0.2],
			"wear": [String(case[1]) + "@p2_w1"],
		}
		CitizenWardrobe.dress(rig, record)
		assert_true(
			rig.has_garment(StringName("wear_" + String(case[1]))), "%s on %s" % [case[1], case[0]]
		)
		var grades := {}
		for mesh: MeshInstance3D in _layer_meshes(rig, case[1]):
			for surface in mesh.mesh.get_surface_count():
				var grade := _grade(mesh.get_active_material(surface))
				if not grade.is_empty():
					grades[grade] = true
		assert_false(grades.is_empty(), "%s has a woven linen surface" % case[1])
		for grade: String in grades:
			assert_true(grade in case[3], "%s on a %s is %s" % [case[1], case[2], grade])
		rig.queue_free()


func test_fine_wool_grade_by_prestige() -> void:
	var crown := {"wear": ["surcoat@p2_w1"]}
	var knight := {"wear": ["surcoat@p3_w0"]}
	var brother := {"wear": ["surcoat@p3_w0", "order_mantle@p3_w0"]}
	assert_eq(CitizenWardrobe.fine_grade("surcoat", "p2_w1", crown), "broadcloth", "crown issue")
	assert_eq(CitizenWardrobe.fine_grade("surcoat", "p3_w0", knight), "scarlet", "a knight's own")
	assert_eq(CitizenWardrobe.fine_grade("surcoat", "p3_w0", brother), "broadcloth", "Order plain")
	assert_eq(CitizenWardrobe.fine_grade("order_mantle", "p3_w0", brother), "broadcloth", "mantle")


func test_fine_wool_wear_ignores_poverty_and_trade() -> void:
	# A poor soldier (patched, sun-pale own wool) and a butcher's stains must not reach the issue.
	var wear := CitizenWardrobe.wear_of({"id": "x", "status": "soldier", "trade": "butcher"})
	for level in 3:
		var cell := CitizenWardrobe.fine_wool_wear(wear, level)
		assert_eq(cell[0].w, 0.0, "no stains on w%d" % level)
		assert_eq(cell[0].y, 0.0, "no soot on w%d" % level)
	assert_eq(CitizenWardrobe.fine_wool_wear(wear, 0)[1].x, 0.0, "w0 fresh: no patches")
	assert_eq(CitizenWardrobe.fine_wool_wear(wear, 1)[1].x, 0.0, "w1 travel-worn: no patches")
	assert_true(CitizenWardrobe.fine_wool_wear(wear, 1)[1].y > 0.0, "w1 sun-faded")
	assert_true(CitizenWardrobe.fine_wool_wear(wear, 2)[1].x > 0.0, "w2 patched")
	var muddy := CitizenWardrobe.fine_wool_wear(wear, 1)[0].x
	assert_true(muddy > CitizenWardrobe.fine_wool_wear(wear, 0)[0].x, "w1 muddier hem than w0")


func test_battered_surcoat_tears_its_hem() -> void:
	for cell: String in ["p2_w1", "p2_w2"]:
		var rig := _rig()
		var record := {
			"id": "t.crown",
			"body": BODY,
			"status": "soldier",
			"cloth": [0.3, 0.3, 0.28],
			"under": [0.2, 0.2, 0.2],
			"wear": ["gambeson@" + cell, "mail_haubergeon@" + cell, "surcoat@" + cell],
			"wear_dye": {"surcoat": [0.58, 0.11, 0.09]},
		}
		CitizenWardrobe.dress(rig, record)
		var meshes := _layer_meshes(rig, "surcoat")
		assert_false(meshes.is_empty(), "surcoat mounted")
		var mesh := meshes[0]
		var material := mesh.get_surface_override_material(0) as ShaderMaterial
		assert_true(material != null, "surcoat woven")
		var torn := material.shader.code.contains("#define TORN_HEM")
		assert_eq(torn, cell.ends_with("w2"), "%s: torn hem shader only on w2" % cell)
		var format: int = mesh.mesh.surface_get_format(0)
		assert_true(format & Mesh.ARRAY_FORMAT_TEX_UV2 != 0, "surcoat carries its HemRise UV2")
		var dye: Color = mesh.get_instance_shader_parameter(&"dye_outer")
		assert_true(dye.a > 0.5 and dye.r > dye.g * 2.0, "%s: red crown dye" % cell)
		rig.queue_free()


## R-1994: the city has more per-instance cloth, plant and water uniforms than Godot's default
## global buffer (65536); overflowing instances read other residents' dyes and stains.
func test_instance_uniform_buffer_fits_the_city() -> void:
	var key := "rendering/limits/global_shader_variables/buffer_size"
	var size := int(ProjectSettings.get_setting(key, 0))
	assert_true(size >= 262144, "instance uniform buffer raised (%d)" % size)
