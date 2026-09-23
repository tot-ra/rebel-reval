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


static func is_roof_family(family: StringName) -> bool:
	return family == FAMILY_TILE or family == FAMILY_SHINGLE or family == FAMILY_THATCH


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
	material.albedo_color = tint
	material.uv1_offset = recipe["uv_offset"]
	return material
