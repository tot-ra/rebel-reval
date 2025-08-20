extends Node2D

var player
@onready var tile_map = get_node("Floor")

func _ready() -> void:
	player = find_player(get_tree().root)
	if player:
		print("Player found: ", player)
		player.navigation_agent.set_navigation_map(tile_map.get_navigation_map())
	else:
		print("Player not found in forge scene!")
		
	if DoorNavigator.spawn_door_tag != null:
		var door_path = "Doors/door_" + DoorNavigator.spawn_door_tag
		var door = get_node(door_path) as Door
		
		if door!=null:
			DoorNavigator.trigger_player_spawn(door.spawn.global_position, door.spawn_direction)

func find_player(node):
	if node is Player:
		return node
	for child in node.get_children():
		var found = find_player(child)
		if found:
			return found
	return null

func _unhandled_input(event):
	if player and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var target_position = get_global_mouse_position()
		print("Forge: Setting target position to: ", target_position)
		player.navigation_agent.set_target_position(target_position)
