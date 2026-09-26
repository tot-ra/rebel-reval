class_name MapViewBurgherHouseSurfaceVariety
extends RefCounted

## Per-building wall/roof remaps for production house GLBs.
##
## The kit only ships two meshes per tier, so a street of similar plots would
## otherwise clone one albedo set. Duplicate imported materials, then swap in
## extra tileable maps and a mild tint/UV offset from the stable building id.

const TEX_DIR := "res://assets/materials/pbr/building_variants"

const FAMILY_TILE := &"tile"
const FAMILY_SHINGLE := &"shingle"
const FAMILY_THATCH := &"thatch"
const FAMILY_RUBBLE := &"rubble"
const FAMILY_RENDER := &"render"
const FAMILY_LIMEWASH := &"limewash"
const FAMILY_LOG := &"log"

const TILE_STEMS: Array[String] = ["tile_red", "tile_umber", "tile_moss"]
const SHINGLE_STEMS: Array[String] = ["shingle_silver", "shingle_oak", "shingle_moss"]
const THATCH_STEMS: Array[String] = ["thatch_gold", "thatch_olive", "thatch_ash"]
const RUBBLE_STEMS: Array[String] = ["rubble_pale", "rubble_buff", "rubble_dark"]
const RENDER_STEMS: Array[String] = ["render_cream", "render_ochre", "render_soot"]
const LIMEWASH_STEMS: Array[String] = ["limewash_chalk", "limewash_straw", "limewash_clay"]
const LOG_STEMS: Array[String] = ["log_pine", "log_weathered", "log_tar"]

# --- AR-03 building surface library ------------------------------------------
# Every procedural box/gabled building wall and roof resolves its authored
# wall_material / roof_material key to one of these shared stems (albedo +
# normal + packed ORM). Stems are shared resources, never forked per building.
const FAMILY_ASHLAR := &"ashlar"
const FAMILY_PLANK := &"plank"
const FAMILY_DAUB := &"daub"
const FAMILY_BRICK := &"brick"
const FAMILY_STRAW := &"straw"
const FAMILY_SOOT := &"soot"
const FAMILY_GABLE_BOARD := &"gable_board"
## Round-log courses painted for flat box walls; the `log` stems above are bark
## and grain only because the burgher GLBs carry real log geometry.
const FAMILY_LOGWALL := &"logwall"

const ASHLAR_STEMS: Array[String] = ["ashlar_pale", "ashlar_buff", "ashlar_grey"]
const PLANK_STEMS: Array[String] = ["plank_vertical", "plank_horizontal", "plank_tarred"]
const DAUB_STEMS: Array[String] = ["daub_clay", "daub_wattle", "daub_straw"]
const BRICK_STEMS: Array[String] = ["brick_red", "brick_dark", "brick_salmon"]
const STRAW_STEMS: Array[String] = ["straw_gold", "straw_grey", "straw_brown"]
const SOOT_STEMS: Array[String] = ["soot_black", "soot_brown", "soot_grey"]
const GABLE_BOARD_STEMS: Array[String] = [
	"gable_board_silver", "gable_board_oak", "gable_board_tarred"
]
const LOGWALL_STEMS: Array[String] = ["logwall_pine", "logwall_weathered", "logwall_tar"]

