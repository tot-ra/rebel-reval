extends SceneTree

## Review plates for the Hingepuu guilt phantoms (SW-2, R-1349). GPU run:
##   tools/godot_render.sh --resolution 1600x900 --script tools/capture_guilt_phantoms.gd -- \
##     --out=res://docs/reports/images/spirit/guilt_phantoms
## Scripts that reach the SessionState autoload are loaded after the first frame and used
## untyped: a SceneTree tool script compiles before autoloads exist.


func _init() -> void:
	var out := "res://build/guilt_phantoms"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	await _frames(1)
	var db := ContentDB.new()
	db.load_from_directories(["res://content/dialogue", "res://content/examples/support"])
	var state := GameState.new()
	# One phantom per tier: church minor, folk heavy, civic crushing.
	state.guilt.from_dict({"levels": {"guilt.church": 2, "guilt.folk": 4, "guilt.civic": 7}})
	var actor := Node2D.new()
	root.add_child(actor)
	var controller: Node = load("res://scripts/reflection/reflection_controller.gd").new()
	controller.content_db = db
	actor.add_child(controller)
	await _frames(2)
	controller.call(&"_bind_state", state)
	controller.call(&"close")
	controller.call(&"enter_hingepuu")
	var hub: Node = controller.call(&"get_hingepuu")
	var folk: Dictionary = (hub.call(&"phantoms") as Array)[1]
	hub.call(&"set_actor_position", hub.call(&"phantom_spot", folk) + Vector2(0, -90))
	await _frames(3)
	await _save(out + "/hub_phantoms.png")
	controller.call(&"face_phantom", folk)
	var host: Node = controller.call(&"phantom_duel_host")
	await _frames(3)
	await _save(out + "/phantom_duel.png")
	host.call(&"close")
	quit()


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("CAPTURED ", path)
