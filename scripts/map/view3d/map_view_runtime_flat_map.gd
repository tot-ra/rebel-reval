class_name MapViewRuntimeFlatMap
extends RefCounted

## Hides authored 2D map render nodes during MapViewRuntime install while keeping
## logic-plane collision and navigation active under the 3D view.


static func hide_visuals(bootstrap: Dictionary) -> void:
	# Buildings and props are hosted under Actors so their 2D collision remains
	# Y-sorted with the player. Hide the render nodes explicitly; CanvasItem
	# visibility does not disable the StaticBody2D collision used by gameplay.
	var assembled: Dictionary = bootstrap.get("assembled", {})
	for key: String in ["terrain", "buildings", "props", "view_landmarks"]:
		var value: Variant = assembled.get(key)
		if value is CanvasItem:
			(value as CanvasItem).visible = false
		elif value is Array:
			for item: Variant in value as Array:
				_hide_object(item)


static func bind_streamed_visual_hiding(bootstrap: Dictionary) -> void:
	var assembled: Dictionary = bootstrap.get("assembled", {})
	var streamer: Variant = assembled.get("object_streamer")
	if streamer == null or not streamer.has_signal(&"object_loaded"):
		return
	if not streamer.object_loaded.is_connected(_on_streamed_object_loaded):
		streamer.object_loaded.connect(_on_streamed_object_loaded)
	for object_id in streamer.loaded_object_ids():
		_hide_object(streamer.loaded_instance(object_id))


static func _on_streamed_object_loaded(_handle: Dictionary, instance: Node) -> void:
	_hide_object(instance)


static func _hide_object(item: Variant) -> void:
	if item == null or not item is Node:
		return
	var node := item as Node
	if node is StaticBody2D:
		var visuals := node.get_node_or_null("Visuals") as CanvasItem
		if visuals != null:
			visuals.visible = false
		return
	if node is CanvasItem:
		(node as CanvasItem).visible = false
