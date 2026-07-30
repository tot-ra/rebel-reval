class_name MapViewSmithyCharcoalStorageModels
extends RefCounted

## Shared access to Kalev's authored charcoal stock. The rrmap still owns the
## one-cell anchor and footprint; this helper replaces only coal_store visuals.

const SCENE_PATH := "res://assets/props/forge/smithy_charcoal_storage.glb"
const PROP_ID := &"coal_store"


static func applies_to(prop: Dictionary) -> bool:
	return StringName(prop.get("id", &"")) == PROP_ID


static func add_model(parent: Node3D) -> Node3D:
	var scene := load(SCENE_PATH) as PackedScene
	assert(scene != null, "Smithy charcoal storage GLB must be imported before map assembly")
	var model := scene.instantiate() as Node3D
	assert(model != null, "Smithy charcoal storage GLB root must be Node3D")
	model.name = "SmithyCharcoalStorageModel"
	model.set_meta(&"production_smithy_charcoal_storage_model", true)
	parent.add_child(model)
	return model
