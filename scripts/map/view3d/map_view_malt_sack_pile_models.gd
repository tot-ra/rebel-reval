class_name MapViewMaltSackPileModels
extends RefCounted

## Shared access to the authored brewery malt sacks. The rrmap still owns the
## one-cell anchor and footprint; this helper replaces only the visual geometry.

const MALT_SACK_PILE_SCENE_PATH := "res://assets/props/crafts/malt_sack_pile.glb"


static func add_model(parent: Node3D) -> Node3D:
	var scene := load(MALT_SACK_PILE_SCENE_PATH) as PackedScene
	assert(scene != null, "Malt sack pile GLB must be imported before map assembly")
	var model := scene.instantiate() as Node3D
	assert(model != null, "Malt sack pile GLB root must be Node3D")
	model.name = "MaltSackPileModel"
	model.set_meta(&"production_malt_sack_pile_model", true)
	parent.add_child(model)
	return model
