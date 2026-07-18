class_name InventoryController
extends Node

const OVERLAY_SCENE := preload("res://scenes/ui/inventory_overlay.tscn")
const TOGGLE_ACTION := &"toggle_inventory"

var _overlay: InventoryOverlay


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = OVERLAY_SCENE.instantiate() as InventoryOverlay
	_overlay.visible = false
	add_child(_overlay)
	_overlay.configure(SessionState.state.bag, SessionState.content_db)
	_overlay.configure_state(SessionState.state)
	_overlay.closed.connect(_on_overlay_closed)
	if not SessionState.debug_state_applied.is_connected(_on_debug_state_applied):
		SessionState.debug_state_applied.connect(_on_debug_state_applied)


func _exit_tree() -> void:
	if SessionState.debug_state_applied.is_connected(_on_debug_state_applied):
		SessionState.debug_state_applied.disconnect(_on_debug_state_applied)


func _on_debug_state_applied(_preset_id: StringName) -> void:
	if _overlay == null:
		return
	_overlay.configure(SessionState.state.bag, SessionState.content_db)
	_overlay.configure_state(SessionState.state)
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
	var journal := get_parent().get_node_or_null("JournalController") as JournalController
	if journal != null:
		journal.close()
	_overlay.open()


func close() -> void:
	if _overlay != null and _overlay.is_open():
		_overlay.close()


func get_selected_placement() -> InventoryPlacement:
	if _overlay == null:
		return null
	return _overlay.get_selected_placement()


func clear_selection() -> void:
	if _overlay != null:
		_overlay.clear_selection()


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
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return key_event.pressed and key_event.keycode == KEY_ESCAPE and _overlay.is_open()
	return false


func _on_overlay_closed() -> void:
	pass
