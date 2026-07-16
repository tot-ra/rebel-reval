extends SceneTree

const MANIFEST_PATH := "res://content/transitions/active_destinations.json"
const DOOR_SCRIPT_PATH := "res://scenes/elements/door.gd"
const RETIRED_SPAWN_IDS := [
	"main",
	"south_1",
	"center_1",
	"center_2",
	"center_3",
	"center_4",
	"center_5",
	"north_1",
	"north_2",
	"east_1",
	"east_2",
	"east_3",
	"east_4",
	"east_5",
]
const RETIRED_SCENE_IDS := [
	"reval_center",
	"reval_north",
	"reval_south",
]
const SOURCE_FILES_WITHOUT_LEGACY_DOOR_PATHS := [
	"res://scripts/global/BaseLevel.gd",
	"res://scripts/global/doorNavigator.gd",
	"res://scenes/reval_east/forge/forge.gd",
]

var _errors: Array[String] = []
var _active_scenes := {}

func _initialize() -> void:
	call_deferred("_verify")

func _verify() -> void:
	_load_manifest()
	_verify_no_legacy_path_construction()
	_verify_retired_ids_absent()
	await _verify_active_destinations_and_spawns()
	await _verify_active_door_destinations()

	if _errors.is_empty():
		print("P0-022 transition verification passed: %d active scenes checked." % _active_scenes.size())
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		print("P0-022 transition verification failed: %d error(s)." % _errors.size())
		quit(1)

func _load_manifest() -> void:
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		_fail("Missing transition manifest: " + MANIFEST_PATH)
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail("Transition manifest must be a JSON object: " + MANIFEST_PATH)
		return

	for scene_record in parsed.get("scenes", []):
		if typeof(scene_record) != TYPE_DICTIONARY:
			_fail("Transition manifest has a non-object scene record")
			continue
		if not bool(scene_record.get("active", true)):
			continue

		var scene_id := String(scene_record.get("id", ""))
		var scene_path := String(scene_record.get("path", ""))
		if scene_id.is_empty() or scene_path.is_empty():
			_fail("Active transition scene is missing id or path")
			continue
		if _active_scenes.has(scene_id):
			_fail("Duplicate active transition scene id: " + scene_id)
			continue

		var spawns := {}
		for spawn_record in scene_record.get("spawns", []):
			if typeof(spawn_record) != TYPE_DICTIONARY:
				_fail("Scene %s has a non-object spawn record" % scene_id)
				continue
			var spawn_id := String(spawn_record.get("id", ""))
			if spawn_id.is_empty():
				_fail("Scene %s has a spawn without id" % scene_id)
				continue
			if spawns.has(spawn_id):
				_fail("Scene %s has duplicate spawn id %s" % [scene_id, spawn_id])
			spawns[spawn_id] = true

		_active_scenes[scene_id] = {
			"path": scene_path,
			"spawns": spawns,
		}

func _verify_retired_ids_absent() -> void:
	for scene_id in RETIRED_SCENE_IDS:
		if _active_scenes.has(scene_id):
			_fail("Retired transition scene id remains active: " + scene_id)

	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	for scene_record in parsed.get("scenes", []):
		if typeof(scene_record) != TYPE_DICTIONARY:
			continue
		var scene_id := String(scene_record.get("id", ""))
		for spawn_record in scene_record.get("spawns", []):
			if typeof(spawn_record) != TYPE_DICTIONARY:
				continue
			var spawn_id := String(spawn_record.get("id", ""))
			if spawn_id in RETIRED_SPAWN_IDS:
				_fail("Retired spawn id %s remains in manifest scene %s" % [spawn_id, scene_id])

func _verify_no_legacy_path_construction() -> void:
	for path in SOURCE_FILES_WITHOUT_LEGACY_DOOR_PATHS:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			_fail("Cannot read source file for legacy door-path check: " + path)
			continue
		var text := file.get_as_text()
		if text.contains("Doors/door_"):
			_fail("Legacy door node path construction remains in active code: " + path)
		if path.ends_with("doorNavigator.gd") and text.contains("scene_paths"):
			_fail("Legacy hard-coded scene dictionary remains in DoorNavigator")

