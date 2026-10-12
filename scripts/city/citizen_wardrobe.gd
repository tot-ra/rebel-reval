class_name CitizenWardrobe
extends RefCounted

## Layered dress of a census resident (docs/SYSTEMS/CITIZEN_WARDROBE.md). The
## body ships its base outfit baked in; this mounts the extra layers the census
## wardrobe rules chose (`wear` in content/world/reval_city/citizens.json):
## hoods, coifs, veils, aprons, aketon, mail, surcoat, helmets, keys, beads,
## scrips and sacks. Each layer is a skinned GLB fitted to that very body
## (assets/characters/realistic/<body>/layers/<layer>.glb), so it deforms with
## the rig like the baked clothes, and is dyed with the resident's `wear_dye`.
##
## Cloth grade and wear (task R-1667): every cloth surface, baked or layered, is
## drawn with a shared grade material (homespun, broadcloth, scarlet, coarse or
## fine linen, leather, quilted) picked by the resident's wealth, and dirtied by
## trade and wealth (smith soot, baker flour, butcher stains, labourer mud,
## patched and faded poor wool) through instance uniforms of
## scripts/city/citizen_cloth.gdshader. No resident owns a material or texture.

const LAYER_PATH := "res://assets/characters/realistic/%s/layers/%s.glb"
const GARMENT_PREFIX := "wear_"
## Layers whose cloth material is named after its textile, not the layer
## (garments.py reuses the hero builders: hood_wool, apron_leather, mail, iron).
const CLOTH_KEY := {
	"hood": "hood_wool",
	"smith_apron": "apron_leather",
	"mail_haubergeon": "mail",
	"kettle_hat": "iron",
}

const CLOTH_SHADER := preload("res://scripts/city/citizen_cloth.gdshader")
const TEXTILE_DIR := "res://assets/characters/realistic/textiles/"
const WEAR_MASK := TEXTILE_DIR + "wear_mask_512.png"
## Metres per garment UV unit of each baked family (textiles.TILE_METRES). Mail
## and iron are not cloth and keep their own materials.
const FAMILY_TILE := {"wool": 0.09, "linen": 0.07, "leather": 0.22, "quilted": 0.20}
## Grade -> tile metres (textiles.GRADE_TILE_METRES; leather and quilted are the family sets).
const GRADE_TILE := {
	"homespun": 0.12,
	"broadcloth": 0.08,
	"scarlet": 0.06,
	"linen_coarse": 0.09,
	"linen_fine": 0.05,
	"fur": 0.12,
	"leather": 0.22,
	"quilted": 0.20,
}
## Rim sheen of the nap; textiles with a hard face have none.
const GRADE_FUZZ := {"homespun": 0.35, "broadcloth": 0.25, "scarlet": 0.2, "fur": 0.5}
## Census status -> wealth: 0 poor, 1 middling, 2 rich (unknown: middling).
const WEALTH := {
	"labourer": 0, "servant": 0, "free_commoner": 0, "apprentice": 0, "dependent": 0, "soldier": 0,
	"journeyman": 1, "master_craftsman": 1, "clerk": 1, "cleric": 1, "burgher": 1,
	"burgher_merchant": 2, "guest_merchant": 2, "patrician": 2, "noble": 2,
}
## Wealth -> [mud, patches, fade]: the poor walk the lanes in mended, sun-pale wool.
const WEALTH_WEAR := [[0.45, 0.7, 0.5], [0.22, 0.15, 0.18], [0.06, 0.0, 0.0]]
## Trade -> [mud, soot, flour, stain] on top of the wealth wear (the larger wins).
## Flour also stands for lime, stone and saw dust.
const TRADE_WEAR := {
	"smith": [0.2, 0.9, 0.0, 0.0],
	"nailsmith": [0.2, 0.9, 0.0, 0.0],
	"armourer": [0.15, 0.7, 0.0, 0.0],
	"cutler": [0.1, 0.55, 0.0, 0.0],
	"brewer": [0.2, 0.25, 0.2, 0.0],
	"tallow": [0.2, 0.3, 0.0, 0.2],
	"chandler": [0.1, 0.2, 0.0, 0.1],
	"baker": [0.1, 0.0, 0.9, 0.0],
	"cook": [0.1, 0.25, 0.3, 0.15],
	"castle_cook": [0.1, 0.25, 0.3, 0.15],
	"butcher": [0.3, 0.0, 0.0, 0.9],
	"fishmonger": [0.3, 0.0, 0.0, 0.45],
	"tanner": [0.6, 0.0, 0.0, 0.55],
	"barber": [0.1, 0.0, 0.0, 0.3],
	"healer": [0.1, 0.0, 0.0, 0.2],
	"midwife": [0.15, 0.0, 0.0, 0.25],
	"mason": [0.5, 0.0, 0.45, 0.0],
	"limeburner": [0.5, 0.1, 0.7, 0.0],
	"brickmaker": [0.9, 0.1, 0.0, 0.0],
	"tiler": [0.6, 0.0, 0.2, 0.0],
	"potter": [0.7, 0.0, 0.0, 0.0],
	"carpenter": [0.3, 0.0, 0.3, 0.0],
	"joiner": [0.2, 0.0, 0.25, 0.0],
	"cooper": [0.3, 0.0, 0.2, 0.0],
	"labourer": [0.8, 0.0, 0.0, 0.0],
	"porter": [0.7, 0.0, 0.0, 0.0],
	"carter": [0.85, 0.0, 0.0, 0.0],
	"drover": [0.9, 0.0, 0.0, 0.0],
	"farmer": [0.85, 0.0, 0.0, 0.0],
	"gardener": [0.75, 0.0, 0.0, 0.0],
	"stable_hand": [0.85, 0.0, 0.0, 0.0],
	"dairy": [0.6, 0.0, 0.0, 0.0],
	"washerwoman": [0.6, 0.0, 0.0, 0.0],
	"fisher": [0.6, 0.0, 0.0, 0.2],
	"boatman": [0.5, 0.0, 0.0, 0.0],
	"sailor": [0.4, 0.0, 0.0, 0.0],
	"shipwright": [0.5, 0.0, 0.2, 0.0],
	"pilgrim": [0.7, 0.0, 0.0, 0.0],
	"pedlar": [0.6, 0.0, 0.0, 0.0],
}
## Base-body cloth dyed by CityCitizens.dye (scripts/city/city_citizens.gd):
## material name suffix -> dye slot (1 `cloth`, 2 `under`). Keep in step with it.
const BODY_DYE_SLOT := {
	"_short_tunic": 1, "_wool_tunic": 1, "_work_gown": 1, "_gown": 1, "_hose": 2, "_headscarf": 2,
}

