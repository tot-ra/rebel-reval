extends SceneTree

## Review plates for the spirit arena cast and blow effects (R-1332). GPU run:
##   tools/godot_render.sh --resolution 1280x720 --script tools/capture_spirit_arena_vfx.gd -- \
##     --out=res://docs/reports/images/spirit_arena_vfx
## Each plate fires one exchange through the real host and grabs a frame mid-effect.

const CONTENT_DIRS: Array[String] = [
	"res://content/examples/valid",
	"res://content/examples/support",
]

var _host: SpiritArenaHost


func _init() -> void:
	var out := "res://build/spirit_arena_vfx"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	await process_frame
	var db := ContentDB.new()
	db.load_from_directories(CONTENT_DIRS)
	var state := GameState.new()
	_host = SpiritArenaHost.new()
	_host.duel.hero_id = &"char.mart"
	_host.freeze_world = false
	# Keep the opening blow hanging so only the scripted exchanges draw.
	_host.duel.telegraph_sec = 3600.0
	root.add_child(_host)
	_host.open_scripted(db, state, &"dialogue.test_duel")
	_host.vfx().allow_shake = true
	await _plate(out + "/fireball_flight.png", _spell("pressure", 42.0), 0.2)
	await _plate(out + "/fireball_impact.png", _spell("pressure", 42.0), 0.45)
	await _plate(out + "/tremor.png", _spell("stagger", 42.0), 0.25)
	await _plate(out + "/iron_skin.png", _spell("buff", 42.0), 0.3)
	await _plate(out + "/hit.png", _incoming(CombatHitResult.OUTCOME_HIT, 20.0, 60.0), 0.1)
	await _plate(out + "/parry.png", _incoming(CombatHitResult.OUTCOME_PARRIED, 0.0, 45.0), 0.15)
	quit()


func _spell(arena_effect: String, pressure_left: float) -> Dictionary:
	return {"kind": "spell", "spell_id": "capture", "arena_effect": arena_effect, "pressure_left": pressure_left}  # gdlint: ignore=max-line-length


func _incoming(outcome: StringName, lost: float, pressure_left: float) -> Dictionary:
	return {"kind": "incoming", "outcome": outcome, "composure_lost": lost, "pressure_left": pressure_left}  # gdlint: ignore=max-line-length


func _plate(path: String, exchange: Dictionary, after_sec: float) -> void:
	_host.vfx().resync()
	# Pressure starts full so every exchange that lowers it shows a number.
	_host.vfx().set("_last_pressure", 60.0)
	await _wait(0.1)
	_host.duel.exchange_resolved.emit(exchange)
	await _wait(after_sec)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("CAPTURED ", path)


func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame
