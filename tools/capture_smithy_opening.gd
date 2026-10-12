extends SceneTree

## Review plates for the New Game opening in the city smithy (R-1872): the porter duel fought in
## place with the normal city player and camera. GPU run:
##   tools/godot_render.sh --resolution 1600x900 --script tools/capture_smithy_opening.gd -- \
##     --out=res://build/smithy_opening


func _init() -> void:
	var out := "res://build/smithy_opening"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	# Autoloads (SessionState, DoorNavigator) are compiled in only after the first frame.
	await process_frame
	# Untyped through load(): a class_name reference would compile before the autoloads exist.
	var opening_script: Script = load("res://scripts/prologue/smithy_opening.gd")
	opening_script.set(&"pending", true)
	root.get_node(^"/root/DoorNavigator").call(&"go_to_scene", &"reval_city", &"kalev_smithy")
	var opening: Node = null
	var guard := 0
	while opening == null and guard < 1200:
		await process_frame
		guard += 1
		var city := current_scene
		if city != null:
			opening = city.get_node_or_null(^"SmithyOpening")
	if opening == null:
		push_error("the city never mounted the smithy opening")
		quit(1)
		return
	while opening.call(&"host") == null and guard < 2400:
		await process_frame
		guard += 1
	var host: Node = opening.call(&"host")
	var duel: Object = host.get(&"duel")
	var duel_script: Script = load("res://scripts/combat/spirit_duel.gd")
	var telegraph_sec: float = duel_script.get_script_constant_map()["TELEGRAPH_SEC"]
	# Let streaming, sight ripple and the camera settle.
	await _frames(90)
	await _save(out + "/duel_start.png")
	duel.call(&"tick", telegraph_sec * 0.7)
	await _frames(3)
	await _save(out + "/telegraph.png")
	duel.call(&"tick", telegraph_sec)
	await _frames(3)
	host.call(&"pick_slot", 0)
	await _frames(40)
	await _save(out + "/word.png")
	host.call(&"pick_slot", 4)
	await _frames(40)
	await _save(out + "/light_hit.png")
	# R-1877: closing the duel cuts to Kalev's arrival framed by the conversation shot.
	host.call(&"close")
	await _frames(60)
	await _save(out + "/kalev_shot.png")
	quit()


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("CAPTURED ", path)
