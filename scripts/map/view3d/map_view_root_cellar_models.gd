class_name MapViewRootCellarModels
extends RefCounted

## Shared access to the authored turf-covered root cellar. Runtime loading avoids
## a clean-clone bootstrap cycle where GDScript parses before Godot imports the GLB.

const ROOT_CELLAR_SCENE_PATH := "res://assets/props/environment/root_cellar_mound.glb"


static func add_model(parent: Node3D) -> Node3D:
	var scene := load(ROOT_CELLAR_SCENE_PATH) as PackedScene
	assert(scene != null, "Root cellar mound GLB must be imported before map assembly")
	var model := scene.instantiate() as Node3D
	assert(model != null, "Root cellar mound GLB root must be Node3D")
	model.name = "RootCellarMoundModel"
	model.set_meta(&"production_root_cellar_model", true)
	parent.add_child(model)
	return model
