class_name MapViewStorageFurnitureModels
extends RefCounted

## Historically tiered storage furniture for 1343 Reval. The default remains an
## open rack; closed cupboards require an explicit social/context variant so a
## rare elite armarium cannot leak into ordinary households through random seeds.

const COMMON_OPEN := &"shelf.common_open"
const BURGHER_CUPBOARD := &"shelf.burgher_cupboard"
const ELITE_ARMARIUM := &"shelf.elite_armarium"

const DEFAULT_VARIANT := COMMON_OPEN
const SCENE_PATHS: Dictionary = {
	COMMON_OPEN: "res://assets/props/furniture/medieval_storage/common_open_rack.glb",
	BURGHER_CUPBOARD: "res://assets/props/furniture/medieval_storage/burgher_cupboard.glb",
	ELITE_ARMARIUM: "res://assets/props/furniture/medieval_storage/elite_armarium.glb",
}


static func add_model(parent: Node3D, prop: Dictionary = {}) -> Node3D:
	var variant := StringName(prop.get("style_variant", DEFAULT_VARIANT))
	if variant.is_empty():
		variant = DEFAULT_VARIANT
	assert(SCENE_PATHS.has(variant), "Storage furniture variant must pass the map allowlist")
	var scene_path := String(SCENE_PATHS[variant])
	var scene := load(scene_path) as PackedScene
	assert(
		scene != null, "Storage furniture GLB must be imported before map assembly: %s" % scene_path
	)
	var model := scene.instantiate() as Node3D
	assert(model != null, "Storage furniture GLB root must be Node3D")
	model.name = "MedievalStorageModel"
	model.set_meta(&"production_storage_furniture", true)
	model.set_meta(&"storage_furniture_variant", variant)
	model.set_meta(&"stores_folded_textiles", true)
	model.set_meta(&"has_modern_hanging_rail", false)
	parent.add_child(model)
	return model
