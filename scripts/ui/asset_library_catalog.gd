class_name AssetLibraryCatalog
extends RefCounted

## Discovers imported GLB/GLTF files under res://assets for the authoring browser.
## The list is filesystem-backed so a new model appears without a second registry.

const ROOT := "res://assets"
const PREFERRED_CLIPS: Array[String] = [
	"Idle",
	"idle",
	"Walk",
	"walk",
	"Walking_A",
]


static func list_models() -> Array[Dictionary]:
	var paths: Array[String] = []
	var seen := {}
	_collect(ROOT, paths, seen)
	paths.sort()
	var entries: Array[Dictionary] = []
	for path in paths:
		if not ResourceLoader.exists(path):
			continue
		entries.append(describe(path))
	return entries


static func describe(path: String) -> Dictionary:
	var relative := path.trim_prefix("res://assets/")
	var file := path.get_file().get_basename()
	return {
		"path": path,
		"id": file,
		"display_name": file.replace("_", " "),
		"category": relative.get_slice("/", 0),
		"folder": relative.get_base_dir(),
	}


static func filter_entries(
	entries: Array[Dictionary], query: String, category: String
) -> Array[Dictionary]:
	var needle := query.strip_edges().to_lower()
	var out: Array[Dictionary] = []
	for entry in entries:
		if not category.is_empty() and String(entry["category"]) != category:
			continue
		if needle.is_empty():
			out.append(entry)
			continue
		var hay := "%s %s %s" % [
			entry["path"],
			entry["display_name"],
			entry["folder"],
		]
		if hay.to_lower().contains(needle):
			out.append(entry)
	return out


static func categories_for(entries: Array[Dictionary]) -> PackedStringArray:
	var seen := {}
	var names: PackedStringArray = []
	for entry in entries:
		var category := String(entry["category"])
		if category.is_empty() or seen.has(category):
			continue
		seen[category] = true
		names.append(category)
	names.sort()
	return names


static func animation_player_for(root: Node) -> AnimationPlayer:
	var players := root.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return null
	return players[0] as AnimationPlayer


static func clip_names_for(root: Node) -> PackedStringArray:
	var names: PackedStringArray = []
	var seen := {}
	var players := root.find_children("*", "AnimationPlayer", true, false)
	for node in players:
		var player := node as AnimationPlayer
		if player == null:
			continue
		for clip: String in player.get_animation_list():
			if clip == "RESET" or seen.has(clip):
				continue
			seen[clip] = true
			names.append(clip)
	names.sort()
	return names


static func preferred_clip(clips: PackedStringArray) -> String:
	for name in PREFERRED_CLIPS:
		if clips.has(name):
			return name
	if clips.is_empty():
		return ""
	return clips[0]


static func mesh_count(root: Node) -> int:
	return root.find_children("*", "MeshInstance3D", true, false).size()


static func combined_aabb(root: Node3D) -> AABB:
	var bounds := AABB()
	var started := false
	var visuals := root.find_children("*", "VisualInstance3D", true, false)
	for node in visuals:
		var visual := node as VisualInstance3D
		if visual == null:
			continue
		var local := visual.get_aabb()
		if local.size == Vector3.ZERO:
			continue
		var world: AABB = visual.global_transform * local
		if not started:
			bounds = world
			started = true
		else:
			bounds = bounds.merge(world)
	return bounds


static func _collect(dir_path: String, paths: Array[String], seen: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var child := dir_path.path_join(entry)
		if dir.current_is_dir():
			_collect(child, paths, seen)
		else:
			var model_path := _model_path_from_entry(child)
			if not model_path.is_empty() and not seen.has(model_path):
				seen[model_path] = true
				paths.append(model_path)
		entry = dir.get_next()
	dir.list_dir_end()


static func _model_path_from_entry(path: String) -> String:
	if path.ends_with(".glb") or path.ends_with(".gltf"):
		return path
	if path.ends_with(".glb.import") or path.ends_with(".gltf.import"):
		return path.trim_suffix(".import")
	return ""
