extends SceneTree

## Review plates for the New Game opening (R-1872, moved to the Holy Spirit almshouse by
## ADR 0052): the porter duel in the sick-room, Gertrud at Lambert's sickbed, the calming duel
## with Lambert's fear, and Kalev at the sickbed (two-shot and the iron charm). GPU run:
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
	var spawn: String = opening_script.get_script_constant_map()["SPAWN_ID"]
	root.get_node(^"/root/DoorNavigator").call(&"go_to_scene", &"reval_city", StringName(spawn))
	var opening: Node = null
	var guard := 0
	while opening == null and guard < 1200:
		await process_frame
		guard += 1
		var city := current_scene
		if city != null:
			opening = city.get_node_or_null(^"SmithyOpening")
	if opening == null:
		push_error("the city never mounted the opening")
		quit(1)
		return
	while opening.call(&"host") == null and guard < 2400:
		await process_frame
		guard += 1
	var host: Node = opening.call(&"host")
	var duel_script: Script = load("res://scripts/combat/spirit_duel.gd")
	var telegraph_sec: float = duel_script.get_script_constant_map()["TELEGRAPH_SEC"]
	# Let streaming, sight ripple and the camera settle.
	await _frames(120)
	await _save(out + "/duel_start.png")
	host.get(&"duel").call(&"tick", telegraph_sec)
	await _frames(3)
	host.call(&"pick_slot", 3)
	await _frames(40)
	await _save(out + "/word.png")
	# Beat 2a: closing the porter duel cuts to Gertrud at Lambert's sickbed.
	host.call(&"close")
	await _frames(60)
	await _save(out + "/sickbed_matron.png")
	var ui := _ui(opening)
	await _click_to_choice(opening, ui)
	ui.call(&"select_choice_for_test", "kneel")
	await _click_until_closed(opening, ui)
	# Beat 2b: the calming duel with Lambert's fear.
	guard = 0
	while opening.call(&"host") == null and guard < 600:
		await process_frame
		guard += 1
	host = opening.call(&"host")
	if host != null:
		await _frames(60)
		await _save(out + "/lambert_duel.png")
		host.get(&"duel").call(&"tick", telegraph_sec)
		await _frames(3)
		host.call(&"pick_slot", 3)
		await _frames(40)
		await _save(out + "/lambert_word.png")
		host.call(&"close")
	# Beat 3: Kalev at the sickbed.
	await _frames(60)
	await _save(out + "/kalev_sickbed.png")
	ui = _ui(opening)
	if ui != null:
		await _click_to_choice(opening, ui)
		ui.call(&"select_choice_for_test", "stare")
		await _frames(2)
		ui.call(&"click_continue_for_test")
		await _frames(25)
		await _save(out + "/kalev_charm.png")
		await _click_to_choice(opening, ui)
		await _frames(20)
		await _save(out + "/kalev_reply.png")
	quit()


func _ui(opening: Node) -> Node:
	var found: Node = null
	for child in opening.get_children():
		if child.has_method(&"click_continue_for_test") and not child.is_queued_for_deletion():
			found = child
	return found


func _click_to_choice(opening: Node, ui: Node) -> void:
	var guard := 0
	var runner: Node = opening.call(&"dialogue_runner")
	while runner != null and not runner.call(&"is_waiting_for_choice") and guard < 20:
		ui.call(&"click_continue_for_test")
		await _frames(2)
		guard += 1


func _click_until_closed(opening: Node, ui: Node) -> void:
	var guard := 0
	var runner: Node = opening.call(&"dialogue_runner")
	while runner != null and is_instance_valid(runner) and runner.call(&"is_active") and guard < 20:
		ui.call(&"click_continue_for_test")
		await _frames(2)
		guard += 1


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("CAPTURED ", path)
