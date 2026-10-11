class_name CitizenWardrobe
extends RefCounted

## Layered dress of a census resident (docs/SYSTEMS/CITIZEN_WARDROBE.md). The
## body ships its base outfit baked in; this mounts the extra layers the census
## wardrobe rules chose (`wear` in content/world/reval_city/citizens.json):
## hoods, coifs, veils, aprons, aketon, mail, surcoat, helmets, keys, beads,
## scrips and sacks. Each layer is a skinned GLB fitted to that very body
## (assets/characters/realistic/<body>/layers/<layer>.glb), so it deforms with
## the rig like the baked clothes, and is dyed with the resident's `wear_dye`.

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

## Layer path -> PackedScene, or null for a layer the body was not fitted with.
static var _scenes: Dictionary = {}


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
		if dyes.has(layer):
			var rgb: Array = dyes[layer]
			dye_layer(rig, layer, Color(float(rgb[0]), float(rgb[1]), float(rgb[2])))
	return worn


static func layer_scene(body: String, layer: String) -> PackedScene:
	var path := LAYER_PATH % [body, layer]
	if not _scenes.has(path):
		_scenes[path] = load(path) if ResourceLoader.exists(path) else null
		if _scenes[path] == null:
			push_warning("CitizenWardrobe: %s has no %s layer" % [body, layer])
	return _scenes[path]


## Tints the layer's own cloth (material `<body>_<layer>`) and leaves its other
## parts alone (the sack's rope, a hem binding in another family).
static func dye_layer(rig: SharedCharacterRig, layer: String, tint: Color) -> void:
	var skeleton := rig.skeleton()
	if skeleton == null:
		return
	var prefix := "Garment_%s%s_" % [GARMENT_PREFIX, layer]
	var suffix := "_" + String(CLOTH_KEY.get(layer, layer))
	for child: Node in skeleton.get_children():
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		if not String(mesh_instance.name).begins_with(prefix):
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_active_material(surface) as BaseMaterial3D
			if material == null or not material.resource_name.ends_with(suffix):
				continue
			var dyed := material.duplicate() as BaseMaterial3D
			dyed.albedo_color = tint
			mesh_instance.set_surface_override_material(surface, dyed)
