extends RichTextLabel

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	gui_input.connect(_on_gui_input)
	call_deferred("grab_focus")


func _on_gui_input(event: InputEvent) -> void:
	if _is_activate_event(event):
		DoorNavigator.go_to_scene(&"forge", &"smithy_start")


func _is_activate_event(event: InputEvent) -> bool:
	return (
		event.is_action_pressed(&"ui_accept")
		or (
			event is InputEventMouseButton
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
			and (event as InputEventMouseButton).pressed
		)
	)
