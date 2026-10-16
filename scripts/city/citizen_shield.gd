class_name CitizenShield
extends RefCounted

## Shields of armed census residents (docs/SYSTEMS/CITIZEN_WARDROBE.md, WD-4), modelled GLBs
## from tools/assets/equipment/build_shields.py (R-2013, EQ-11). A shield is a plain prop on
## the left hand slot, not a skinned layer. Kinds come from the wardrobe rules (`shield` in
## content/world/reval_city/citizens.json):
##   order - white field with the Order's black cross (p3)
##   crown - plain red, the Danish crown's colour, no invented arms (p2)
##   field - the knight's own surcoat colour: a pale painted board tinted at runtime (p3)
##   plain - scuffed lime wood with an iron boss (p1)
##   buckler, pavise - round burgher sidearm and the wall crossbowman's standing shield
## Files `<dir>/<family>_<cell>.glb` (heater families `heater_<kind>`); the bearer's
## `gear_variant` cell picks one, else the nearest shipped cell of that kind (wear first,
## then prestige). Heater 0.46 x 0.62 m, face toward +Z, origin mid-board.

const VARIANT_DIRS := {
	"heater": "res://assets/props/weapons/heater_shield/variants",
	"buckler": "res://assets/props/weapons/buckler/variants",
	"pavise": "res://assets/props/weapons/pavise/variants",
}
## Shipped cells per family (file stem `<family>_<cell>`), newest wear first.
const SHIPPED := {
	"heater_order": ["p3_w0", "p3_w1"],
	"heater_crown": ["p2_w1"],
	"heater_field": ["p3_w1"],
	"heater_plain": ["p1_w0", "p1_w2"],
	"buckler": ["p1_w1", "p2_w1"],
	"pavise": ["p1_w1"],
}
const EquipmentVariant := preload("res://scripts/city/equipment_variant.gd")

static var _cache: Dictionary = {}


## PackedScene of one shield; `field` is only read for kind "field". `cell` is the
## bearer's prestige and wear cell.
static func scene(
	kind: String, field: Color = Color(0.4, 0.4, 0.4), cell: String = EquipmentVariant.BASE_CELL
) -> PackedScene:
	var family := _family(kind)
	var chosen := _nearest(family, cell)
	var key := "%s:%s:%s" % [family, chosen, field.to_html(false) if kind == "field" else ""]
	if not _cache.has(key):
		var source := load("%s/%s_%s.glb" % [VARIANT_DIRS[_dir_key(family)], family, chosen]) as PackedScene
		var root := source.instantiate() as Node3D
		root.name = "Shield_" + kind
		if kind == "field":
			_tint_face(root, field)
		var packed := PackedScene.new()
		packed.pack(root)
		root.free()
		_cache[key] = packed
	return _cache[key]


static func _family(kind: String) -> String:
	return kind if kind in ["buckler", "pavise"] else "heater_" + (kind if kind in ["order", "crown", "field"] else "plain")


static func _dir_key(family: String) -> String:
	return "heater" if family.begins_with("heater_") else family


## The shipped cell of `family` nearest to `cell`: smallest wear gap, then prestige gap,
## newer wear on a tie.
static func _nearest(family: String, cell: String) -> String:
	var shipped: Array = SHIPPED[family]
	var want_wear := EquipmentVariant.wear(cell)
	var want_prestige := EquipmentVariant.prestige(cell)
	var best: String = shipped[0]
	var best_score := 1 << 30
	for candidate: String in shipped:
		var wear_gap := absi(EquipmentVariant.wear(candidate) - want_wear)
		var score := (
			wear_gap * 100
			+ absi(EquipmentVariant.prestige(candidate) - want_prestige) * 10
			+ (1 if EquipmentVariant.wear(candidate) > want_wear else 0)
		)
		if score < best_score:
			best_score = score
			best = candidate
	return best


## The painted face (material `shield_face`) of a field shield takes the knight's colour: the
## texture is a pale board, so the albedo colour multiplies it into that surcoat tone.
static func _tint_face(root: Node, field: Color) -> void:
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := (node as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var material := mesh.surface_get_material(i) as StandardMaterial3D
			if material != null and material.resource_name == "shield_face":
				var tinted := material.duplicate() as StandardMaterial3D
				tinted.albedo_color = field
				(node as MeshInstance3D).set_surface_override_material(i, tinted)