## Layer path -> PackedScene, or null for a layer the body was not fitted with.
static var _scenes: Dictionary = {}
## Source garment material -> {grade: ShaderMaterial}, shared by all residents.
static var _cloth: Dictionary = {}
static var _shaders: Dictionary = {}


## Mounts every layer of `record["wear"]` on `rig`; returns how many are worn.
## Safe to call twice: layers already worn are kept.
static func dress(rig: SharedCharacterRig, record: Dictionary) -> int:
	var body := String(record.get("body", ""))
	var dyes: Dictionary = record.get("wear_dye", {})
	var worn := 0
	for layer: String in record.get("wear", []):
		var garment_id := StringName(GARMENT_PREFIX + layer)
		if rig.has_garment(garment_id):
			worn += 1
			continue
		var scene := layer_scene(body, layer)
		if scene == null or not rig.equip_garment(garment_id, scene):
			continue
		worn += 1
	weave(rig, record)
	return worn


static func layer_scene(body: String, layer: String) -> PackedScene:
	var path := LAYER_PATH % [body, layer]
	if not _scenes.has(path):
		_scenes[path] = load(path) if ResourceLoader.exists(path) else null
		if _scenes[path] == null:
			push_warning("CitizenWardrobe: %s has no %s layer" % [body, layer])
	return _scenes[path]


## Gives every cloth surface on the rig its shared grade material and sets this
## resident's dyes and wear as instance uniforms. Safe to call twice.
static func weave(rig: SharedCharacterRig, record: Dictionary) -> void:
	var skeleton := rig.skeleton()
	if skeleton == null:
		return
	var wealth := wealth_of(record)
	var wear := wear_of(record)
	var outer_dyes: Dictionary = record.get("wear_dye", {})
	for child: Node in skeleton.get_children():
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var layer := _layer_of(mesh_instance, record)
		var woven := false
		for surface in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.mesh.surface_get_material(surface) as BaseMaterial3D
			var family := family_of(source)
			if family.is_empty():
				continue
			var slot := dye_slot(source.resource_name, layer)
			var grade := grade_of(family, wealth, slot)
			mesh_instance.set_surface_override_material(surface, cloth_material(source, family, grade, slot))
			woven = true
		if not woven:
			continue
		var outer := Color(1, 1, 1, 0)
		var under := Color(1, 1, 1, 0)
		if layer.is_empty():
			outer = _linear_dye(record.get("cloth", []))
			under = _linear_dye(record.get("under", []))
		else:
			outer = _linear_dye(outer_dyes.get(layer, []))
		mesh_instance.set_instance_shader_parameter(&"dye_outer", outer)
		mesh_instance.set_instance_shader_parameter(&"dye_under", under)
		mesh_instance.set_instance_shader_parameter(&"wear_soil", wear[0])
		mesh_instance.set_instance_shader_parameter(&"wear_age", wear[1])


static func wealth_of(record: Dictionary) -> int:
	return int(WEALTH.get(String(record.get("status", "")), 1))


