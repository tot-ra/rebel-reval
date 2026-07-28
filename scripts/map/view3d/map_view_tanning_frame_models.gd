class_name MapViewTanningFrameModels
extends RefCounted

## Shared access to the authored hide stretching frame. Runtime placement remains
## owned by the rrmap prop anchor and footprint; this helper only supplies visuals.

const TANNING_FRAME_SCENE_PATH := "res://assets/props/crafts/tanning_frame.glb"


static func add_model(parent: Node3D) -> Node3D:
	var scene := load(TANNING_FRAME_SCENE_PATH) as PackedScene
	assert(scene != null, "Tanning frame GLB must be imported before map assembly")
	var model := scene.instantiate() as Node3D
	assert(model != null, "Tanning frame GLB root must be Node3D")
	model.name = "TanningFrameModel"
	model.set_meta(&"production_tanning_frame_model", true)
	parent.add_child(model)
	return model
