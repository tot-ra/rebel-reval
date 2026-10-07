extends RichTextLabel

## Main-menu entry for the seamless Reval 1343 preview (ADR 0031): the whole
## walled town, Toompea and the shore in one scene without district loads.

const CITY_SCENE := "res://scenes/world/reval_city/reval_city.tscn"


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	gui_input.connect(_on_gui_input)


func _on_gui_input(event: InputEvent) -> void:
	if _is_activate_event(event):
		get_tree().change_scene_to_file(CITY_SCENE)


func _is_activate_event(event: InputEvent) -> bool:
	return (
		event.is_action_pressed(&"ui_accept")
		or (
			event is InputEventMouseButton
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
			and (event as InputEventMouseButton).pressed
		)
	)
