extends "res://scripts/global/BaseLevel.gd"

@onready var player = get_node("Buildings/Player")
@onready var tile_map = get_node("TileMapLayer")

func _ready():
	super()
	player.navigation_agent.set_navigation_map(tile_map.get_navigation_map())

func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		player.navigation_agent.set_target_position(get_global_mouse_position())
