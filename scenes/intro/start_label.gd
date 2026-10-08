extends RichTextLabel

## New game opens on the historical prologue cutscene (ADR 0034), which chains into the
## almshouse opening (ADR 0033) and from there to the forge.
const OPENING_SCENE := "res://scenes/cutscene/prologue_opening.tscn"

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Main menu labels should not show the default Godot focus border on load.
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	gui_input.connect(_on_gui_input)
	call_deferred("grab_focus")


func _on_gui_input(event: InputEvent) -> void:
	if _is_activate_event(event):
		get_tree().change_scene_to_file(OPENING_SCENE)


func _is_activate_event(event: InputEvent) -> bool:
	return (
		event.is_action_pressed(&"ui_accept")
		or (
			event is InputEventMouseButton
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
			and (event as InputEventMouseButton).pressed
		)
	)
