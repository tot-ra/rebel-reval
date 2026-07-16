extends RichTextLabel

func _ready():
	self.gui_input.connect(_on_gui_input)

func _on_gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		DoorNavigator.go_to_scene(&"reval_east", &"street_start")
