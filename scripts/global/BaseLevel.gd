extends Node2D

func _ready() -> void:
	DoorNavigator.spawn_player_at_pending_spawn(self)
