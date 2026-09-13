extends RefCounted
class_name CharacterWardrobe

const SLOTS: Array[String] = ["torso", "outerwear", "legs", "feet", "hands", "head", "back"]
var _outfits: Dictionary = {}
var _original_visibility: Dictionary = {}

func equip(rig: SharedCharacterRig, wearable: CharacterWearable) -> bool:
	if wearable == null or wearable.stable_id.is_empty() or wearable.scene == null:
		return false
	if wearable.slot not in SLOTS or wearable.fitted_body.is_empty():
		return false
	if wearable.fitted_body != rig.body_basename():
		return false
	# Reject misspelled coverage before replacing the current outfit.
	for prefix: StringName in wearable.covered_meshes:
		if not (String(prefix).begins_with("Clothing_") or String(prefix).begins_with("Anatomy_") or String(prefix).begins_with("Hair_")):
			return false
		var found := false
		for node: Node in rig.find_children("*", "MeshInstance3D", true, false):
			if _body_mesh_name(node).begins_with(String(prefix)):
				found = true
				break
		if not found:
			return false
	var garment_id := StringName("wearable_%s" % wearable.slot)
	if not rig.equip_garment(garment_id, wearable.scene):
		return false
	_outfits[garment_id] = wearable
	refresh(rig)
	return true

func forget(garment_id: StringName, rig: SharedCharacterRig) -> void:
	_outfits.erase(garment_id)
	refresh(rig)

func equipped(slot: StringName) -> CharacterWearable:
	return _outfits.get(StringName("wearable_%s" % slot)) as CharacterWearable

func refresh(rig: SharedCharacterRig) -> void:
	# Recompute the union: removing one layer must not uncover a region still
	# covered by another. LOD switching must never resurrect the default outfit.
	for node: Node in rig.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var body_name := _body_mesh_name(mesh)
		var covered := false
		for wearable: CharacterWearable in _outfits.values():
			for prefix: StringName in wearable.covered_meshes:
				if body_name.begins_with(String(prefix)):
					covered = true
		if covered:
			if not _original_visibility.has(mesh):
				_original_visibility[mesh] = mesh.visible
			mesh.visible = false
		elif _original_visibility.has(mesh):
			mesh.visible = _original_visibility[mesh]
			_original_visibility.erase(mesh)

static func _body_mesh_name(node: Node) -> String:
	var mesh_name := String(node.name)
	for prefix: String in ["LOD1_", "LOD2_"]:
		mesh_name = mesh_name.trim_prefix(prefix)
	return mesh_name
