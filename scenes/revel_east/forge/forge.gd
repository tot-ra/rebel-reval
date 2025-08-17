extends Node2D

func _ready() -> void:
	if DoorNavigator.spawn_door_tag != null:
		var door_path = "Doors/door_" + DoorNavigator.spawn_door_tag
		var door = get_node(door_path) as Door
		
		if door!=null:
			DoorNavigator.trigger_player_spawn(door.spawn.global_position, door.spawn_direction)
