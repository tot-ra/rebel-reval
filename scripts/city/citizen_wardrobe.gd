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
##
## Variants (task R-2004): a `wear` entry is "<layer>@<cell>" (prestige and wear cell,
## docs/SYSTEMS/EQUIPMENT_VARIANTS.md). A layer mounts `<layer>_<cell>.glb` when the body
## has one, else its base layer; the cell's wear then scales the cloth wear and gives the
## layer's iron and mail a stand-in finish. Plain "<layer>" entries (older data) are w1.

const EquipmentVariant := preload("res://scripts/city/equipment_variant.gd")
const CitizenBags := preload("res://scripts/city/citizen_bags.gd")
## Rigid belt gear on the baked belt (task R-2033): buckle, purse, keys, beads.
const BeltGear := preload("res://scripts/city/belt_gear.gd")

const LAYER_PATH := "res://assets/characters/realistic/%s/layers/%s.glb"
const LAYER_DIR := "res://assets/characters/realistic/%s/layers"
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
	"linen_coarse_w1": 0.09,
	"linen_coarse_w2": 0.09,
	"fur": 0.12,
	"leather": 0.22,
	"quilted": 0.20,
	# Bag leathers (task R-2034, tools/assets/realistic_humans/bag_textiles.py).
	"leather_tooled": 0.11,
	"rawhide": 0.20,
	"quilted_silk": 0.20,
}
## Worn coarse linen (task R-2024): albedo-only grades over the plain linen_coarse weave.
const GRADE_BASE := {"linen_coarse_w1": "linen_coarse", "linen_coarse_w2": "linen_coarse"}
## Statuses that sweat their shirt through (coarse linen w2): day labour and service.
const SWEAT_STATUS := ["labourer", "servant"]
## Rim sheen of the nap; textiles with a hard face have none.
const GRADE_FUZZ := {"homespun": 0.35, "broadcloth": 0.25, "scarlet": 0.2, "fur": 0.5}
## Census status -> wealth: 0 poor, 1 middling, 2 rich (unknown: middling).
const WEALTH := {
	"labourer": 0,
	"servant": 0,
	"free_commoner": 0,
	"apprentice": 0,
	"dependent": 0,
	"soldier": 0,
	"journeyman": 1,
	"master_craftsman": 1,
	"clerk": 1,
	"cleric": 1,
	"burgher": 1,
	"burgher_merchant": 2,
	"guest_merchant": 2,
	"patrician": 2,
	"noble": 2,
}
## Variant wear (w0, w1, w2) -> [soil, patches, fade] scale on a layer's cloth wear.
const CELL_WEAR := [[0.5, 0.2, 0.3], [1.0, 1.0, 1.0], [1.5, 2.2, 1.8]]
## Floor of [patches, fade] on a battered (w2) layer, so even a rich man's old aketon shows it.
const BATTERED_FLOOR := [0.45, 0.35]
## Fine wool layers (task R-2022): the surcoat and the Order mantle are the lord's issue or a
## knight's own cloth, not the wearer's purse, so the variant cell alone sets grade and wear.
## p2 (crown and lords' issue) broadcloth, p3 (a knight's own surcoat) scarlet; the Order
## mantle and its brothers' surcoats stay broadcloth (the Rule asks plain cloth, not scarlet).
const FINE_WOOL_LAYERS := ["surcoat", "order_mantle"]
## Variant wear (w0, w1, w2) -> [mud at the hem, patches, sun fade, torn hem]: w0 fresh from the
## store, w1 travel-worn (hem mud, faded), w2 torn at the hem and patched.
const FINE_WOOL_WEAR := [[0.04, 0.0, 0.0, 0.0], [0.4, 0.0, 0.3, 0.0], [0.7, 0.45, 0.45, 1.0]]
## Padded layers (task R-2019): one fitted aketon per body, its variant cell picks the cover.
## p1 undyed linen (town munition), p2 linen dyed madder or woad (crown and lords' issue), p3
## silk-covered (a knight's, seen only at hem and collar). Wear adds sweat at collar and armpits.
const PADDED_LAYERS := ["gambeson"]
## Prestige -> dyes (sRGB) one unit (duty post) or resident picks from; p1 stays undyed.
const PADDED_DYES := {
	2: [[0.55, 0.20, 0.14], [0.27, 0.36, 0.50]],
	3: [[0.46, 0.10, 0.09], [0.16, 0.22, 0.40], [0.20, 0.16, 0.13]],
}
## Variant wear (w0, w1, w2) -> sweat and patched pieces on a padded layer. Issue gear is
## mended by the store, not by its wearer's purse, so the cell alone sets its patches.
const PADDED_SWEAT := [0.15, 0.55, 0.85]
const PADDED_PATCHES := [0.0, 0.08, 0.6]
## Patch pieces on quilting replace whole channels (2 channels x 12 cm), not squares
## across the stitch lines (the old "checkerboard" aketon); metres, garment UV axes.
const QUILT_PATCH := Vector2(0.08, 0.12)
const SQUARE_PATCH := Vector2(0.16, 0.16)
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
	"_short_tunic": 1,
	"_wool_tunic": 1,
	"_long_tunic": 1,
	"_cotehardie": 1,
	"_work_gown": 1,
	"_gown": 1,
	"_hose": 2,
	"_headscarf": 2,
}
## Men's base tunics (task R-2023): the body's baked tunic or cotehardie takes a variant
## cell from the census like a layer. Prestige follows wealth (p1 homespun, p2 broadcloth,
## p3 scarlet); wear is rolled per resident: the poor w1 or w2, the middling w0 or w1, the
## rich w0; trades that wade in mud wear theirs out (w2).
## Wear (w0, w1, w2) -> [rub at elbows, cuffs and seat, frayed edges, patches scale, patches floor].
const TUNIC_WEAR := [[0.15, 0.0, 0.0, 0.0], [0.55, 0.45, 0.4, 0.0], [1.0, 1.0, 1.0, 0.45]]
## Share of residents of each wealth whose tunic is the worse of their two cells.
const TUNIC_WORN_SHARE := [0.45, 0.5, 0.0]
## Mud wear (TRADE_WEAR) at which a trade wears its tunic out (porters, carters, farmers).
const TUNIC_HARD_MUD := 0.7
## Pewter sleeve buttons baked on crowd tunics (mens_dress.sleeve_buttons): shown on p2 and p3.
const TUNIC_BUTTONS := "_tunic_buttons"
## Dags (cut leaf tongues) on the hood's hem (task R-2028,
## tools/assets/realistic_humans/headwear.py):
## the hood layer carries them as their own surface, shown on prestige p3 only.
const HOOD_DAGS := "_hood_dags"