## Authored `wall_material` key -> library families. `plaster` alternates lime
## render over rubble and limewash over daub; `timber` is frame infill.
const WALL_MATERIAL_FAMILIES := {
	&"limestone": [FAMILY_RUBBLE],
	&"stone": [FAMILY_RUBBLE],
	&"ashlar": [FAMILY_ASHLAR],
	&"plaster": [FAMILY_RENDER, FAMILY_LIMEWASH],
	&"timber": [FAMILY_DAUB],
	&"smoked_plaster": [FAMILY_SOOT],
	&"brick": [FAMILY_BRICK],
	&"plank": [FAMILY_PLANK],
	&"log": [FAMILY_LOGWALL],
	&"gable_board": [FAMILY_GABLE_BOARD],
}
## Authored `roof_material` key -> library families.
const ROOF_MATERIAL_FAMILIES := {
	&"tile": [FAMILY_TILE],
	&"shingle": [FAMILY_SHINGLE],
	&"thatch": [FAMILY_THATCH],
	&"straw": [FAMILY_STRAW],
}
## Limestone on these surfaces is cut and coursed ashlar (ecclesiastical and
## elite fabric), not the vernacular rubble of ordinary houses. Matched as
## substrings of the stable building/landmark ID because the material helpers
## only receive the ID, not the building record.
const ASHLAR_SURFACE_HINTS: Array[String] = [
	"church", "chapel", "cathedral", "st_olaf", "convent", "monaster", "cloister",
	"precinct", "castle", "guild", "town_hall",
]

## Real-world size in metres (u, v) of one texture repeat, measured from the
## painter: e.g. brick is 4 x 0.3 m bricks by 12 x 0.1 m courses, logwall is
## 8 x 0.25 m logs, tile is 8 monk/nun lanes by 9 courses.
const FAMILY_PLATE_METRES := {
	FAMILY_RUBBLE: Vector2(2.4, 2.4),
	FAMILY_ASHLAR: Vector2(1.4, 1.4),
	FAMILY_RENDER: Vector2(4.0, 4.0),
	FAMILY_LIMEWASH: Vector2(2.5, 2.5),
	FAMILY_SOOT: Vector2(2.5, 2.5),
	FAMILY_DAUB: Vector2(2.0, 2.0),
	FAMILY_BRICK: Vector2(1.2, 1.2),
	FAMILY_PLANK: Vector2(1.5, 1.5),
	FAMILY_GABLE_BOARD: Vector2(1.6, 1.6),
	FAMILY_LOGWALL: Vector2(2.0, 2.0),
	FAMILY_LOG: Vector2(2.0, 2.0),
	FAMILY_TILE: Vector2(1.4, 2.25),
	FAMILY_SHINGLE: Vector2(0.84, 2.0),
	FAMILY_THATCH: Vector2(1.6, 1.6),
	FAMILY_STRAW: Vector2(1.8, 1.8),
}
## Stems whose painter differs from the family plate.
const STEM_PLATE_METRES := {
	"daub_wattle": Vector2(1.0, 1.0),
	"plank_horizontal": Vector2(1.75, 1.75),
}
## Normal strength per family: lime coats and daub are near-flat, joints deep.
const FAMILY_NORMAL_SCALE := {
	FAMILY_RENDER: 0.5,
	FAMILY_LIMEWASH: 0.5,
	FAMILY_SOOT: 0.5,
	FAMILY_DAUB: 0.6,
	FAMILY_THATCH: 0.8,
	FAMILY_STRAW: 0.8,
}

const WALL_TINTS: Array[Color] = [
	Color(1.0, 1.0, 1.0),
	Color(1.05, 0.98, 0.88),
	Color(0.9, 0.88, 0.84),
	Color(1.02, 0.92, 0.78),
]
const ROOF_TINTS: Array[Color] = [
	Color(1.0, 1.0, 1.0),
	Color(0.92, 0.78, 0.68),
	Color(0.82, 0.86, 0.7),
	Color(1.04, 0.9, 0.76),
]


static func recipe_for(surface_id: StringName) -> Dictionary:
	var seed := absi(String(surface_id).hash())
	return {
		"seed": seed,
		"wall_roll": seed % 3,
		"roof_roll": int(seed / 5) % 3,
		"wall_tint": WALL_TINTS[int(seed / 3) % WALL_TINTS.size()],
		"roof_tint": ROOF_TINTS[int(seed / 11) % ROOF_TINTS.size()],
		"uv_offset": Vector3(
			float(int(seed / 7) % 4) * 0.25, float(int(seed / 13) % 4) * 0.25, 0.0
		),
	}


