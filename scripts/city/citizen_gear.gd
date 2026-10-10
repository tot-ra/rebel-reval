class_name CitizenGear
extends RefCounted

## Duty gear for census residents on the gate watch, town patrols and the wall
## walk (docs/SYSTEMS/GATE_GARRISONS.md). They wear their own clothes (the blank
## citizen body, dyed for the crown's red or the town's colours); what marks the
## post is a kettle hat on the head and a spear or sword in the hand. The kit id
## comes from `duty.kit` in content/world/reval_city/citizens.json.

const KETTLE_HAT := preload("res://assets/characters/realistic/watchman/kettle_hat/kettle_hat.glb")
const SPEAR := preload("res://assets/characters/shared/spear.tscn")
const SWORD := preload("res://assets/characters/shared/sword.tscn")

## Kit -> {hat, hand}. The gatekeeper carries nothing: his keys are his badge.
const KITS := {
	"watch": {"hat": true, "hand": &"spear"},
	"crown": {"hat": true, "hand": &"spear"},
	"sergeant": {"hat": true, "hand": &"sword"},
	"keeper": {"hat": false, "hand": &""},
}
## Spear held upright at the side, butt on the ground. The hand slot's X axis points
## down, so the spear's shaft (its Y) is turned onto hand -X and the grip sits a third
## of the way up; scaled to a 1.8 m shaft-and-head. Measured with the idle pose.
static var _spear_held := Transform3D(
	Basis(Vector3.BACK, PI * 0.5).scaled(Vector3(1.25, 1.25, 1.25)), Vector3(0.415, 0.0, 0.0)
)


## Mounts the kit of `record["duty"]` on `rig`; a resident off duty (or any
## civilian) is left untouched. Safe to call twice.
static func arm(rig: SharedCharacterRig, record: Dictionary) -> void:
	var duty: Dictionary = record.get("duty", {})
	if duty.is_empty() or not KITS.has(duty.get("kit", "")):
		return
	var kit: Dictionary = KITS[duty["kit"]]
	# The hat is a skinned garment authored on the shared skeleton: it follows the head bone.
	if kit["hat"]:
		rig.equip_garment(&"duty_hat", KETTLE_HAT)
	match kit["hand"]:
		&"spear":
			var spear := rig.equip(&"right_hand", SPEAR)
			if spear != null:
				spear.transform = _spear_held
		&"sword":
			rig.equip(&"right_hand", SWORD)