## Layer path -> PackedScene, or null for a layer the body was not fitted with.
static var _scenes: Dictionary = {}
## Source garment material -> {grade: ShaderMaterial}, shared by all residents.
static var _cloth: Dictionary = {}
static var _shaders: Dictionary = {}
static var _hidden: ShaderMaterial


## Mounts every layer of `record["wear"]` on `rig`; returns how many are worn.
## Safe to call twice: layers already worn are kept.
static func dress(rig: SharedCharacterRig, record: Dictionary) -> int:
	var body := String(record.get("body", ""))
	var dyes: Dictionary = record.get("wear_dye", {})
	var worn := 0
	# Keys and beads hang as rigid parts on a baked belt (BeltGear), not as fitted layers.
	var rigid := BeltGear.handles(rig, record)
	for entry: String in record.get("wear", []):
		var parts := EquipmentVariant.split(entry)
		var layer := parts[0]
		var garment_id := StringName(GARMENT_PREFIX + layer)
		if rig.has_garment(garment_id) or layer in rigid:
			worn += 1
			continue
		# The variant's own fitted layer when shipped, else the base layer (fallback).
		var scene := EquipmentVariant.variant_scene(LAYER_DIR % body, layer, parts[1])
		if scene == null:
			scene = layer_scene(body, layer)
		if scene == null or not rig.equip_garment(garment_id, scene):
			continue
		worn += 1
	weave(rig, record)
	BeltGear.hang(rig, record)
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
		var parts := _layer_of(mesh_instance, record)
		var layer := parts[0]
		var level := EquipmentVariant.wear(parts[1])
		# A battered (w2) surcoat or mantle has a torn hem (shader variant with discard).
		var torn := level == 2 and layer in FINE_WOOL_LAYERS
		var tunic := tunic_cell(record) if layer.is_empty() else ""
		var woven := false
		for surface in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.mesh.surface_get_material(surface) as BaseMaterial3D
			if (
				not tunic.is_empty()
				and source != null
				and source.resource_name.ends_with(TUNIC_BUTTONS)
			):
				if EquipmentVariant.prestige(tunic) < 2:
					mesh_instance.set_surface_override_material(surface, hidden_material())
				continue
			if source != null and source.resource_name.ends_with(HOOD_DAGS):
				if EquipmentVariant.prestige(parts[1]) < 3:
					mesh_instance.set_surface_override_material(surface, hidden_material())
				continue
			# Scrips and sacks (R-2034): the cell picks each part's leather or linen.
			var bag := (
				CitizenBags.surface_rule(source, parts[1], record)
				if layer in CitizenBags.LAYERS
				else {}
			)
			if bag.has("keep"):
				mesh_instance.set_surface_override_material(surface, bag["keep"])
				continue
			var family := family_of(source)
			if family.is_empty():
				continue
			var slot := dye_slot(source.resource_name, layer)
			var grade := grade_of(family, wealth, slot)
			if grade == "linen_coarse":
				grade = linen_grade(record)
			if bag.has("grade"):
				var woven_bag := CitizenBags.cloth(source, family, bag)
				mesh_instance.set_surface_override_material(surface, woven_bag)
				woven = true
				continue
			if grade == "linen_coarse":
				grade = linen_grade(record)
			if family == "wool" and layer in FINE_WOOL_LAYERS:
				grade = fine_grade(layer, parts[1], record)
			if (
				family == "quilted"
				and layer in PADDED_LAYERS
				and EquipmentVariant.prestige(parts[1]) == 3
			):
				grade = "quilted_silk"
			mesh_instance.set_surface_override_material(
				surface, cloth_material(source, family, grade, slot, torn)
			)
			woven = true
		if not layer.is_empty():
			# Iron and mail of the layer (kettle hat, haubergeon): stand-in wear finish.
			EquipmentVariant.finish_mesh(mesh_instance, level)
		if not woven:
			continue
		var outer := Color(1, 1, 1, 0)
		var under := Color(1, 1, 1, 0)
		if layer.is_empty():
			outer = _linear_dye(record.get("cloth", []))
			under = _linear_dye(record.get("under", []))
		else:
			outer = _linear_dye(outer_dyes.get(layer, padded_dye(layer, parts[1], record)))
		mesh_instance.set_instance_shader_parameter(&"dye_outer", outer)
		mesh_instance.set_instance_shader_parameter(&"dye_under", under)
		var layer_wear := wear if layer.is_empty() else cell_wear(wear, level)
		if layer in FINE_WOOL_LAYERS:
			layer_wear = fine_wool_wear(wear, level)
		if torn:
			mesh_instance.set_instance_shader_parameter(&"wear_tear", float(FINE_WOOL_WEAR[2][3]))
		mesh_instance.set_instance_shader_parameter(&"wear_soil", layer_wear[0])
		var age := layer_wear[1]
		if layer in PADDED_LAYERS:
			age.x = float(PADDED_PATCHES[clampi(level, 0, 2)])
			age.w = float(PADDED_SWEAT[clampi(level, 0, 2)])
		if not tunic.is_empty():
			# The tunic's own cell: patches only as it wears, elbows and hems by its wear.
			var tunic_wear: Array = TUNIC_WEAR[EquipmentVariant.wear(tunic)]
			age.x = maxf(age.x * float(tunic_wear[2]), float(tunic_wear[3]))
			mesh_instance.set_instance_shader_parameter(
				&"wear_cloth", Vector4(float(tunic_wear[0]), float(tunic_wear[1]), 0.0, 0.0)
			)
		mesh_instance.set_instance_shader_parameter(&"wear_age", age)


