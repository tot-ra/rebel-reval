extends "res://scenes/menu/main_menu_entry.gd"

## Main-menu entry that opens the 3D asset library browser.

const LIBRARY_SCENE := "res://scenes/menu/assets_library.tscn"


func activate() -> void:
	get_tree().change_scene_to_file(LIBRARY_SCENE)
