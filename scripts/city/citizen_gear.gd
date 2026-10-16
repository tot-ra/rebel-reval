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

## Lantern hanging from the left fist by its bail: the hand slot's X points down, so
## the lantern's up (Y) is turned onto hand -X, the same turn as the spear.
static var _lantern_held := Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.05, 0.0, 0.0))

static var _lantern: PackedScene

## Shield strapped to the left forearm, face outward. Measured with the idle pose
## (tools/capture_citizen_wardrobe.gd).
static var _shield_held := Transform3D(
	(Basis(Vector3.BACK, PI * 0.5) * Basis(Vector3.UP, -PI * 0.5)).scaled(Vector3(0.8, 0.8, 0.8)),
	Vector3(0.08, 0.0, 0.06)
)


## Dresses `record`'s wardrobe layers, then mounts the kit of `record["duty"]`
## (hat fallback and weapon); a civilian gets only the layers and, for an armed
## knight or man-at-arms, a shield. Safe to call twice.
static func arm(rig: SharedCharacterRig, record: Dictionary) -> void:
	# Layered dress first (docs/SYSTEMS/CITIZEN_WARDROBE.md): duty kits there add the
	# aketon, mail, surcoat and a kettle hat fitted to this very body.
	CitizenWardrobe.dress(rig, record)
	_carry_shield(rig, record)
	var duty: Dictionary = record.get("duty", {})
	if duty.is_empty() or not KITS.has(duty.get("kit", "")):
		return
	var kit: Dictionary = KITS[duty["kit"]]
	# Fallback hat (the watchman's, skinned to the shared skeleton) for a body
	# without its own fitted kettle hat layer.
	if kit["hat"] and not rig.has_garment(&"wear_kettle_hat"):
		rig.equip_garment(&"duty_hat", KETTLE_HAT)
	match kit["hand"]:
		&"spear":
			var spear := rig.equip(&"right_hand", SPEAR)
			if spear != null:
				spear.transform = _spear_held
		&"sword":
			rig.equip(&"right_hand", SWORD)
	_carry_lantern(rig, duty, kit)


## The night shift carries a horn lantern in the free left hand; it lights itself
## after dusk (WatchLantern). A shield-bearer keeps his shield instead.
static func _carry_lantern(rig: SharedCharacterRig, duty: Dictionary, kit: Dictionary) -> void:
	if String(duty.get("shift", "")) != "night" or kit["hand"] == &"":
		return
	if rig.equipped(&"left_hand") != null:
		return
	var lantern := rig.equip(&"left_hand", _lantern_scene())
	if lantern != null:
		lantern.transform = _lantern_held



static func _lantern_scene() -> PackedScene:
	if _lantern == null:
		var node := WatchLantern.new()
		_lantern = PackedScene.new()
		_lantern.pack(node)
		node.free()
	return _lantern


## Left-hand shield of an armed resident (`shield` kind from the wardrobe rules). A "field"
## shield takes the colour of the coat of plates or surcoat the knight wears.
static func _carry_shield(rig: SharedCharacterRig, record: Dictionary) -> void:
	var kind := String(record.get("shield", ""))
	if kind.is_empty() or rig.equipped(&"left_hand") != null:
		return
	var field := Color(0.4, 0.4, 0.4)
	var dyes: Dictionary = record.get("wear_dye", {})
	for layer: String in ["coat_of_plates", "surcoat"]:
		if dyes.has(layer):
			var rgb: Array = dyes[layer]
			field = Color(float(rgb[0]), float(rgb[1]), float(rgb[2]))
			break
	var shield := rig.equip(&"left_hand", CitizenShield.scene(kind, field))
	if shield != null:
		shield.transform = _shield_held
