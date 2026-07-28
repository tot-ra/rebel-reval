class_name MapViewChestModels
extends RefCounted

## Selects one authored chest construction by rrmap style_variant. Wealth and
## storage purpose change the whole silhouette and hardware rather than tinting a
## shared placeholder; map-owned footprint, collision, and navigation stay intact.

const PropStyleVariants := preload("res://scripts/map/map_prop_style_variants.gd")

const SCENE_PATH_BY_VARIANT: Dictionary = {
	PropStyleVariants.CHEST_PLAIN_COFFER: "res://assets/props/furniture/chest_poor_household.glb",
	PropStyleVariants.CHEST_BURGHER: "res://assets/props/furniture/chest_burgher_household.glb",
	PropStyleVariants.CHEST_MERCHANT_STRONGBOX: "res://assets/props/furniture/chest_merchant_strongbox.glb",
}
const MODEL_NAME_BY_VARIANT: Dictionary = {
	PropStyleVariants.CHEST_PLAIN_COFFER: "PlainCofferModel",
	PropStyleVariants.CHEST_BURGHER: "BurgherChestModel",
	PropStyleVariants.CHEST_MERCHANT_STRONGBOX: "MerchantStrongboxModel",
}
const DEFAULT_VARIANT := PropStyleVariants.CHEST_BURGHER


static func add_model(parent: Node3D, prop: Dictionary = {}) -> Node3D:
	var variant := StringName(prop.get("style_variant", DEFAULT_VARIANT))
	if variant.is_empty():
		variant = DEFAULT_VARIANT
	assert(SCENE_PATH_BY_VARIANT.has(variant), "Chest style_variant must be validated before map assembly")
	var scene := load(String(SCENE_PATH_BY_VARIANT[variant])) as PackedScene
	assert(scene != null, "Chest GLB must be imported before map assembly: %s" % String(variant))
	var model := scene.instantiate() as Node3D
	assert(model != null, "Chest GLB root must be Node3D: %s" % String(variant))
	model.name = String(MODEL_NAME_BY_VARIANT[variant])
	model.set_meta(&"production_chest_model", true)
	model.set_meta(&"chest_style_variant", variant)
	parent.add_child(model)
	return model
