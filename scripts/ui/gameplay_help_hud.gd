class_name GameplayHelpHud
extends CanvasLayer

## Deprecated standalone strip. Control hints and mouse entry points now live in
## QuickAccessMenu at the bottom of the screen. This scene remains for inventory
## and conversion-plan retain rows; bootstrap no longer mounts a visible copy.

const HELP_TEXT := (
	"WASD or arrows - move | Click - travel | E - interact | "
	+ "C - camera | N - map | I - inventory | J - journal"
)


func _ready() -> void:
	layer = 20
	# Intentionally empty: unified bottom Quick access owns the visible help.
