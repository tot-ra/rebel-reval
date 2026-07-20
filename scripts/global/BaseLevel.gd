extends Node2D

## Map scenes own player placement after MapSceneBootstrap.assemble creates doors.
## Do not spawn here: doors do not exist yet, and a successful pending spawn clears
## IDs that later fallbacks used to mis-read as "use authored player_spawn".
func _ready() -> void:
	pass
