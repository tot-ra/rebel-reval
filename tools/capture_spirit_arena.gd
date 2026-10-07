extends SceneTree

## Review plates for the spirit duel screen (ADR 0033, SD-04). GPU run:
##   tools/godot_render.sh --resolution 1280x720 --script tools/capture_spirit_arena.gd -- \
##     --out=res://build/spirit_arena

const DUEL_ID := &"dialogue.test_duel"


func _init() -> void:
	var out := "res://build/spirit_arena"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var db := ContentDB.new()
	db.load_from_directories(["res://content/examples/valid", "res://content/examples/support"])
	var host := SpiritArenaHost.new()
	host.duel.hero_id = &"char.mart"
	host.freeze_world = false
	root.add_child(host)
	host.open(db, GameState.new(), DUEL_ID)
	await _frames(3)
	await _save(out + "/telegraph.png")
	host.duel.tick(SpiritDuel.TELEGRAPH_SEC * 0.6)
	await _frames(2)
	await _save(out + "/telegraph_late.png")
	host.duel.tick(SpiritDuel.TELEGRAPH_SEC)
	await _frames(3)
	await _save(out + "/answer.png")
	host.close()
	var watch_db := ContentDB.new()
	watch_db.load_from_directories(
		["res://content/prologue", "res://content/examples/valid", "res://content/examples/support"]
	)
	var watcher := SpiritArenaHost.new()
	watcher.freeze_world = false
	root.add_child(watcher)
	watcher.observe(watch_db, GameState.new(), &"dialogue.prologue.almshouse_quarrel")
	watcher.observation.step()
	watcher.observation.step()
	await _frames(3)
	await _save(out + "/observation.png")
	quit()


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("CAPTURED ", path)
