extends "res://scenes/menu/main_menu_entry.gd"

## New game opens in the almshouse (ADR 0033), which leads on to Kalev's smithy. The still-image
## conquest vision that used to play first was removed (R-1763) until it is remade as video.
const OPENING_SCENE := "res://scenes/prologue/almshouse_opening.tscn"


func activate() -> void:
	get_tree().change_scene_to_file(OPENING_SCENE)
