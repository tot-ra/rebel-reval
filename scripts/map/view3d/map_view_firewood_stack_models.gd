class_name MapViewFirewoodStackModels
extends RefCounted

## Shared access to the authored yard firewood stack. The rrmap still owns the
## two-cell anchor and footprint; this helper replaces only the visual geometry.

const SCENE_PATH := "res://assets/props/crafts/yard_firewood_stack.glb"


static func add_model(parent: Node3D) -> Node3D:
	var scene := load(SCENE_PATH) as PackedScene
	assert(scene != null, "Yard firewood stack GLB must be imported before map assembly")
	var model := scene.instantiate() as Node3D
	assert(model != null, "Yard firewood stack GLB root must be Node3D")
	model.name = "YardFirewoodStackModel"
	model.set_meta(&"production_yard_firewood_stack_model", true)
	parent.add_child(model)
	return model
