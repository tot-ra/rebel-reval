class_name SpiritUndress
extends RefCounted
## Spirit sight shows the soul, not the dress: while sight is open every adult census body is
## drawn unclothed (docs/SYSTEMS/SPIRIT_SIGHT.md).
##
## A crowd body bakes its outfit into one mesh with no skin under it, so stripping cloth at
## runtime shows a hole. Each adult citizen body therefore ships a build-time nude twin,
## assets/characters/realistic/<body>/layers/nude.glb (build_human.py --nude-only), skinned to
## the same skeleton. Undressing hides the baked body and every mounted garment and mounts that
## twin; restoring unmounts it and shows exactly what was visible before.
##
## Minor body variants are refused by name. The 18-year-old apprentice is also explicitly
## protected as the player character; heroes (Tier 1) have no nude layer and stay dressed.

const NUDE_PATH := "res://assets/characters/realistic/%s/layers/nude.glb"
const NUDE_ID := &"spirit_nude"
const GARMENT_PREFIX := "Garment_"
const MINOR_MARKERS: Array[String] = ["child", "apprentice", "boy", "girl"]
const HERO_ID := &"char.apprentice"
const META_VISIBLE := &"spirit_undress_visible"

## Nude layer path -> PackedScene, or null for a body that has none.
static var _scenes: Dictionary = {}


## The nude twin of this rig's body, or null when it may not or cannot be undressed.
static func nude_scene(rig: SharedCharacterRig) -> PackedScene:
	if is_protected(rig):
		return null
	var body := rig.body_basename()
	if body.is_empty():
		return null
	var path := NUDE_PATH % body
	if not _scenes.has(path):
		_scenes[path] = load(path) if ResourceLoader.exists(path) else null
	return _scenes[path]


## Minor body variants and the player character remain protected by every undress system.
static func is_protected(rig: SharedCharacterRig) -> bool:
	if rig.name == &"PlayerRig" or rig.variant_id() == HERO_ID:
		return true
	var lowered := (rig.body_basename() + " " + String(rig.variant_id())).to_lower()
	for marker in MINOR_MARKERS:
		if lowered.contains(marker):
			return true
	return false


static func eligible(rig: SharedCharacterRig) -> bool:
	return nude_scene(rig) != null


static func is_undressed(rig: SharedCharacterRig) -> bool:
	return rig.has_garment(NUDE_ID)


## Idempotent: calling it again also hides garments mounted since the last call.
static func undress(rig: SharedCharacterRig) -> void:
	var scene := nude_scene(rig)
	if scene == null:
		return
	if not rig.has_garment(NUDE_ID) and not rig.equip_garment(NUDE_ID, scene):
		return
	var own_prefix := "%s%s_" % [GARMENT_PREFIX, NUDE_ID]
	for mesh_instance in _dressed_meshes(rig):
		if String(mesh_instance.name).begins_with(own_prefix):
			continue
		if not mesh_instance.has_meta(META_VISIBLE):
			mesh_instance.set_meta(META_VISIBLE, mesh_instance.visible)
		mesh_instance.visible = false


static func restore(rig: SharedCharacterRig) -> void:
	if rig.has_garment(NUDE_ID):
		rig.unequip_garment(NUDE_ID)
	for mesh_instance in _dressed_meshes(rig):
		if mesh_instance.has_meta(META_VISIBLE):
			mesh_instance.visible = bool(mesh_instance.get_meta(META_VISIBLE))
			mesh_instance.remove_meta(META_VISIBLE)


## The baked body meshes of the imported model plus every mounted garment; held items
## (weapons, shields, tools) are attachments, not dress, and stay.
static func _dressed_meshes(rig: SharedCharacterRig) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	var skeleton := rig.skeleton()
	if skeleton == null:
		return found
	for child: Node in skeleton.get_children():
		var mesh_instance := child as MeshInstance3D
		if mesh_instance != null and mesh_instance.skin != null:
			found.append(mesh_instance)
	return found