func _verify_active_destinations_and_spawns() -> void:
	for scene_id in _active_scenes.keys():
		var scene_path: String = _active_scenes[scene_id]["path"]
		if not ResourceLoader.exists(scene_path):
			_fail("Active transition scene path does not exist: %s (%s)" % [scene_id, scene_path])
			continue

		var packed := load(scene_path) as PackedScene
		if packed == null:
			_fail("Active transition scene failed to load as PackedScene: %s (%s)" % [scene_id, scene_path])
			continue

		var instance := await _mount_scene_instance(packed)
		if instance == null:
			_fail("Active transition scene failed to instantiate: %s (%s)" % [scene_id, scene_path])
			continue

		for spawn_id in _active_scenes[scene_id]["spawns"].keys():
			var matches := _find_spawn_doors(instance, StringName(spawn_id))
			if matches.is_empty():
				_fail("Scene %s is missing registered spawn id %s" % [scene_id, spawn_id])
				continue
			if matches.size() > 1:
				_fail("Scene %s has duplicate Door.spawn_id %s" % [scene_id, spawn_id])
			for door in matches:
				if door.get_node_or_null("Spawn") == null:
					_fail("Scene %s spawn id %s door has no Spawn child" % [scene_id, spawn_id])

		_release_scene_instance(instance)

func _verify_active_door_destinations() -> void:
	for source_scene_id in _active_scenes.keys():
		var source_scene_path: String = _active_scenes[source_scene_id]["path"]
		var packed := load(source_scene_path) as PackedScene
		if packed == null:
			continue
		var instance := await _mount_scene_instance(packed)
		if instance == null:
			continue
		_verify_doors_recursive(instance, source_scene_id, instance)
		_release_scene_instance(instance)

func _mount_scene_instance(packed: PackedScene) -> Node:
	var instance := packed.instantiate()
	if instance == null:
		return null
	root.add_child(instance)
	if not instance.is_node_ready():
		await instance.ready
	return instance

func _release_scene_instance(instance: Node) -> void:
	if is_instance_valid(instance):
		instance.queue_free()

func _verify_doors_recursive(node: Node, source_scene_id: String, root: Node) -> void:
	if _node_uses_script(node, DOOR_SCRIPT_PATH):
		var own_spawn_id := String(node.get("spawn_id"))
		var node_path := String(root.get_path_to(node))
		if own_spawn_id.is_empty():
			_fail("Door %s/%s lacks stable spawn_id" % [source_scene_id, node_path])
		if bool(node.get("transition_enabled")):
			var destination_scene_id := String(node.get("destination_scene_id"))
			var destination_spawn_id := String(node.get("destination_spawn_id"))
			if destination_scene_id.is_empty() or destination_spawn_id.is_empty():
				_fail("Active door %s/%s lacks stable destination_scene_id or destination_spawn_id" % [source_scene_id, node_path])
			elif not _active_scenes.has(destination_scene_id):
				_fail("Active door %s/%s points to inactive or missing scene id %s" % [source_scene_id, node_path, destination_scene_id])
			elif not _active_scenes[destination_scene_id]["spawns"].has(destination_spawn_id):
				_fail("Active door %s/%s points to missing spawn %s/%s" % [source_scene_id, node_path, destination_scene_id, destination_spawn_id])
	for child in node.get_children():
		_verify_doors_recursive(child, source_scene_id, root)

func _find_spawn_doors(node: Node, target_spawn_id: StringName) -> Array[Node]:
	var matches: Array[Node] = []
	if _node_uses_script(node, DOOR_SCRIPT_PATH) and StringName(String(node.get("spawn_id"))) == target_spawn_id:
		matches.append(node)
	for child in node.get_children():
		matches.append_array(_find_spawn_doors(child, target_spawn_id))
	return matches

func _node_uses_script(node: Node, script_path: String) -> bool:
	var script = node.get_script()
	return script != null and String(script.resource_path) == script_path

func _fail(message: String) -> void:
	_errors.append(message)
