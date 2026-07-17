class_name ScreenDirectionInput
extends RefCounted

## Screen-relative movement axes from arrow keys and WASD via ui_* actions.


static func read_axis() -> Vector2:
	return Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)
