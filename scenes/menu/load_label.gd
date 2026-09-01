extends RichTextLabel

## Main-menu entry that opens the save list overlay so the player can pick
## a save slot to resume. The label is hidden entirely when no saves exist.

const SaveListOverlay := preload("res://scenes/menu/save_list_overlay.gd")


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	gui_input.connect(_on_gui_input)
	_refresh_availability()


func _on_gui_input(event: InputEvent) -> void:
	if _is_activate_event(event):
		_show_overlay()


func _is_activate_event(event: InputEvent) -> bool:
	return (
		event.is_action_pressed(&"ui_accept")
		or (
			event is InputEventMouseButton
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
			and (event as InputEventMouseButton).pressed
		)
	)


func _show_overlay() -> void:
	# Guard against double-clicks while the overlay is already open.
	if get_tree().get_nodes_in_group("save_list_overlay").size() > 0:
		return

	var overlay: Control = SaveListOverlay.new()
	overlay.add_to_group("save_list_overlay")
	overlay.save_selected.connect(_on_save_selected)
	get_tree().current_scene.add_child(overlay)


func _on_save_selected(slot: int) -> void:
	var ok := SessionState.load_game(slot)
	if not ok:
		push_warning("Failed to load save slot %d" % slot)
		return
	# Navigate to the exact scene/spawn recorded in the loaded save.
	var state: GameState = SessionState.state
	DoorNavigator.go_to_scene(state.player.location_id, state.player.spawn_id)


func _refresh_availability() -> void:
	var saves := SessionState.list_saves()
	visible = saves.size() > 0
	focus_mode = Control.FOCUS_ALL if visible else Control.FOCUS_NONE
	if visible:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_update_sibling_focus_neighbors(true)
	else:
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		_update_sibling_focus_neighbors(false)


## When the Load label is hidden, wire Start's bottom to Credits and
## Credits' top to Start so keyboard navigation skips the invisible node.
func _update_sibling_focus_neighbors(load_visible: bool) -> void:
	var start_label := get_node_or_null("../Start label")
	var credits_label := get_node_or_null("../Credits label")
	if start_label == null or credits_label == null:
		return
	if load_visible:
		start_label.focus_neighbor_bottom = NodePath("../Load label")
		credits_label.focus_neighbor_top = NodePath("../Load label")
	else:
		start_label.focus_neighbor_bottom = NodePath("../Credits label")
		credits_label.focus_neighbor_top = NodePath("../Start label")
