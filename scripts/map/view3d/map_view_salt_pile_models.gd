class_name MapViewSaltPileModels
extends RefCounted

## Shared access to the authored salt pile. The rrmap still owns the
## one-cell anchor and footprint; this helper replaces only the visual geometry.

const SALT_PILE_SCENE_PATH := "res://assets/props/crafts/salt_pile.glb"

static func add_model(parent: Node3D) -> Node3D:
	var scene := load(SALT_PILE_SCENE_PATH) as PackedScene
	assert(scene != null, "Salt pile GLB must be imported before map assembly")
	var model := scene.instantiate() as Node3D
	assert(model != null, "Salt pile GLB root must be Node3D")
	model.name = "SaltPileModel"
	model.set_meta(&"production_salt_pile_model", true)
	parent.add_child(model)
	return model
