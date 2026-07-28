class_name MapViewFishingNetModels
extends RefCounted

## Shared access to the authored fishing net rack. The rrmap still owns placement,
## footprint, collision, and navigation; this helper supplies visual geometry only.

const FISHING_NETS_SCENE_PATH := "res://assets/props/crafts/fishing_nets.glb"


static func add_model(parent: Node3D) -> Node3D:
	var scene := load(FISHING_NETS_SCENE_PATH) as PackedScene
	assert(scene != null, "Fishing nets GLB must be imported before map assembly")
	var model := scene.instantiate() as Node3D
	assert(model != null, "Fishing nets GLB root must be Node3D")
	model.name = "FishingNetsModel"
	model.set_meta(&"production_fishing_nets_model", true)
	parent.add_child(model)
	return model