static func wealth_of(record: Dictionary) -> int:
	return int(WEALTH.get(String(record.get("status", "")), 1))


## Variant cell ("p2_w1") of a man's baked base tunic, a pure function of the record; ""
## for women (their gowns keep the resident's wealth wear).
static func tunic_cell(record: Dictionary) -> String:
	if String(record.get("sex", "")) != "m":
		return ""
	var wealth := wealth_of(record)
	var trade: Array = TRADE_WEAR.get(String(record.get("trade", "")), [0.0, 0.0, 0.0, 0.0])
	var roll := float(("tunic:" + String(record.get("id", ""))).hash() & 0xFFFF) / 65535.0
	var level: int = [1, 0, 0][wealth] + (1 if roll < float(TUNIC_WORN_SHARE[wealth]) else 0)
	if float(trade[0]) >= TUNIC_HARD_MUD and wealth < 2:
		level = 2
	return "p%d_w%d" % [wealth + 1, level]


## Shared material that draws nothing: collapses every vertex, so a hidden surface
## (p1 sleeve buttons) costs no fragments and casts no shadow.
static func hidden_material() -> ShaderMaterial:
	if _hidden == null:
		var shader := Shader.new()
		shader.code = (
			"shader_type spatial;\nrender_mode unshaded;\n"
			+ "void vertex() {\n\tPOSITION = vec4(0.0, 0.0, 2.0, 1.0);\n}\n"
		)
		_hidden = ShaderMaterial.new()
		_hidden.resource_name = "hidden"
		_hidden.shader = shader
	return _hidden


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


