extends SceneTree

## Review plates for the porter's spirit form and the duel's consequences (R-1335). GPU run:
##   tools/godot_render.sh --resolution 1280x720 --script tools/capture_spirit_form.gd -- \
##     --out=res://build/spirit_form
## Plates: form_key.png (rusted key swelling on the first telegraphed blow), form_cracked.png
## (the rod after two fireballs: smaller, cracked), form_shattered.png (broken porter),
## form_silhouette.png (an arena without a staged actor draws the body itself),
## kalev_struck.png (Kalev's reaction after the shove).


func _init() -> void:
	var out := "res://build/spirit_form"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	# Autoloads (SessionState, DoorNavigator) are compiled in only after the first frame.
	await process_frame

	var opening := _opening()
	opening.begin_duel()
	var host: SpiritArenaHost = opening.host()
	host.duel.tick(SpiritDuel.TELEGRAPH_SEC * 0.8)
	await _settle(host)
	await _save(out + "/form_key.png")
	host.duel.tick(SpiritDuel.TELEGRAPH_SEC)
	host.duel.answer("fire_hands")
	host.duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	host.duel.answer("fire_lock")
	host.duel.tick(SpiritDuel.TELEGRAPH_SEC * 0.3)
	await _settle(host)
	await _save(out + "/form_cracked.png")
	host.duel.tick(SpiritDuel.TELEGRAPH_SEC)
	host.duel.answer("fire_secret")
	await _settle(host)
	await _save(out + "/form_shattered.png")
	opening.queue_free()
	await _frames(2)

	# An arena with no staged actor (world duels) draws the porter's body itself.
	var state := GameState.new()
	for grant_id: StringName in AlmshouseOpening.STARTER_GRANTS:
		MagicResolver.apply_grant_operation(state, _session_db(), grant_id)
	state.set_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER, 8)
	var backdrop := CanvasLayer.new()
	var dark := ColorRect.new()
	dark.color = Color(0.08, 0.07, 0.1)
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(dark)
	root.add_child(backdrop)
	var bare := SpiritArenaHost.new()
	bare.freeze_world = false
	root.add_child(bare)
	bare.open(_session_db(), state, AlmshouseOpening.CONFRONTATION)
	bare.duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	bare.duel.answer("still_hunger")
	bare.duel.tick(SpiritDuel.TELEGRAPH_SEC * 0.5)
	await _settle(bare)
	await _save(out + "/form_silhouette.png")
	bare.close()
	bare.queue_free()
	backdrop.queue_free()
	await _frames(2)

	var struck := _opening()
	struck.begin_duel()
	struck.host().duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	struck.host().duel.answer("shove")
	struck.host().close()
	await _frames(6)
	await _save(out + "/kalev_struck.png")
	print("GUILT ", _session_state().guilt.levels())
	quit()


func _opening() -> AlmshouseOpening:
	for flag: StringName in [
		&"flag.prologue.apprenticed",
		&"flag.prologue.struck_porter",
		&"flag.prologue.broke_porter",
		&"flag.prologue.punished_by_porter",
		&"flag.prologue.spared_porter",
	]:
		_session_state().set_flag(flag, false)
	_session_state().guilt.reset()
	var opening := (
		(load("res://scenes/prologue/almshouse_opening.tscn") as PackedScene).instantiate()
		as AlmshouseOpening
	)
	opening.auto_continue = false
	root.add_child(opening)
	return opening


## Let the form's eased presence catch up with the duel before the plate is taken.
func _settle(host: SpiritArenaHost) -> void:
	await _frames(2)
	host.form_view().advance(10.0)
	await _frames(2)


## Autoloads are not compile-time identifiers in a SceneTree script; look them up.
func _session_state() -> GameState:
	return root.get_node(^"SessionState").get("state") as GameState


func _session_db() -> ContentDB:
	return root.get_node(^"SessionState").get("content_db") as ContentDB


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("CAPTURED ", path)
