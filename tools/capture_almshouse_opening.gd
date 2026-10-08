extends SceneTree

## Review plates for the New Game opening (ADR 0033; 3D spirit disc since R-1389). GPU run:
##   tools/godot_render.sh --resolution 1280x720 --script tools/capture_almshouse_opening.gd -- \
##     --out=res://build/almshouse_opening


func _init() -> void:
	var out := "res://build/almshouse_opening"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	# Autoloads (SessionState, DoorNavigator) are compiled in only after the first frame.
	await process_frame
	var opening := (load("res://scenes/prologue/almshouse_opening.tscn") as PackedScene).instantiate()
	opening.set(&"auto_continue", false)
	root.add_child(opening)
	await _frames(4)
	await _save(out + "/title.png")
	opening.call(&"begin_duel")
	# Untyped: naming SpiritArenaHost / SpiritDuel here would compile the SessionState autoload
	# reference before it exists in a --script run.
	var host: Node = opening.call(&"host")
	var duel: Object = host.get(&"duel")
	var duel_script: Script = load("res://scripts/combat/spirit_duel.gd")
	var telegraph_sec: float = duel_script.get_script_constant_map()["TELEGRAPH_SEC"]
	var reply_sec: float = duel_script.get_script_constant_map()["REPLY_WINDOW_SEC"]
	# SD-18: the blow sweeping along the telegraph arc with the guard/dodge prompt.
	duel.call(&"tick", telegraph_sec * 0.7)
	await _frames(3)
	await _save(out + "/telegraph.png")
	# R-1389: the hall stripped to the spirit disc; the boy steps out of the red strike arc.
	var stage: Node = opening.get_node(^"Stage")
	stage.call(&"move_hero", Vector2(0.0, 1.0), false, 1.4)
	host.call(&"_process", 0.0)
	await _frames(3)
	await _save(out + "/arena_sidestep.png")
	duel.call(&"tick", telegraph_sec)
	# The spell-card hotbar with the countdown ring part-way down.
	duel.call(&"tick", reply_sec * 0.4)
	await _frames(3)
	await _save(out + "/duel.png")
	# R-1388: slot 1 speaks a word that answers the porter: the line in a bubble over the boy,
	# the bolt in the element colour mid-flight, the compact cast bar with its cooldown sweep.
	host.call(&"pick_slot", 0)
	await _frames(8)
	await _save(out + "/word.png")
	await _frames(32)
	await _save(out + "/cast.png")
	# R-1365: Kalev in the hall doorway, camera reframed on him and the boy, on his first line.
	host.call(&"close")
	await _frames(40)
	await _save(out + "/kalev.png")
	quit()


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("CAPTURED ", path)
