extends "res://tests/godot/test_case.gd"

## R-1868: Aita's body is the MPFB build conformed to a Meshy scan
## (agents/rebel-art/skills/meshy-human, route A) and dressed by
## tools/assets/meshy_human/fit_wearables_to_conform.py. It must keep the MPFB
## rig, clip and face contract and still wear her whole work outfit.

const LIVE_AITA := preload("res://assets/characters/variants/aita.tscn")
const REGIONS: Array[String] = [
	"Anatomy_Head",
	"Anatomy_Head_Eyes",
	"Anatomy_Head_Lashes",
	"Anatomy_Head_Teeth",
	"Anatomy_Torso",
	"Anatomy_Arms",
	"Anatomy_Forearms",
	"Anatomy_Hands",
	"Anatomy_Legs",
	"Anatomy_Calves",
	"Anatomy_Feet",
	"Clothing_Braies",
	"Hair_Scalp",
]

var rig: SharedCharacterRig


func before_each() -> void:
	super.before_each()
	rig = LIVE_AITA.instantiate() as SharedCharacterRig
	(Engine.get_main_loop() as SceneTree).root.add_child(rig)


func after_each() -> void:
	SharedCharacterRig._detach_render_geometry(rig)
	rig.free()
	super.after_each()


func test_body_keeps_shared_rig_and_every_clip() -> void:
	assert_eq(rig.validation_errors(), [])
	assert_eq(rig.skeleton().get_bone_count(), 71)
	# The GLB's own library; combat_roll_clip.gd adds its roll clips in a second one.
	assert_eq(rig.animation_player().get_animation_library(&"").get_animation_list().size(), 76)
	for motion: StringName in [&"idle", &"walk", &"run", &"hammer_attack", &"guard"]:
		assert_true(rig.play_animation(motion, 0.0), "missing %s" % motion)


func test_body_keeps_mpfb_mesh_set() -> void:
	# Wearables hide regions by these names; Hair_Scalp must exist or the
	# headscarf refuses to equip.
	for region: String in REGIONS:
		assert_true(_mesh(region) != null, "missing %s" % region)


func test_default_outfit_equips_and_covers_the_body() -> void:
	for slot: StringName in [&"torso", &"outerwear", &"head", &"feet"]:
		assert_true(rig.equipped_wearable(slot) != null, "%s wearable did not equip" % slot)
	for hidden: String in ["Anatomy_Torso", "Anatomy_Arms", "Anatomy_Legs", "Anatomy_Feet", "Hair_Scalp"]:
		assert_false(_mesh(hidden).visible, "%s must be covered by the outfit" % hidden)
	assert_true(_mesh("Anatomy_Head").visible)


func test_face_blinks_and_talks_through_blend_shapes() -> void:
	for shape: StringName in [&"blink", &"jaw_open", &"smile", &"brow_up", &"frown", &"pucker"]:
		assert_true(_mesh("Anatomy_Head").find_blend_shape_by_name(shape) >= 0, "missing %s" % shape)
	assert_true(_mesh("Anatomy_Head_Lashes").find_blend_shape_by_name(&"blink") >= 0,
		"lashes must follow the eyelids")
	var realistic := rig as Node
	var blinked := false
	for _frame: int in 400:
		realistic.call("_process", 1.0 / 60.0)
		blinked = blinked or float(realistic.call("face_shape_value", &"blink")) > 0.5
	assert_true(blinked, "Aita must blink within a few seconds")
	realistic.call("on_dialogue_speaker", &"char.aita", 60)
	assert_true(bool(realistic.call("is_talking")), "Aita talks while her line is read")
	var opened := false
	for _frame: int in 60:
		realistic.call("_process", 1.0 / 60.0)
		opened = opened or float(realistic.call("face_shape_value", &"jaw_open")) > 0.15
	assert_true(opened, "the jaw moves while talking")


func _mesh(mesh_name: String) -> MeshInstance3D:
	for found: Node in rig.find_children("*", "MeshInstance3D", true, false):
		if String(found.name) == mesh_name:
			return found as MeshInstance3D
	return null