static func classify(material: BaseMaterial3D) -> StringName:
	if material == null:
		return &""
	var haystack := String(material.resource_name).to_lower()
	if material.albedo_texture != null:
		haystack += " " + material.albedo_texture.resource_path.to_lower()
	if haystack.contains("claytile") or haystack.contains("roof_tile"):
		return FAMILY_TILE
	if haystack.contains("woodshingle"):
		return FAMILY_SHINGLE
	if haystack.contains("reedthatch") or haystack.contains("thatch"):
		return FAMILY_THATCH
	if haystack.contains("limerender"):
		return FAMILY_RENDER
	if haystack.contains("limewash"):
		return FAMILY_LIMEWASH
	if haystack.contains("limestonerubble") or haystack.contains("limestoneplinth"):
		return FAMILY_RUBBLE
	if haystack.contains("craftbodalog") or haystack.contains("merchanttimberlog"):
		return FAMILY_LOG
	return &""


static func stems_for(family: StringName) -> Array[String]:
	match family:
		FAMILY_TILE:
			return TILE_STEMS
		FAMILY_SHINGLE:
			return SHINGLE_STEMS
		FAMILY_THATCH:
			return THATCH_STEMS
		FAMILY_RUBBLE:
			return RUBBLE_STEMS
		FAMILY_RENDER:
			return RENDER_STEMS
		FAMILY_LIMEWASH:
			return LIMEWASH_STEMS
		FAMILY_LOG:
			return LOG_STEMS
		FAMILY_ASHLAR:
			return ASHLAR_STEMS
		FAMILY_PLANK:
			return PLANK_STEMS
		FAMILY_DAUB:
			return DAUB_STEMS
		FAMILY_BRICK:
			return BRICK_STEMS
		FAMILY_STRAW:
			return STRAW_STEMS
		FAMILY_SOOT:
			return SOOT_STEMS
		FAMILY_GABLE_BOARD:
			return GABLE_BOARD_STEMS
		FAMILY_LOGWALL:
			return LOGWALL_STEMS
		_:
			return []


static func albedo_path(family: StringName, roll: int) -> String:
	var stems := stems_for(family)
	if stems.is_empty():
		return ""
	return "%s/%s_albedo.png" % [TEX_DIR, stems[posmod(roll, stems.size())]]


static func normal_path(family: StringName, roll: int) -> String:
	var stems := stems_for(family)
	if stems.is_empty():
		return ""
	return "%s/%s_normal.png" % [TEX_DIR, stems[posmod(roll, stems.size())]]


static func orm_path(family: StringName, roll: int) -> String:
	var stems := stems_for(family)
	if stems.is_empty():
		return ""
	return "%s/%s_orm.png" % [TEX_DIR, stems[posmod(roll, stems.size())]]


static func is_roof_family(family: StringName) -> bool:
	return (
		family == FAMILY_TILE
		or family == FAMILY_SHINGLE
		or family == FAMILY_THATCH
		or family == FAMILY_STRAW
	)


## Library families for an authored material key, or [] when the key has no
## surface set (callers then keep the documented procedural fallback).
static func library_families(material_key: StringName, is_roof: bool) -> Array:
	var table: Dictionary = ROOF_MATERIAL_FAMILIES if is_roof else WALL_MATERIAL_FAMILIES
	return table.get(material_key, [])


## Deterministic stem for one building surface. The roll hashes
## (map_seed, surface_id, material key) so the same map always looks the same
## while a different map seed reshuffles which buildings share a stem.
static func library_stem(
	material_key: StringName, is_roof: bool, surface_id: StringName, map_seed: int = 0
) -> String:
	var families := library_families(material_key, is_roof)
	if families.is_empty():
		return ""
	var families_for_surface := families
	if not is_roof and material_key == &"limestone" and _is_ashlar_surface(surface_id):
		families_for_surface = [FAMILY_ASHLAR]
	var candidates: Array[String] = []
	for family in families_for_surface:
		candidates.append_array(stems_for(family))
	var roll := absi(("%d:%s:%s" % [map_seed, surface_id, material_key]).hash())
	return candidates[roll % candidates.size()]


