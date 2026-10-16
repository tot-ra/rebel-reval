extends "res://tests/godot/test_case.gd"

## Scrips and back sacks by variant cell (task R-2034, docs/SYSTEMS/CITIZEN_WARDROBE.md):
## the cell picks each part's leather or linen; the scallop shows only on pilgrims.

const CitizenBags := preload("res://scripts/city/citizen_bags.gd")
const BODY := "citizen_m_adult_average"


func _source(name: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = name
	return material


func _rig() -> SharedCharacterRig:
	var scene := load("res://assets/characters/variants/%s.tscn" % BODY) as PackedScene
	var rig := scene.instantiate() as SharedCharacterRig
	(Engine.get_main_loop() as SceneTree).root.add_child(rig)
	return rig


## Material name suffix -> the surface override on the rig's mounted `layer` mesh.
func _layer_materials(rig: SharedCharacterRig, layer: String) -> Dictionary:
	var found := {}
	for child: Node in rig.skeleton().get_children():
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null:
			continue
		if not String(mesh_instance.name).begins_with("Garment_wear_%s_" % layer):
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.mesh.surface_get_material(surface)
			var key := String(source.resource_name).trim_prefix(BODY)
			found[key] = mesh_instance.get_surface_override_material(surface)
	return found


func _grade_of(material: Material) -> String:
	var shader := material as ShaderMaterial
	if shader == null:
		return ""
	var albedo := shader.get_shader_parameter(&"albedo_tex") as Texture2D
	return albedo.resource_path.get_file().get_slice("_albedo", 0) if albedo != null else ""


func test_cell_picks_the_scrip_leather() -> void:
	var pouch := _source(BODY + "_satchel")
	var strap := _source(BODY + "_satchel_strap")
	var clerk := {"id": "cit.test.clerk", "trade": "clerk"}
	assert_eq(String(CitizenBags.surface_rule(pouch, "p2_w0", clerk)["grade"]), "leather_tooled")
	assert_eq(String(CitizenBags.surface_rule(pouch, "p3_w1", clerk)["grade"]), "leather_tooled")
	assert_eq(String(CitizenBags.surface_rule(strap, "p2_w0", clerk)["grade"]), "leather")
	var seen := {}
	for i in 40:
		var pedlar := {"id": "cit.test.pedlar.%d" % i, "trade": "pedlar"}
		var rule := CitizenBags.surface_rule(pouch, "p1_w2", pedlar)
		seen[rule["grade"]] = true
		assert_eq(int(rule["slot"]), 0, "an undyed pouch takes no leather dye")
		assert_eq(String(CitizenBags.surface_rule(strap, "p1_w2", pedlar)["grade"]), "rawhide")
	assert_eq(seen.keys().size(), 2, "the poor carry both rawhide and linen scrips")
	assert_true(seen.has("rawhide") and seen.has("linen_coarse"))
	var pilgrim := {"id": "cit.test.pilgrim", "trade": "pilgrim"}
	assert_eq(String(CitizenBags.surface_rule(pouch, "p1_w2", pilgrim)["grade"]), "leather")


func test_scallop_only_on_pilgrims() -> void:
	var badge := _source(BODY + "_satchel_badge")
	var clerk := CitizenBags.surface_rule(badge, "p2_w1", {"id": "a", "trade": "clerk"})
	assert_eq(clerk["keep"], CitizenBags.hidden())
	var pilgrim := CitizenBags.surface_rule(badge, "p1_w2", {"id": "b", "trade": "pilgrim"})
	var pewter := pilgrim["keep"] as BaseMaterial3D
	assert_true(pewter != null, "pilgrim badge keeps a pewter material")
	assert_true(pewter.has_meta(&"variant_wear"), "marked so the w2 stand-in finish does not rust it")


func test_dressed_scrip_and_sack() -> void:
	var rig := _rig()
	var record := {
		"id": "cit.test.porter", "body": BODY, "trade": "porter", "status": "labourer",
		"wear": ["back_sack@p1_w2"],
	}
	CitizenWardrobe.dress(rig, record)
	var sack := _layer_materials(rig, "back_sack")
	assert_eq(_grade_of(sack.get("_back_sack")), "linen_coarse")
	assert_eq(_grade_of(sack.get("_back_sack_rope")), "linen_coarse")
	rig.queue_free()
	for trade: String in ["merchant", "pilgrim"]:
		rig = _rig()
		CitizenWardrobe.dress(rig, {
			"id": "cit.test." + trade, "body": BODY, "trade": trade, "status": "burgher_merchant",
			"wear": ["satchel@p3_w0"], "wear_dye": {"satchel": [0.42, 0.27, 0.15]},
		})
		var scrip := _layer_materials(rig, "satchel")
		for part: String in ["_satchel", "_satchel_strap", "_satchel_toggle", "_satchel_badge"]:
			assert_true(scrip.has(part), "%s scrip has its %s surface" % [trade, part])
		var pilgrim := trade == "pilgrim"
		assert_eq(_grade_of(scrip.get("_satchel")), "leather" if pilgrim else "leather_tooled")
		assert_eq(scrip.get("_satchel_badge") == CitizenBags.hidden(), not pilgrim)
		rig.queue_free()
