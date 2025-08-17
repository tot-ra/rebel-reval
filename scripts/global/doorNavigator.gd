extends Node

var spawn_door_tag

var scene_paths = {
	"forge": "res://scenes/revel_east/forge/forge.tscn",
	"revel_east": "res://scenes/revel_east/revel_east.tscn"
}

signal on_trigger_player_spawn

func go_to_scene(level_tag, destination_tag):
	if scene_paths.has(level_tag):
		var scene_path = scene_paths[level_tag]
		spawn_door_tag = destination_tag
		get_tree().call_deferred("change_scene_to_file", scene_path)

func trigger_player_spawn(position: Vector2, direction: String):
	on_trigger_player_spawn.emit(position, direction)
