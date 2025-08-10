extends RichTextLabel

func _ready():
	self.gui_input.connect(_on_gui_input)

func _on_gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		get_tree().change_scene_to_file("res://scenes/center.tscn")
