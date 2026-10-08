extends SceneTree

## Review plates for the New Game opening (ADR 0033). GPU run:
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
	opening.auto_continue = false
	root.add_child(opening)
	await _frames(4)
	await _save(out + "/title.png")
	opening.begin_duel()
	var host: SpiritArenaHost = opening.host()
	# SD-18: the blow sweeping along the telegraph arc with the guard/dodge prompt.
	host.duel.tick(SpiritDuel.TELEGRAPH_SEC * 0.7)
	await _frames(3)
	await _save(out + "/telegraph.png")
	host.duel.tick(SpiritDuel.TELEGRAPH_SEC)
	# The spell-card hotbar with the countdown ring part-way down.
	host.duel.tick(SpiritDuel.REPLY_WINDOW_SEC * 0.4)
	await _frames(3)
	await _save(out + "/duel.png")
	# A cast reply: its spoken line typed over the arena.
	host.pick_slot(0)
	await _frames(40)
	await _save(out + "/cast.png")
	quit()


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("CAPTURED ", path)
