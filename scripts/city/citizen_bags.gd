extends RefCounted

## Bag layers of the census residents (task R-2034, docs/SYSTEMS/CITIZEN_WARDROBE.md):
## the scrip (`satchel`) and the back sack (`back_sack`). One fitted layer per body
## carries every part on its own material (garments.py `satchel`, `back_sack`); the
## resident's variant cell picks what each part is made of, so a clerk's tooled scrip
## and a pedlar's rawhide one are the same mesh:
## - scrip pouch and flap: p1 coarse linen or rawhide (by id), p2 and p3 tooled leather;
##   pilgrims carry plain soft leather whatever their cell, with the pewter scallop shown;
## - scrip strap and toggle tab: p1 rawhide, else leather;
## - back sack and its cord: coarse linen sacking.
## Wear (w0..w2) stays the layer cloth wear of CitizenWardrobe (patches on w2).
## Preloaded by CitizenWardrobe, no class_name.

const EquipmentVariant := preload("res://scripts/city/equipment_variant.gd")

const LAYERS := ["satchel", "back_sack"]
const PILGRIM := "pilgrim"
## Material key suffix of each part (garments.py finish keys).
const POUCH := "_satchel"
const STRAP := "_satchel_strap"
const BADGE := "_satchel_badge"
const SACK := "_back_sack"
const CORD := "_back_sack_rope"
## Colour (sRGB) of an undyed grade on a bag; it replaces the baked leather brown,
## and the pouch then takes no dye (the record's tan or dark is a leather dye).
const UNDYED := {
	"linen_coarse": Color(0.66, 0.6, 0.48),
	"rawhide": Color(0.74, 0.56, 0.34),
}

## Pewter badge material shared by every pilgrim's scrip, marked worn so the variant
## stand-in finish (EquipmentVariant.finish_mesh) leaves it alone: pewter dulls, it does not rust.
static var _pewter: Dictionary = {}
## Woven bag material -> its copy in an undyed grade's own colour (see UNDYED).
static var _tinted: Dictionary = {}
static var _hidden: ShaderMaterial


## How one surface of a bag layer is dressed: {} = the ordinary layer rules;
## {"keep": material} (the badge: pewter on pilgrims, hidden on everyone else); or
## {"grade", "slot", "tint"} for CitizenBags.cloth, where tint alpha 0 keeps the baked colour.
static func surface_rule(source: BaseMaterial3D, cell: String, record: Dictionary) -> Dictionary:
	if source == null:
		return {}
	var material_name := source.resource_name
	var pilgrim := String(record.get("trade", "")) == PILGRIM
	var poor := EquipmentVariant.prestige(cell) <= 1
	if material_name.ends_with(BADGE):
		return {"keep": pewter(source) if pilgrim else hidden()}
	if material_name.ends_with(POUCH):
		if pilgrim:
			return {"grade": "leather", "slot": 1, "tint": Color(0, 0, 0, 0)}
		if poor:
			var grade := "rawhide" if _roll(record) < 0.5 else "linen_coarse"
			return {"grade": grade, "slot": 0, "tint": UNDYED[grade]}
		return {"grade": "leather_tooled", "slot": 1, "tint": Color(0, 0, 0, 0)}
	if material_name.ends_with(STRAP):
		if poor and not pilgrim:
			return {"grade": "rawhide", "slot": 0, "tint": UNDYED["rawhide"]}
		return {"grade": "leather", "slot": 0, "tint": Color(0, 0, 0, 0)}
	if material_name.ends_with(SACK) or material_name.ends_with(CORD):
		return {"grade": "linen_coarse", "slot": 0, "tint": Color(0, 0, 0, 0)}
	return {}


## The shared woven material of a bag surface under `rule` (from surface_rule).
static func cloth(source: BaseMaterial3D, family: String, rule: Dictionary) -> ShaderMaterial:
	var material := CitizenWardrobe.cloth_material(source, family, rule["grade"], rule["slot"])
	var tint: Color = rule["tint"]
	if tint.a <= 0.0:
		return material
	if not _tinted.has(material):
		var copy := material.duplicate() as ShaderMaterial
		var linear := tint.srgb_to_linear()
		copy.set_shader_parameter(&"base_color", Vector3(linear.r, linear.g, linear.b))
		_tinted[material] = copy
	return _tinted[material]


## Shared material that draws nothing (the badge of a scrip that is not a pilgrim's):
## every vertex collapses, so the surface costs no fragments and casts no shadow.
static func hidden() -> ShaderMaterial:
	if _hidden == null:
		var shader := Shader.new()
		shader.code = (
			"shader_type spatial;\nrender_mode unshaded;\n"
			+ "void vertex() {\n\tPOSITION = vec4(0.0, 0.0, 2.0, 1.0);\n}\n"
		)
		_hidden = ShaderMaterial.new()
		_hidden.resource_name = "hidden_bag_badge"
		_hidden.shader = shader
	return _hidden


## The badge's shared pewter: the baked source marked worn (see _pewter).
static func pewter(source: BaseMaterial3D) -> BaseMaterial3D:
	if not _pewter.has(source):
		var material := source.duplicate() as BaseMaterial3D
		material.resource_name = source.resource_name
		# Pewter is a pale, soft tin alloy: light grey and only half metallic, so the
		# badge reads against the leather without an environment map to reflect.
		material.albedo_color = Color(0.78, 0.78, 0.74)
		material.metallic = 0.45
		material.roughness = 0.45
		material.set_meta(&"variant_wear", 1)
		_pewter[source] = material
	return _pewter[source]


## Per-resident roll in [0, 1) for the p1 pouch: half the poor carry linen, half rawhide.
static func _roll(record: Dictionary) -> float:
	return float(("scrip:" + String(record.get("id", ""))).hash() & 0xFFFF) / 65536.0
