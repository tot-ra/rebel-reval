extends "res://scenes/menu/main_menu_entry.gd"

## Main-menu entry that opens the Credits screen (audio attribution).

const CREDITS_SCENE := "res://scenes/menu/credits.tscn"


func activate() -> void:
	get_tree().change_scene_to_file(CREDITS_SCENE)