## [Vector4(mud, soot, flour, stain), Vector4(patches, fade, seed, 0)]: the larger
## of the wealth and trade wear, scaled by a per-resident roll so two smiths differ.
static func wear_of(record: Dictionary) -> Array[Vector4]:
	var base: Array = WEALTH_WEAR[wealth_of(record)]
	var trade: Array = TRADE_WEAR.get(String(record.get("trade", "")), [0.0, 0.0, 0.0, 0.0])
	var roll := String(record.get("id", "")).hash()
	var scale := 0.75 + 0.4 * float(roll & 0xFF) / 255.0
	var seed := float((roll >> 8) & 0xFFFF) / 65535.0
	var soil := Vector4(maxf(base[0], trade[0]), trade[1], trade[2], trade[3]) * scale
	soil = soil.clamp(Vector4.ZERO, Vector4.ONE)
	var patches := clampf(base[1] * scale, 0.0, 1.0)
	var fade := clampf(base[2] * scale, 0.0, 1.0)
	return [soil, Vector4(patches, fade, seed, 0.0)]


## Cloth grade of a surface: wool by wealth (the rich wear scarlet outside and
## broadcloth beneath), linen fine for all but the poor; leather and quilting as made.
static func grade_of(family: String, wealth: int, slot: int) -> String:
	match family:
		"wool":
			if wealth == 2:
				return "scarlet" if slot == 1 else "broadcloth"
			return "broadcloth" if wealth == 1 else "homespun"
		"linen":
			return "linen_coarse" if wealth == 0 else "linen_fine"
	return family


## Baked textile family of a garment material, read off its albedo map
## (`textiles/<family>_albedo[_512].png`); "" for skin, hair, mail and iron.
static func family_of(material: BaseMaterial3D) -> String:
	if material == null or material.albedo_texture == null:
		return ""
	var path := material.albedo_texture.resource_path
	if not path.begins_with(TEXTILE_DIR):
		return ""
	var family := path.get_file().get_slice("_albedo", 0)
	return family if FAMILY_TILE.has(family) else ""


## 1 when the surface takes the outer dye (base tunic or gown, or a layer's own
## cloth), 2 for the base hose and headscarf, 0 when it keeps its baked colour.
static func dye_slot(material_name: String, layer: String) -> int:
	if not layer.is_empty():
		return 1 if material_name.ends_with("_" + String(CLOTH_KEY.get(layer, layer))) else 0
	for suffix: String in BODY_DYE_SLOT:
		if material_name.ends_with(suffix):
			return BODY_DYE_SLOT[suffix]
	return 0


## The shared material of `source` woven in `grade`.
static func cloth_material(
	source: BaseMaterial3D, family: String, grade: String, slot: int
) -> ShaderMaterial:
	var by_grade: Dictionary = _cloth.get_or_add(source, {})
	if by_grade.has(grade):
		return by_grade[grade]
	var material := ShaderMaterial.new()
	# Keep the garment's name: dye rules and tests match on it.
	material.resource_name = source.resource_name
	material.shader = _shader(source.cull_mode == BaseMaterial3D.CULL_DISABLED)
	var maps := "%s%s_%%s_512.png" % [TEXTILE_DIR, grade]
	material.set_shader_parameter(&"albedo_tex", load(maps % "albedo"))
	material.set_shader_parameter(&"normal_tex", load(maps % "normal"))
	material.set_shader_parameter(&"orm_tex", load(maps % "orm"))
	material.set_shader_parameter(&"wear_tex", load(WEAR_MASK))
	material.set_shader_parameter(&"base_color", Vector3(
		source.albedo_color.srgb_to_linear().r,
		source.albedo_color.srgb_to_linear().g,
		source.albedo_color.srgb_to_linear().b,
	))
	material.set_shader_parameter(&"uv_scale", float(FAMILY_TILE[family]) / float(GRADE_TILE[grade]))
	material.set_shader_parameter(&"tile_metres", float(FAMILY_TILE[family]))
	var depth := source.normal_scale if source.normal_enabled else 0.0
	material.set_shader_parameter(&"normal_depth", depth)
	material.set_shader_parameter(&"fuzz", float(GRADE_FUZZ.get(grade, 0.0)))
	material.set_shader_parameter(&"dye_slot", slot)
	by_grade[grade] = material
	return material


static func _shader(double_sided: bool) -> Shader:
	if not _shaders.has(double_sided):
		if double_sided:
			var shader := Shader.new()
			shader.code = CLOTH_SHADER.code.replace("cull_back", "cull_disabled")
			_shaders[double_sided] = shader
		else:
			_shaders[double_sided] = CLOTH_SHADER
	return _shaders[double_sided]


## Layer id of a mounted `Garment_wear_<layer>_*` mesh, "" for the base body.
static func _layer_of(mesh_instance: MeshInstance3D, record: Dictionary) -> String:
	var name := String(mesh_instance.name)
	for layer: String in record.get("wear", []):
		if name.begins_with("Garment_%s%s_" % [GARMENT_PREFIX, layer]):
			return layer
	return ""


## Record dye [r, g, b] (sRGB) as a linear instance colour; alpha 0 = no dye.
static func _linear_dye(rgb: Array) -> Color:
	if rgb.size() < 3:
		return Color(1, 1, 1, 0)
	var linear := Color(float(rgb[0]), float(rgb[1]), float(rgb[2])).srgb_to_linear()
	linear.a = 1.0
	return linear
