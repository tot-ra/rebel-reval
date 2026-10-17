class_name WorldItemView
extends Node3D

## Mirrors a world item onto the 3D view. The yellow contour on hover is drawn by
## InteractableWorldIndicator on the item model; there is no floor marker.

var _item_root: Node3D


func configure(item_scene: PackedScene, logic_position: Vector2, cell_size: int) -> void:
	for child in get_children():
		child.queue_free()
	_item_root = null

	if item_scene != null:
		_item_root = item_scene.instantiate() as Node3D
		if _item_root != null:
			add_child(_item_root)

	MapViewBridge.sync_actor(self, logic_position, cell_size)


## The model subtree only, so the contour follows the item silhouette.
func get_item_visual_root() -> Node3D:
	return _item_root if is_instance_valid(_item_root) else null


func sync_logic_position(logic_position: Vector2, cell_size: int) -> void:
	MapViewBridge.sync_actor(self, logic_position, cell_size)


## World-space bounds of the item model, used for cursor picking in screen space.
## Empty (size zero) when the scene has no mesh.
func get_world_aabb() -> AABB:
	var root := get_item_visual_root()
	var box := AABB()
	var first := true
	if root == null:
		return box
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		var part := mesh.global_transform * mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box
