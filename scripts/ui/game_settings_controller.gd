class_name GameSettingsController
extends Node

## Opens the in-game settings overlay on Esc when no other modal surface is active.

const OverlayScript := preload("res://scripts/ui/game_settings_overlay.gd")

var _overlay


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = OverlayScript.new()
	_overlay.name = "GameSettingsOverlay"
	_overlay.visible = false
	_overlay.configure(UserSettings if has_node("/root/UserSettings") else null)
	_overlay.closed.connect(_on_overlay_closed)
	add_child(_overlay)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel") or event.is_echo():
		return
	if _overlay.is_open():
		get_viewport().set_input_as_handled()
		_overlay.close()
		return
	if not _can_open():
		return
	get_viewport().set_input_as_handled()
	open()


func is_open() -> bool:
	return _overlay != null and _overlay.is_open()


func open() -> void:
	if _overlay == null or _overlay.is_open():
		return
	_close_other_overlays()
	_overlay.open()


func close() -> void:
	if _overlay != null and _overlay.is_open():
		_overlay.close()


func toggle() -> void:
	if is_open():
		close()
	else:
		open()


func _close_other_overlays() -> void:
	var parent := get_parent()
	var inventory := parent.get_node_or_null("InventoryController") as InventoryController
	if inventory != null:
		inventory.close()
	var journal := parent.get_node_or_null("JournalController") as JournalController
	if journal != null:
		journal.close()
	var world_map := parent.get_node_or_null("WorldMapController") as WorldMapController
	if world_map != null:
		world_map.close()
	var reflection := parent.get_node_or_null("ReflectionController") as ReflectionController
	if reflection != null:
		reflection.close()
	var quick_access := parent.get_node_or_null("QuickAccessMenu") as QuickAccessMenu
	if quick_access != null:
		_close_controls_overlay(quick_access)


func _close_controls_overlay(quick_access: QuickAccessMenu) -> void:
	var controls := quick_access.get_node_or_null("ControlsOverlay")
	if controls != null and controls.has_method("is_open") and bool(controls.call("is_open")):
		controls.call("close")


func _can_open() -> bool:
	if not get_tree().get_nodes_in_group(&"demo_dialogue_active").is_empty():
		return false
	var parent := get_parent()
	var inventory := parent.get_node_or_null("InventoryController") as InventoryController
	if inventory != null and inventory.is_open():
		return false
	var journal := parent.get_node_or_null("JournalController") as JournalController
	if journal != null and journal.is_open():
		return false
	var world_map := parent.get_node_or_null("WorldMapController") as WorldMapController
	if world_map != null and world_map.is_open():
		return false
	var reflection := parent.get_node_or_null("ReflectionController") as ReflectionController
	if reflection != null and reflection.is_open():
		return false
	var commission := parent.get_node_or_null("ForgeCommissionController") as ForgeCommissionController
	if commission != null and commission.is_open():
		return false
	for node in get_tree().get_nodes_in_group(&"modal_input_overlay"):
		if node == _overlay:
			continue
		if node is CanvasLayer and (node as CanvasLayer).visible:
			return false
		if node is CanvasItem and (node as CanvasItem).visible:
			return false
	return true


func _on_overlay_closed() -> void:
	pass
