extends "res://tests/godot/test_case.gd"

## ADR 0022: realistic MPFB-based Kalev keeps the shared rig contract and a
## fully modular, historically grounded wardrobe.

const LIVE_KALEV := preload("res://assets/characters/kalev/kalev.tscn")
const DIR := "res://assets/characters/realistic/kalev/"
const REGIONS: Array[String] = [
	"Anatomy_Head",
	"Anatomy_Torso",
	"Anatomy_Arms",
	"Anatomy_Forearms",
	"Anatomy_Hands",
	"Anatomy_Legs",
	"Anatomy_Calves",
	"Anatomy_Feet",
	"Clothing_Braies",
	"Hair_Scalp",
	"Hair_Beard",
]
const GARMENTS: Array[String] = [
	"linen_shirt",
	"work_tunic",
	"wool_tunic",
	"gambeson",
	"mail_haubergeon",
	"smith_apron",
	"hose",
	"boots",
	"hood",
	"kettle_hat",
]

var rig: SharedCharacterRig


func before_each() -> void:
	super.before_each()
	rig = LIVE_KALEV.instantiate() as SharedCharacterRig
	(Engine.get_main_loop() as SceneTree).root.add_child(rig)


func after_each() -> void:
	SharedCharacterRig._detach_render_geometry(rig)
	rig.free()
	super.after_each()


func test_body_keeps_shared_rig_and_every_clip() -> void:
	assert_eq(rig.validation_errors(), [])
	assert_eq(rig.skeleton().get_bone_count(), 41)
	assert_true(rig.skeleton().find_bone("handslot.r") >= 0)
	assert_eq(rig.animation_player().get_animation_list().size(), 76)
	for motion: StringName in [&"idle", &"walk", &"run", &"hammer_attack", &"guard"]:
		assert_true(rig.play_animation(motion, 0.0), "missing %s" % motion)


func test_body_exposes_every_wardrobe_region() -> void:
	for region: String in REGIONS:
		assert_true(_mesh(region) != null, "missing body region %s" % region)


func test_every_garment_equips_hides_its_regions_and_restores_them() -> void:
	for garment: String in GARMENTS:
		var wearable := load(DIR + garment + ".tres") as CharacterWearable
		assert_true(wearable != null, garment)
		assert_eq(wearable.fitted_body, "kalev")
		rig.unequip_wearable(StringName(wearable.slot))
		var visible_before := {}
		for region: StringName in wearable.covered_meshes:
			visible_before[region] = _mesh(region).visible
		assert_true(rig.equip_wearable(wearable), "%s must fit Kalev" % garment)
		for region: StringName in wearable.covered_meshes:
			assert_false(_mesh(region).visible, "%s must hide %s" % [garment, region])
		rig.unequip_wearable(StringName(wearable.slot))
		for region: StringName in wearable.covered_meshes:
			assert_eq(
				_mesh(region).visible,
				visible_before[region],
				"%s must restore %s" % [garment, region]
			)


func test_named_outfits_equip_completely() -> void:
	var outfits: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "outfits.json"))
	for outfit: String in ["forge", "street", "travel", "armed"]:
		for slot: String in CharacterWardrobe.SLOTS:
			rig.unequip_wearable(StringName(slot))
		for garment: String in outfits[outfit]:
			assert_true(
				rig.equip_wearable(load(DIR + garment + ".tres")), "%s: %s" % [outfit, garment]
			)
		assert_true(rig.play_animation(&"walk", 0.0))


func test_wearables_fitted_to_other_bodies_are_rejected() -> void:
	var foreign := load("res://assets/characters/kalev_fresh/boots.tres") as CharacterWearable
	assert_false(rig.equip_wearable(foreign))
	assert_eq(rig.equipped_wearable(&"feet").stable_id, &"wearable.kalev.boots")


func test_fur_shells_read_strand_length_from_vertex_colour() -> void:
	for name: String in ["Hair_Beard"]:
		var mesh := _mesh(name)
		var material := mesh.get_active_material(0) as BaseMaterial3D
		assert_true(
			material.vertex_color_use_as_albedo, "%s needs vertex colour for strand cut-off" % name
		)
		assert_eq(material.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR)
		assert_almost_eq(material.alpha_scissor_threshold, 0.5, 0.001)


func _mesh(mesh_name: String) -> MeshInstance3D:
	for found: Node in rig.find_children("*", "MeshInstance3D", true, false):
		if String(found.name) == mesh_name:
			return found as MeshInstance3D
	return null
