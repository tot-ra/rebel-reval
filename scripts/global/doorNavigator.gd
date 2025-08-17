extends Node

const scene_forge = preload("res://scenes/revel_east/forge/forge.tscn")
const scene_revel_east = preload("res://scenes/revel_east/revel_east.tscn")

signal on_trigger_player_spawn

func go_to_scene(level_tag, destination_tag):
	var scene_to_load
	
	match level_tag:
		"forge":
			scene_to_load = scene_forge
		"revel_east":
			scene_to_load = scene_revel_east
			
	if scene_to_load != null:
		# spawn_door_tag = destination_tag
		get_tree().change_scene_to_packed(scene_to_load)

func trigger_player_spawn(position: Vector2, direction: String):
	on_trigger_player_spawn.emit(position, direction)
