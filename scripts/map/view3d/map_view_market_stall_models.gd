class_name MapViewMarketStallModels
extends RefCounted

## Shared access to the authored portable market stall. Every `stall` prop keeps
## its map-owned footprint and gameplay behavior while reusing one coherent model.

const MARKET_STALL_SCENE_PATH := "res://assets/props/market/market_stall.glb"


static func add_model(parent: Node3D) -> Node3D:
	var scene := load(MARKET_STALL_SCENE_PATH) as PackedScene
	assert(scene != null, "Market stall GLB must be imported before map assembly")
	var model := scene.instantiate() as Node3D
	assert(model != null, "Market stall GLB root must be Node3D")
	model.name = "MarketStallModel"
	model.set_meta(&"production_market_stall_model", true)
	parent.add_child(model)
	return model
