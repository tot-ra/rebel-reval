class_name MapViewMedievalHandToolModels
extends RefCounted

## Reusable authored hand tools for forge and farm dressing. Gameplay footprints
## stay map-owned; these GLBs provide only historically legible view geometry.

const TOOL_GLB_ROOT := "res://assets/props/tools/"

const SCENE_PATHS: Dictionary = {
	MapTypes.PROP_KIND_BLACKSMITH_TONGS: TOOL_GLB_ROOT + "blacksmith_tongs/blacksmith_tongs.glb",
	MapTypes.PROP_KIND_BLACKSMITH_HAMMER: TOOL_GLB_ROOT + "blacksmith_hammer/blacksmith_hammer.glb",
	MapTypes.PROP_KIND_BLACKSMITH_PUNCH: TOOL_GLB_ROOT + "blacksmith_punch/blacksmith_punch.glb",
	MapTypes.PROP_KIND_PITCHFORK: TOOL_GLB_ROOT + "pitchfork/pitchfork.glb",
	MapTypes.PROP_KIND_SCYTHE: TOOL_GLB_ROOT + "scythe/scythe.glb",
	MapTypes.PROP_KIND_SICKLE: TOOL_GLB_ROOT + "sickle/sickle.glb",
	MapTypes.PROP_KIND_RAKE: TOOL_GLB_ROOT + "rake/rake.glb",
	MapTypes.PROP_KIND_WOODEN_SHOVEL: TOOL_GLB_ROOT + "wooden_shovel/wooden_shovel.glb",
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
