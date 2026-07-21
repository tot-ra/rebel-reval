class_name JournalController
extends Node

const OVERLAY_SCENE := preload("res://scenes/ui/journal_overlay.tscn")
const TOGGLE_ACTION := &"toggle_journal"

var _overlay: JournalOverlay


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = OVERLAY_SCENE.instantiate() as JournalOverlay
	_overlay.visible = false
	add_child(_overlay)
	_overlay.configure(SessionState.state, SessionState.content_db)
	_overlay.closed.connect(_on_overlay_closed)
	if not SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.connect(_on_state_replaced)


func _exit_tree() -> void:
	if SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.disconnect(_on_state_replaced)


func _on_state_replaced(_previous: GameState, current: GameState, _reason: StringName) -> void:
	if _overlay == null:
		return
	_overlay.configure(current, SessionState.content_db)
	if _overlay.is_open():
		_overlay.open()


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
	# Global overlays are mutually exclusive regardless of whether they were
	# opened from the visible menu or their direct keyboard shortcut.
	var inventory := get_parent().get_node_or_null("InventoryController") as InventoryController
	if inventory != null:
		inventory.close()
	var world_map := get_parent().get_node_or_null("WorldMapController") as WorldMapController
	if world_map != null:
		world_map.close()
	_overlay.configure(SessionState.state, SessionState.content_db)
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


func _is_toggle_event(event: InputEvent) -> bool:
	if not event.is_pressed() or event.is_echo():
		return false
	if event.is_action(TOGGLE_ACTION):
		return event.is_action_pressed(TOGGLE_ACTION)
	if event.is_action(&"ui_cancel") and event.is_action_pressed(&"ui_cancel"):
		return _overlay.is_open()
	return false


func _on_overlay_closed() -> void:
	pass
