extends RichTextLabel

func _ready():
	# Clickable menu text should show the hand/pointer cursor on hover.
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	self.gui_input.connect(_on_gui_input)

func _on_gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		DoorNavigator.go_to_scene(&"forge", &"smithy_start")
