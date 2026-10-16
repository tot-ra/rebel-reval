class_name CitizenGear
extends RefCounted

## Duty gear for census residents on the gate watch, town patrols and the wall
## walk (docs/SYSTEMS/GATE_GARRISONS.md). They wear their own clothes (the blank
## citizen body, dyed for the crown's red or the town's colours); what marks the
## post is a kettle hat on the head and a spear or sword in the hand. The kit id
## comes from `duty.kit` in content/world/reval_city/citizens.json.

const KETTLE_HAT := preload("res://assets/characters/realistic/watchman/kettle_hat/kettle_hat.glb")
## Watch spear variant from the equipment pipeline (docs/SYSTEMS/EQUIPMENT_VARIANTS.md,
## R-2003): Meshy leaf-blade head on a 2 m ash shaft, origin at the grip, shaft along +Y.
## The legacy primitive assets/characters/shared/spear.tscn stays until R-2035.
const SPEAR := preload("res://assets/props/weapons/spear/variants/spear_p1_w1.glb")
const SWORD := preload("res://assets/characters/shared/sword.tscn")
## Variant folders (EQUIPMENT_VARIANTS.md): `<dir>/<family>_<cell>.glb`. The resident's
## `gear_variant` cell picks the file; a missing cell falls back to SPEAR or SWORD above.
const SPEAR_DIR := "res://assets/props/weapons/spear/variants"
const SWORD_DIR := "res://assets/props/weapons/sword/variants"
const EquipmentVariant := preload("res://scripts/city/equipment_variant.gd")

## Kit -> {hat, hand}. The gatekeeper carries nothing: his keys are his badge.
const KITS := {
	"watch": {"hat": true, "hand": &"spear"},
	"crown": {"hat": true, "hand": &"spear"},
	"sergeant": {"hat": true, "hand": &"sword"},
	"keeper": {"hat": false, "hand": &""},
}
## Spear held upright at the side, butt near the ground. The hand slot's X axis points
## down, so the spear's shaft (its Y) is turned onto hand -X; the GLB origin is already
## the grip (socket_grip), so no offset or scale. Real size, 2.33 m overall.
static var _spear_held := Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3.ZERO)

## Lantern hanging from the left fist by its bail. The left hand slot mirrors the right
## one, so the spear's turn would stand the lantern on its head and bury the horn body in
## the sleeve (only its light showed): turn the other way. WatchLantern then keeps
## itself plumb while lit, so this only matters for the unlit lantern.
static var _lantern_held := Transform3D(Basis(Vector3.BACK, -PI * 0.5), Vector3(-0.05, 0.0, 0.0))

static var _lantern: PackedScene

## Shield strapped to the left forearm, face outward. Measured with the idle pose
## (tools/capture_citizen_wardrobe.gd, tools/capture_shields.gd). The modelled shields
## (R-2013) face +Z with the enarmes behind, so the last turn about Y puts the painted face
## away from the body; the old flat board was symmetric and hid that.
static var _shield_held := Transform3D(
	(Basis(Vector3.BACK, PI * 0.5) * Basis(Vector3.UP, PI * 0.5)).scaled(Vector3(0.9, 0.9, 0.9)),
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
	var cell := gear_cell(record)
	match kit["hand"]:
		&"spear":
			var spear := _equip_variant(rig, SPEAR_DIR, "spear", cell, SPEAR)
			if spear != null:
				spear.transform = _spear_held
		&"sword":
			_equip_variant(rig, SWORD_DIR, "sword", cell, SWORD)
	_carry_lantern(rig, duty, kit)


## Prestige and wear cell of the resident's hand gear (`gear_variant`), base cell if unset.
static func gear_cell(record: Dictionary) -> String:
	var cell := String(record.get("gear_variant", ""))
	return cell if EquipmentVariant.is_cell(cell) else EquipmentVariant.BASE_CELL


## Mounts `<family>_<cell>` on the right hand, or the base item with a stand-in wear
## finish when that variant is not shipped. Returns the mounted node.
static func _equip_variant(
	rig: SharedCharacterRig, dir: String, family: String, cell: String, base: PackedScene
) -> Node3D:
	var own := EquipmentVariant.variant_scene(dir, family, cell)
	var item := rig.equip(&"right_hand", own if own != null else base)
	if item != null:
		item.set_meta(&"variant", "%s_%s" % [family, cell])
		if own == null:
			EquipmentVariant.finish(item, cell)
	return item


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
	var shield := rig.equip(&"left_hand", CitizenShield.scene(kind, field, gear_cell(record)))
	if shield != null:
		shield.transform = _shield_held