static func family_of_stem(stem: String) -> StringName:
	for family in [
		FAMILY_GABLE_BOARD, FAMILY_LOGWALL, FAMILY_TILE, FAMILY_SHINGLE, FAMILY_THATCH,
		FAMILY_RUBBLE, FAMILY_RENDER, FAMILY_LIMEWASH, FAMILY_LOG, FAMILY_ASHLAR,
		FAMILY_PLANK, FAMILY_DAUB, FAMILY_BRICK, FAMILY_STRAW, FAMILY_SOOT,
	]:
		if stems_for(family).has(stem):
			return family
	return &""


static func stem_plate_metres(stem: String) -> Vector2:
	if STEM_PLATE_METRES.has(stem):
		return STEM_PLATE_METRES[stem]
	return FAMILY_PLATE_METRES.get(family_of_stem(stem), Vector2(2.0, 2.0))


static func stem_normal_scale(stem: String) -> float:
	return float(FAMILY_NORMAL_SCALE.get(family_of_stem(stem), 1.0))


static func stem_paths(stem: String) -> Dictionary:
	return {
		"albedo": "%s/%s_albedo.png" % [TEX_DIR, stem],
		"normal": "%s/%s_normal.png" % [TEX_DIR, stem],
		"orm": "%s/%s_orm.png" % [TEX_DIR, stem],
	}


static func _is_ashlar_surface(surface_id: StringName) -> bool:
	var id := String(surface_id).to_lower()
	for hint in ASHLAR_SURFACE_HINTS:
		if id.contains(hint):
			return true
	return false


## Dress an instantiated kit house. Overrides stay on the instance so the
## shared imported materials are not recolored for every other clone.
static func apply(model: Node, surface_id: StringName) -> Dictionary:
	var recipe := recipe_for(surface_id)
	if model == null:
		return recipe
	model.set_meta(&"house_surface_recipe", recipe)
	_apply_node(model, recipe)
	return recipe


static func _apply_node(model: Node, recipe: Dictionary) -> void:
	var mesh_instance := model as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		var mesh := mesh_instance.mesh
		for surface in mesh.get_surface_count():
			var source := mesh.surface_get_material(surface) as BaseMaterial3D
			if source == null:
				continue
			mesh_instance.set_surface_override_material(surface, _vary_material(source, recipe))
	for child in model.get_children():
		_apply_node(child, recipe)


static func _vary_material(source: BaseMaterial3D, recipe: Dictionary) -> BaseMaterial3D:
	var material := source.duplicate() as BaseMaterial3D
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = false
	var family := classify(source)
	if family == &"":
		return material
	var roll: int = recipe["roof_roll"] if is_roof_family(family) else recipe["wall_roll"]
	var tint: Color = recipe["roof_tint"] if is_roof_family(family) else recipe["wall_tint"]
	var albedo := albedo_path(family, roll)
	if not albedo.is_empty() and ResourceLoader.exists(albedo):
		material.albedo_texture = load(albedo)
	var normal := normal_path(family, roll)
	if (
		material is StandardMaterial3D
		and not normal.is_empty()
		and ResourceLoader.exists(normal)
	):
		var standard := material as StandardMaterial3D
		standard.normal_enabled = true
		standard.normal_texture = load(normal)
	# AR-03: packed ORM gives the kit GLBs varying specular response too.
	var orm := orm_path(family, roll)
	if not orm.is_empty() and ResourceLoader.exists(orm):
		var orm_texture: Texture2D = load(orm)
		material.roughness_texture = orm_texture
		material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		material.roughness = 1.0
		material.ao_enabled = true
		material.ao_texture = orm_texture
		material.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.albedo_color = tint
	material.uv1_offset = recipe["uv_offset"]
	return material
