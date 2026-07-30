class_name MapViewMedievalHandToolModels
extends RefCounted

## Reusable authored hand tools for forge and farm dressing. Gameplay footprints
## stay map-owned; these GLBs provide only historically legible view geometry.

const SCENE_PATHS: Dictionary = {
	MapTypes.PROP_KIND_BLACKSMITH_TONGS: "res://assets/props/tools/blacksmith_tongs.glb",
	MapTypes.PROP_KIND_BLACKSMITH_HAMMER: "res://assets/props/tools/blacksmith_hammer.glb",
	MapTypes.PROP_KIND_BLACKSMITH_PUNCH: "res://assets/props/tools/blacksmith_punch.glb",
	MapTypes.PROP_KIND_PITCHFORK: "res://assets/props/tools/pitchfork.glb",
	MapTypes.PROP_KIND_SCYTHE: "res://assets/props/tools/scythe.glb",
	MapTypes.PROP_KIND_SICKLE: "res://assets/props/tools/sickle.glb",
	MapTypes.PROP_KIND_RAKE: "res://assets/props/tools/rake.glb",
	MapTypes.PROP_KIND_WOODEN_SHOVEL: "res://assets/props/tools/wooden_shovel.glb",
}
const NODE_NAMES: Dictionary = {
	MapTypes.PROP_KIND_BLACKSMITH_TONGS: "BlacksmithTongsModel",
	MapTypes.PROP_KIND_BLACKSMITH_HAMMER: "BlacksmithHammerModel",
	MapTypes.PROP_KIND_BLACKSMITH_PUNCH: "BlacksmithPunchModel",
	MapTypes.PROP_KIND_PITCHFORK: "PitchforkModel",
	MapTypes.PROP_KIND_SCYTHE: "ScytheModel",
	MapTypes.PROP_KIND_SICKLE: "SickleModel",
	MapTypes.PROP_KIND_RAKE: "RakeModel",
	MapTypes.PROP_KIND_WOODEN_SHOVEL: "WoodenShovelModel",
}


static func add_model(parent: Node3D, kind: StringName) -> Node3D:
	var scene_path := String(SCENE_PATHS.get(kind, ""))
	assert(not scene_path.is_empty(), "Medieval hand-tool kind must have an authored GLB")
	var packed := load(scene_path) as PackedScene
	assert(packed != null, "%s must be imported before hand tools are assembled" % scene_path)
	var model := packed.instantiate() as Node3D
	model.name = String(NODE_NAMES.get(kind, "MedievalHandToolModel"))
	model.set_meta(&"production_medieval_hand_tool", true)
	parent.add_child(model)
	return model
