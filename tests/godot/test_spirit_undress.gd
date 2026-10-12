extends "res://tests/godot/test_case.gd"

## Spirit sight swaps adult census bodies for their nude twin and never touches minors
## (docs/SYSTEMS/SPIRIT_SIGHT.md).

const ADULT_BODIES := [
	"citizen_m_adult_average", "citizen_m_adult_thin_b", "citizen_m_elder_heavy",
	"citizen_f_adult_average", "citizen_f_adult_heavy_b", "citizen_f_adult_thin_d", "citizen_f_elder_thin",
]


func _rig(body: String) -> SharedCharacterRig:
	var scene := load("res://assets/characters/variants/%s.tscn" % body) as PackedScene
	var rig := scene.instantiate() as SharedCharacterRig
	(Engine.get_main_loop() as SceneTree).root.add_child(rig)
	return rig


## Names of the visible skinned meshes on the rig's skeleton.
func _visible_meshes(rig: SharedCharacterRig) -> Array[String]:
	var names: Array[String] = []
	for child: Node in rig.skeleton().get_children():
		var mesh_instance := child as MeshInstance3D
		if mesh_instance != null and mesh_instance.skin != null and mesh_instance.visible \
				and not mesh_instance.is_queued_for_deletion():
			names.append(String(mesh_instance.name))
	return names


func test_every_adult_body_has_a_nude_twin() -> void:
	for body in ADULT_BODIES:
		var rig := _rig(body)
		assert_true(SpiritUndress.eligible(rig), "%s ships layers/nude.glb" % body)
		rig.queue_free()


func test_adult_is_shown_nude_and_dressed_again() -> void:
	var rig := _rig("citizen_m_adult_average")
	rig.equip_garment(&"wear_hood", load("res://assets/characters/realistic/citizen_m_adult_average/layers/hood.glb"))
	var dressed := _visible_meshes(rig)
	assert_true(dressed.has("Anatomy_CrowdBody"), "baked body is drawn before sight")
	SpiritUndress.undress(rig)
	SpiritUndress.undress(rig)  # idempotent
	var nude := _visible_meshes(rig)
	assert_eq(nude.size(), 1, "only the nude twin is drawn in sight: %s" % [nude])
	assert_true(nude[0].ends_with("Layer_nude"), "the drawn mesh is the nude layer")
	var materials: Array[String] = []
	var layer := rig.skeleton().get_node(nude[0]) as MeshInstance3D
	for surface in layer.mesh.get_surface_count():
		materials.append(layer.mesh.surface_get_material(surface).resource_name)
	for material_name in materials:
		assert_false(material_name.contains("tunic") or material_name.contains("hose") \
				or material_name.contains("braies"), "no cloth on the nude layer: %s" % material_name)
	SpiritUndress.restore(rig)
	assert_false(SpiritUndress.is_undressed(rig))
	assert_eq(_visible_meshes(rig), dressed, "the same meshes are drawn after sight")
	rig.queue_free()


func test_minors_and_hero_stay_dressed() -> void:
	for body in ["citizen_m_child_average", "citizen_f_child_average", "apprentice", "aita"]:
		var rig := _rig(body)
		var before := _visible_meshes(rig)
		assert_false(SpiritUndress.eligible(rig), "%s is not undressed" % body)
		SpiritUndress.undress(rig)
		assert_eq(_visible_meshes(rig), before, "%s keeps its clothes" % body)
		rig.queue_free()
