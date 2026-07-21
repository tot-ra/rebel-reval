extends RichTextLabel

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	gui_input.connect(_on_gui_input)


func _on_gui_input(event: InputEvent) -> void:
	if _is_activate_event(event):
		get_tree().quit()


func _is_activate_event(event: InputEvent) -> bool:
	return (
		event.is_action_pressed(&"ui_accept")
		or (
			event is InputEventMouseButton
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
			and (event as InputEventMouseButton).pressed
		)
	)
