class_name WorldMapController
extends Node

## Persistent world/district map entry point on every playable player host (P1-031).

const TOGGLE_ACTION := &"toggle_world_map"

var _overlay: WorldMapOverlay


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = WorldMapOverlay.new()
	_overlay.name = "WorldMapOverlay"
	_overlay.visible = false
	add_child(_overlay)
	_overlay.closed.connect(_on_overlay_closed)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_toggle_event(event):
		return
	get_viewport().set_input_as_handled()
	toggle()


func is_open() -> bool:
	return _overlay != null and _overlay.is_open()


func open() -> void:
	if _overlay == null or _overlay.is_open():
		return
	_close_sibling_overlays()
	_overlay.configure(_resolve_current_scene_id())
	_overlay.open()


func close() -> void:
	if _overlay != null and _overlay.is_open():
		_overlay.close()


func toggle() -> void:
	if _overlay == null:
		return
	if _overlay.is_open():
		close()
	else:
		open()


func get_overlay() -> WorldMapOverlay:
	return _overlay


func _resolve_current_scene_id() -> StringName:
	var tree := get_tree()
	if tree == null:
		return &""
	return WorldMapGraph.resolve_current_scene_id(tree.current_scene)


func _close_sibling_overlays() -> void:
	var inventory := get_parent().get_node_or_null("InventoryController") as InventoryController
	if inventory != null:
		inventory.close()
	var journal := get_parent().get_node_or_null("JournalController") as JournalController
	if journal != null:
		journal.close()


func _is_toggle_event(event: InputEvent) -> bool:
	if not event.is_pressed() or event.is_echo():
		return false
	if event.is_action(TOGGLE_ACTION):
		return event.is_action_pressed(TOGGLE_ACTION)
	return false


func _on_overlay_closed() -> void:
	pass
