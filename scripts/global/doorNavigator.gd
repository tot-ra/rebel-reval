extends Node

const TRANSITION_MANIFEST_PATH := "res://content/transitions/active_destinations.json"
const MAX_CACHE_SIZE := 5

signal on_trigger_player_spawn

var pending_spawn_scene_id: StringName = &""
var pending_spawn_id: StringName = &""

# Kept only as a compatibility bridge for older scenes or console calls.
# Active code should use pending_spawn_scene_id and pending_spawn_id.
var spawn_door_tag = null

var scene_cache := {}
var cache_order: Array[StringName] = []

var _manifest_loaded := false
var _scenes := {}

func _ready() -> void:
	load_manifest()

func load_manifest(force_reload: bool = false) -> bool:
	if _manifest_loaded and not force_reload:
		return true

	_scenes.clear()
	var file := FileAccess.open(TRANSITION_MANIFEST_PATH, FileAccess.READ)
	if file == null:
		push_error("Transition manifest is missing: " + TRANSITION_MANIFEST_PATH)
		return false

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Transition manifest must be a JSON object: " + TRANSITION_MANIFEST_PATH)
		return false

	for scene_record in parsed.get("scenes", []):
		if typeof(scene_record) != TYPE_DICTIONARY:
			push_error("Transition manifest contains a non-object scene record")
			continue

		var scene_id := StringName(String(scene_record.get("id", "")))
		var scene_path := String(scene_record.get("path", ""))
		if String(scene_id).is_empty() or scene_path.is_empty():
			push_error("Transition manifest scene records require id and path")
			continue

		var spawns := {}
		for spawn_record in scene_record.get("spawns", []):
			if typeof(spawn_record) != TYPE_DICTIONARY:
				push_error("Transition manifest scene %s contains a non-object spawn record" % String(scene_id))
				continue
			var spawn_id := StringName(String(spawn_record.get("id", "")))
			if String(spawn_id).is_empty():
				push_error("Transition manifest scene %s has a spawn without id" % String(scene_id))
				continue
			spawns[spawn_id] = true

		_scenes[scene_id] = {
			"path": scene_path,
			"active": bool(scene_record.get("active", true)),
			"spawns": spawns,
		}

	_manifest_loaded = true
	return true

func get_active_scene_ids() -> Array[StringName]:
	load_manifest()
	var ids: Array[StringName] = []
	for scene_id in _scenes.keys():
		if bool(_scenes[scene_id].get("active", false)):
			ids.append(scene_id)
	ids.sort()
	return ids

func has_active_scene(scene_id) -> bool:
	load_manifest()
	var key := StringName(String(scene_id))
	return _scenes.has(key) and bool(_scenes[key].get("active", false))

func get_scene_path(scene_id) -> String:
	load_manifest()
	var key := StringName(String(scene_id))
	if not _scenes.has(key):
		return ""
	return String(_scenes[key].get("path", ""))

func get_scene_spawn_ids(scene_id) -> Array[StringName]:
	load_manifest()
	var key := StringName(String(scene_id))
	var ids: Array[StringName] = []
	if not _scenes.has(key):
		return ids
	for spawn_id in _scenes[key].get("spawns", {}).keys():
		ids.append(spawn_id)
	ids.sort()
	return ids

func has_spawn(scene_id, spawn_id) -> bool:
	load_manifest()
	var scene_key := StringName(String(scene_id))
	var spawn_key := StringName(String(spawn_id))
	return _scenes.has(scene_key) and _scenes[scene_key].get("spawns", {}).has(spawn_key)

func get_spawn_node(level: Node, scene_id, spawn_id) -> Door:
	if not has_spawn(scene_id, spawn_id):
		return null
	return _find_spawn_door(level, StringName(String(spawn_id)))

func go_to_scene(scene_id, spawn_id) -> void:
	var scene_key := StringName(String(scene_id))
	var spawn_key := StringName(String(spawn_id))
	if not has_active_scene(scene_key):
		push_warning("Transition scene is not active or registered: " + String(scene_key))
		return
	if not has_spawn(scene_key, spawn_key):
		push_warning("Transition spawn is not registered: %s/%s" % [String(scene_key), String(spawn_key)])
		return

	pending_spawn_scene_id = scene_key
	pending_spawn_id = spawn_key
	spawn_door_tag = null
	var scene_resource: PackedScene = _get_scene_resource(scene_key)
	if scene_resource == null:
		push_error("Transition scene failed to load: " + get_scene_path(scene_key))
		clear_pending_spawn()
		return

	get_tree().call_deferred("change_scene_to_packed", scene_resource)

func spawn_player_at_pending_spawn(level: Node) -> bool:
	# Resolve through stable Door.spawn_id values so gameplay IDs are not tied
	# to node names or folder layout.
	if String(pending_spawn_id).is_empty():
		return false

	var door := get_spawn_node(level, pending_spawn_scene_id, pending_spawn_id)
	if door == null:
		push_warning("Pending spawn could not be resolved: %s/%s" % [String(pending_spawn_scene_id), String(pending_spawn_id)])
		return false
	if door.spawn == null:
		push_warning("Pending spawn door has no Spawn child: %s/%s" % [String(pending_spawn_scene_id), String(pending_spawn_id)])
		return false

	trigger_player_spawn(door.spawn.global_position, door.spawn_direction)
	clear_pending_spawn()
	return true

## Place at a pending door spawn when set; otherwise use authored default_spawn.
## WHY: spawn_player_at_pending_spawn clears pending IDs on success, so scenes must
## not treat an empty pending_spawn_id as "use default spawn" after a door transition.
## Call only after map doors exist (after MapSceneBootstrap.assemble).
func place_player(level: Node, player: Node2D, default_spawn: Vector2) -> bool:
	if spawn_player_at_pending_spawn(level):
		return true
	if player != null:
		player.global_position = default_spawn
	return false

func clear_pending_spawn() -> void:
	pending_spawn_scene_id = &""
	pending_spawn_id = &""
	spawn_door_tag = null

func trigger_player_spawn(position: Vector2, direction: String):
	on_trigger_player_spawn.emit(position, direction)

func _get_scene_resource(scene_id: StringName) -> PackedScene:
	if scene_cache.has(scene_id):
		cache_order.erase(scene_id)
		cache_order.append(scene_id)
		return scene_cache[scene_id]

	var scene_path := get_scene_path(scene_id)
	if not ResourceLoader.exists(scene_path):
		push_error("Transition scene path does not exist: " + scene_path)
		return null

	var scene_resource := load(scene_path) as PackedScene
	if scene_resource == null:
		return null

	if cache_order.size() >= MAX_CACHE_SIZE:
		var lru_scene_id = cache_order.pop_front()
		scene_cache.erase(lru_scene_id)

	scene_cache[scene_id] = scene_resource
	cache_order.append(scene_id)
	return scene_resource

func _find_spawn_door(node: Node, target_spawn_id: StringName) -> Door:
	if node is Door and node.spawn_id == target_spawn_id:
		return node
	for child in node.get_children():
		var found := _find_spawn_door(child, target_spawn_id)
		if found != null:
			return found
	return null
