extends Node

## Review plates for talking with anyone in the seamless city (R-1885..R-1889, ADR 0047): the
## named-NPC card, a resident conversation (two-shot, the hero choosing, the close shot on the
## speaker), the inner-eye reply rising to the play view and the spirit duel. Host scene so
## autoloads resolve:
##   tools/godot_render.sh --resolution 1600x900 res://tools/capture_character_talk.tscn \
##     -- --city-spawn=poi.forum --city-hour=10 [--out=res://build/character_talk]

const SCENE := preload("res://scenes/world/reval_city/reval_city.tscn")


func _ready() -> void:
	call_deferred("_run")


func _arg(prefix: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.trim_prefix(prefix)
	return fallback


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("saved ", path)


func _run() -> void:
	var out := _arg("--out=", "res://build/character_talk")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var city: Node = SCENE.instantiate()
	add_child(city)
	var pinned := float(_arg("--city-hour=", "-1"))
	for _i in 240:
		if pinned >= 0.0 and city.runtime != null:
			city.runtime.cycle_progress = pinned / 24.0
		await get_tree().process_frame
	var citizens := city.find_child("CityCitizens", true, false) as CityCitizens
	var named := city.find_child("CityNamedNpcs", true, false) as CityNamedNpcs
	var player: Node2D = citizens.player
	# 1. The named-NPC card (faction / alignment row) over the street.
	if named != null and named.live_count() > 0:
		var npc: NamedNpcActor = named.live_actors()[0]
		named.select(npc)
		await _frames(10)
		await _save(out + "/card_named.png")
		citizens.info_panel().hide_panel()
	# 2. Walk up to the nearest grown resident in the open and talk.
	var best: CitizenActor = null
	var best_d := INF
	for actor in citizens.live_actors():
		if not actor.outdoors or actor.at_home or int(actor.record["age"]) < 18:
			continue
		var d := actor.global_position.distance_to(player.global_position)
		if d < best_d:
			best = actor
			best_d = d
	if best == null:
		push_error("no resident outdoors")
		get_tree().quit(1)
		return
	player.global_position = best.global_position + Vector2(48, 24)
	await _frames(30)
	var conversation := citizens.activate(best, true)
	if conversation == null:
		push_error("no conversation opened")
		get_tree().quit(1)
		return
	print("talking to ", best.record["name"])
	await _frames(40)
	await _save(out + "/talk_two_shot.png")
	var ui := conversation.ui
	var guard := 0
	while not conversation.runner.is_waiting_for_choice() and guard < 10:
		ui.click_continue_for_test()
		guard += 1
	await _frames(10)
	await _save(out + "/talk_choices.png")
	ui.select_choice_for_test("who")
	await _frames(10)
	await _save(out + "/talk_close.png")
	guard = 0
	while not conversation.runner.is_waiting_for_choice() and guard < 10:
		ui.click_continue_for_test()
		guard += 1
	ui.select_choice_for_test(CharacterConversation.INNER_EYE_CHOICE)
	await _frames(5)
	await _save(out + "/talk_inner_eye.png")
	guard = 0
	while conversation.runner != null and conversation.runner.is_active() and guard < 10:
		ui.click_continue_for_test()
		guard += 1
	await get_tree().create_timer(0.55).timeout
	await _save(out + "/talk_crane.png")
	await get_tree().create_timer(1.6).timeout
	await _frames(30)
	await _save(out + "/talk_duel.png")
	print("stage ", conversation.stage)
	if conversation.host != null:
		conversation.host.close()
	await _frames(10)
	get_tree().quit()
