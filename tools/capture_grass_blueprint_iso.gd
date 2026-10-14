extends Node

## Review plates for blueprint-map grass in third person vs painted iso (LIVING_VEGETATION.md,
## Camera independence). Host scene so autoloads resolve:
##   tools/godot_render.sh --resolution 1600x900 res://tools/capture_grass_blueprint_iso.tscn \
##     [-- --scene=world_tartu --spawn=from_reval_south --tag=after]
## Output: build/grass/blueprint_<mode>_<tag>.png

const OUTPUT_DIR := "res://build/grass"


func _arg(prefix: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.trim_prefix(prefix)
	return fallback


func _ready() -> void:
	var tree := get_tree()
	if get_parent() != tree.root:
		reparent(tree.root)
	if tree.current_scene == self:
		tree.current_scene = null
	call_deferred("_run")


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _find_runtime(node: Node) -> MapViewRuntime:
	if node is MapViewRuntime:
		return node
	for child in node.get_children():
		var found := _find_runtime(child)
		if found != null:
			return found
	return null


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	SessionState.state = GameState.new()
	SessionState.content_db.load_from_directories(SessionState.DEMO_CONTENT_DIRS)
	var scene_id := StringName(_arg("--scene=", "world_tartu"))
	DoorNavigator.pending_spawn_scene_id = scene_id
	DoorNavigator.pending_spawn_id = StringName(_arg("--spawn=", "from_reval_south"))
	DoorNavigator.spawn_door_tag = null
	get_tree().change_scene_to_file(DoorNavigator.get_scene_path(scene_id))
	await _frames(240)
	var runtime := _find_runtime(get_tree().current_scene)
	if runtime == null:
		push_error("no MapViewRuntime in scene")
		get_tree().quit(1)
		return
	var tag := _arg("--tag=", "now")
	var modes := [
		[MapViewRuntimeCamera.CameraMode.THIRD_PERSON, "third"],
		[MapViewRuntimeCamera.CameraMode.PAINTED_ISO, "iso"],
	]
	for mode: Array in modes:
		runtime.set_camera_mode(mode[0])
		await _frames(150)
		await RenderingServer.frame_post_draw
		var path := ProjectSettings.globalize_path(
			"%s/blueprint_%s_%s.png" % [OUTPUT_DIR, mode[1], tag]
		)
		get_viewport().get_texture().get_image().save_png(path)
		print("saved ", path)
	get_tree().quit(0)
