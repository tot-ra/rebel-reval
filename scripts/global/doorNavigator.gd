extends Node

var spawn_door_tag

const MAX_CACHE_SIZE = 5
var scene_cache = {}
var cache_order = []

var scene_paths = {
	"forge": "res://scenes/reval_east/forge/forge.tscn",
	"reval_east": "res://scenes/reval_east/reval_east.tscn",
	"reval_north": "res://scenes/reval_north/reval_north.tscn",
	"reval_center": "res://scenes/reval_center/reval_center.tscn",
	"reval_south": "res://scenes/reval_south/reval_south.tscn"
}

signal on_trigger_player_spawn

func go_to_scene(level_tag, destination_tag):
	if not scene_paths.has(level_tag):
		print("scene does not have level tag" + level_tag)
		return

	spawn_door_tag = destination_tag
	var scene_resource

	if scene_cache.has(level_tag):
		# Scene is in cache, move it to the end of cache_order
		scene_resource = scene_cache[level_tag]
		cache_order.erase(level_tag)
		cache_order.append(level_tag)
	else:
		# Scene is not in cache, load it
		var scene_path = scene_paths[level_tag]
		scene_resource = load(scene_path)
		
		# If cache is full, remove the least recently used scene
		if cache_order.size() >= MAX_CACHE_SIZE:
			var lru_level_tag = cache_order.pop_front()
			scene_cache.erase(lru_level_tag)
		
		# Add the new scene to the cache
		scene_cache[level_tag] = scene_resource
		cache_order.append(level_tag)

	get_tree().call_deferred("change_scene_to_packed", scene_resource)

func trigger_player_spawn(position: Vector2, direction: String):
	on_trigger_player_spawn.emit(position, direction)
