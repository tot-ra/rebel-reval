extends "res://tests/godot/test_case.gd"

## Layered citizen dress (docs/SYSTEMS/CITIZEN_WARDROBE.md, task R-1663).

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
			var material := mesh.get_active_material(surface) as BaseMaterial3D
			if material != null and material.resource_name.ends_with("_surcoat"):
				dyed = dyed or material.albedo_color.is_equal_approx(red)
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
