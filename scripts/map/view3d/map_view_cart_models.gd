class_name MapViewCartModels
extends RefCounted

## Shared access to the authored medieval wooden cart GLB. Both street `cart` and
## rural `farm_cart` prop kinds reuse the same asset so wagon quality cannot drift
## between Lower Town yards and foreland service plots.

const WOODEN_CART_SCENE_PATH := "res://assets/props/vehicles/wooden_cart.glb"


static func add_model(parent: Node3D) -> Node3D:
	var scene := load(WOODEN_CART_SCENE_PATH) as PackedScene
	assert(scene != null, "Wooden cart GLB must be imported before map assembly")
	var model := scene.instantiate() as Node3D
	assert(model != null, "Wooden cart GLB root must be Node3D")
	model.name = "WoodenCartModel"
	model.set_meta(&"production_cart_model", true)
	parent.add_child(model)
	return model
