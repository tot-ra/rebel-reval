extends "res://scenes/menu/main_menu_entry.gd"

## New game opens in the seamless city inside Kalev's smithy, where the porter's spirit duel is
## fought in place (R-1872, SmithyOpening); no separate opening scene is loaded. The still-image
## conquest vision that used to play first was removed (R-1763) until it is remade as video.


func activate() -> void:
	SmithyOpening.start_new_game(DoorNavigator)