## Dye [r, g, b] (sRGB) of a padded layer of variant `cell`, or [] for undyed linen. Men of
## one duty post share it (one store's issue); off duty it follows the resident.
static func padded_dye(layer: String, cell: String, record: Dictionary) -> Array:
	var dyes: Array = PADDED_DYES.get(EquipmentVariant.prestige(cell), [])
	if not layer in PADDED_LAYERS or dyes.is_empty():
		return []
	var duty: Dictionary = record.get("duty", {}) if record.get("duty") is Dictionary else {}
	var key := String(duty.get("post", record.get("id", "")))
	return dyes[posmod(("padded:" + key).hash(), dyes.size())]


## The resident's cloth wear scaled for a layer of variant wear `level` (0..2).
static func cell_wear(wear: Array[Vector4], level: int) -> Array[Vector4]:
	if level == 1:
		return wear
	var scale: Array = CELL_WEAR[clampi(level, 0, 2)]
	var soil := (wear[0] * float(scale[0])).clamp(Vector4.ZERO, Vector4.ONE)
	var patches := clampf(wear[1].x * float(scale[1]), 0.0, 1.0)
	var fade := clampf(wear[1].y * float(scale[2]), 0.0, 1.0)
	if level == 2:
		patches = maxf(patches, BATTERED_FLOOR[0])
		fade = maxf(fade, BATTERED_FLOOR[1])
	return [soil, Vector4(patches, fade, wear[1].z, 0.0)]


## Wool grade of a fine wool layer of variant `cell` (see FINE_WOOL_LAYERS).
static func fine_grade(layer: String, cell: String, record: Dictionary) -> String:
	if layer != "surcoat" or EquipmentVariant.prestige(cell) < 3:
		return "broadcloth"
	for entry: String in record.get("wear", []):
		if EquipmentVariant.split(entry)[0] == "order_mantle":
			return "broadcloth"
	return "scarlet"


## Wear of a fine wool layer: its cell's FINE_WOOL_WEAR, not the wearer's trade or purse
## (a poor soldier's issue surcoat is not his mended own; no butcher stains on a garrison).
## The resident's seed still varies the mud and the patch pattern.
static func fine_wool_wear(wear: Array[Vector4], level: int) -> Array[Vector4]:
	var cell: Array = FINE_WOOL_WEAR[clampi(level, 0, 2)]
	var seed := wear[1].z
	var mud := clampf(float(cell[0]) * (0.8 + 0.4 * seed), 0.0, 1.0)
	return [Vector4(mud, 0.0, 0.0, 0.0), Vector4(float(cell[1]), float(cell[2]), seed, 0.0)]


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


## Coarse linen of a poor resident by wear (task R-2024): w2 sweat-stained for labourers,
## servants and one in three of the rest (rolled on the id), else w1 yellowed. Everyone
## better off wears bleached fine linen, the w0 (docs/SYSTEMS/EQUIPMENT_VARIANTS.md).
static func linen_grade(record: Dictionary) -> String:
	var roll := posmod(("linen:" + String(record.get("id", ""))).hash(), 3)
	if String(record.get("status", "")) in SWEAT_STATUS or roll == 0:
		return "linen_coarse_w2"
	return "linen_coarse_w1"


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
		var key := String(CLOTH_KEY.get(layer, layer))
		# A padded layer's bound edges and hems take its dye too (an aketon is one cloth).
		if layer in PADDED_LAYERS and material_name.ends_with("_%s_binding" % key):
			return 1
		return 1 if material_name.ends_with("_" + key) else 0
	for suffix: String in BODY_DYE_SLOT:
		if material_name.ends_with(suffix):
			return BODY_DYE_SLOT[suffix]
	return 0


