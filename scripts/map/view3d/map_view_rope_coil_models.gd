class_name MapViewRopeCoilModels
extends RefCounted

## Shared access to the authored rope coil. Runtime placement remains owned by
## the rrmap anchor and one-cell footprint; this helper replaces only visuals.

const ROPE_COIL_SCENE_PATH := "res://assets/props/crafts/rope_coil.glb"


static func add_model(parent: Node3D) -> Node3D:
	var scene := load(ROPE_COIL_SCENE_PATH) as PackedScene
	assert(scene != null, "Rope coil GLB must be imported before map assembly")
	var model := scene.instantiate() as Node3D
	assert(model != null, "Rope coil GLB root must be Node3D")
	model.name = "RopeCoilModel"
	model.set_meta(&"production_rope_coil_model", true)
	parent.add_child(model)
	return model
