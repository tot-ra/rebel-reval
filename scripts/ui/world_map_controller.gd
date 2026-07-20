class_name WorldMapController
extends Node

## Persistent world/district map entry point on every playable player host (P1-031).
## Click-to-travel through DoorNavigator is P1-031a.
## Keyboard/gamepad focus travel is P1-031b.

const TOGGLE_ACTION := &"toggle_world_map"

var _overlay: WorldMapOverlay
## Last planned go_to_scene args for headless verification (scene_id + spawn_id).
var last_travel_request: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = WorldMapOverlay.new()
	_overlay.name = "WorldMapOverlay"
	_overlay.visible = false
	add_child(_overlay)
	_overlay.closed.connect(_on_overlay_closed)
	_overlay.travel_requested.connect(_on_travel_requested)


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


## Plan and optionally execute a district-map travel. Tests pass execute=false to
## record go_to_scene args without changing the SceneTree.
func travel_to_scene(destination_scene_id: StringName, execute: bool = true) -> Dictionary:
	last_travel_request.clear()
	if _overlay == null:
		return {}
	var plan := _overlay.plan_travel_to(destination_scene_id)
	if plan.is_empty():
		# WHY: prefer the overlay's configured scene so headless plans stay stable
		# even when SceneTree.current_scene is a test harness root.
		var from_id := _overlay.get_current_scene_id()
		if from_id.is_empty():
			from_id = _resolve_current_scene_id()
		plan = WorldMapGraph.plan_travel(from_id, destination_scene_id)
	if plan.is_empty():
		return {}
	last_travel_request = plan.duplicate(true)
	if execute:
		DoorNavigator.go_to_scene(plan["scene_id"], plan["spawn_id"])
		close()
	return last_travel_request


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


func _on_travel_requested(scene_id: StringName, spawn_id: StringName) -> void:
	last_travel_request = {
		"scene_id": scene_id,
		"spawn_id": spawn_id,
	}
	DoorNavigator.go_to_scene(scene_id, spawn_id)
	close()