## The shared material of `source` woven in `grade`.
static func cloth_material(
	source: BaseMaterial3D, family: String, grade: String, slot: int, torn: bool = false
) -> ShaderMaterial:
	var by_grade: Dictionary = _cloth.get_or_add(source, {})
	var key := grade + ("/torn" if torn else "")
	if by_grade.has(key):
		return by_grade[key]
	var material := ShaderMaterial.new()
	# Keep the garment's name: dye rules and tests match on it.
	material.resource_name = source.resource_name
	material.shader = _shader(source.cull_mode == BaseMaterial3D.CULL_DISABLED, torn)
	var maps := "%s%s_%%s_512.png" % [TEXTILE_DIR, grade]
	material.set_shader_parameter(&"albedo_tex", load(maps % "albedo"))
	# Worn grades share the weave of their base grade (GRADE_BASE).
	var weave_maps := "%s%s_%%s_512.png" % [TEXTILE_DIR, GRADE_BASE.get(grade, grade)]
	material.set_shader_parameter(&"normal_tex", load(weave_maps % "normal"))
	material.set_shader_parameter(&"orm_tex", load(weave_maps % "orm"))
	material.set_shader_parameter(&"wear_tex", load(WEAR_MASK))
	(
		material
		. set_shader_parameter(
			&"base_color",
			Vector3(
				source.albedo_color.srgb_to_linear().r,
				source.albedo_color.srgb_to_linear().g,
				source.albedo_color.srgb_to_linear().b,
			)
		)
	)
	material.set_shader_parameter(
		&"uv_scale", float(FAMILY_TILE[family]) / float(GRADE_TILE[grade])
	)
	material.set_shader_parameter(&"tile_metres", float(FAMILY_TILE[family]))
	var depth := source.normal_scale if source.normal_enabled else 0.0
	material.set_shader_parameter(&"normal_depth", depth)
	material.set_shader_parameter(&"fuzz", float(GRADE_FUZZ.get(grade, 0.0)))
	material.set_shader_parameter(&"dye_slot", slot)
	var quilted := grade.begins_with("quilted")
	material.set_shader_parameter(&"patch_cell", QUILT_PATCH if quilted else SQUARE_PATCH)
	by_grade[key] = material
	return material


## The cloth shader, double-sided and/or with TORN_HEM defined. Only torn layers get the
## variant with `discard`, so every other cloth keeps the cheaper opaque pipeline.
static func _shader(double_sided: bool, torn: bool = false) -> Shader:
	var key := Vector2i(int(double_sided), int(torn))
	if not _shaders.has(key):
		if double_sided or torn:
			var code := CLOTH_SHADER.code
			if double_sided:
				code = code.replace("cull_back", "cull_disabled")
			if torn:
				code = code.replace(
					"shader_type spatial;", "shader_type spatial;\n#define TORN_HEM"
				)
			var shader := Shader.new()
			shader.code = code
			_shaders[key] = shader
		else:
			_shaders[key] = CLOTH_SHADER
	return _shaders[key]


## [layer id, variant cell] of a mounted `Garment_wear_<layer>_*` mesh; ["", ""] for the base body.
static func _layer_of(mesh_instance: MeshInstance3D, record: Dictionary) -> PackedStringArray:
	var name := String(mesh_instance.name)
	for entry: String in record.get("wear", []):
		var parts := EquipmentVariant.split(entry)
		if name.begins_with("Garment_%s%s_" % [GARMENT_PREFIX, parts[0]]):
			return parts
	return PackedStringArray(["", ""])


## Record dye [r, g, b] (sRGB) as a linear instance colour; alpha 0 = no dye.
static func _linear_dye(rgb: Array) -> Color:
	if rgb.size() < 3:
		return Color(1, 1, 1, 0)
	var linear := Color(float(rgb[0]), float(rgb[1]), float(rgb[2])).srgb_to_linear()
	linear.a = 1.0
	return linear
