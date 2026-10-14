extends Node

## Review plates for SPL-2 (R-1914, ADR 0048): a spirit duel with a resident won by trust. The
## hero opens the duel through the inner-eye reply, puts raising spells in the cast bar (the SPL-4
## loadout hook), and eases the person with free strikes until the trust meter fills and the duel
## ends `resolved_eased`. Plates: the meter mid-duel with the raise/lower arrows, then the win.
## Host scene so autoloads resolve:
##   tools/godot_render.sh --resolution 1600x900 res://tools/capture_spirit_trust_win.tscn \
##     -- --city-spawn=poi.forum --city-hour=10 [--out=res://build/spirit_trust_win]

const SCENE := preload("res://scenes/world/reval_city/reval_city.tscn")
## Raising spells for the first four slots; slot 5 keeps its lowering starter for contrast.
const LOADOUT: Array[StringName] = [
	&"spell.word.comfort",
	&"spell.word.praise",
	&"spell.word.listen",
	&"spell.word.shared_prayer",
]
const MAX_CASTS := 40
## Replies a raising word must not answer: they leave the duel or break the person.
const AVOID_REPLIES: Array[String] = ["break", "step_back"]


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
	var out := _arg("--out=", "res://build/spirit_trust_win")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var city: Node = SCENE.instantiate()
	add_child(city)
	var pinned := float(_arg("--city-hour=", "-1"))
	for _i in 240:
		if pinned >= 0.0 and city.runtime != null:
			city.runtime.cycle_progress = pinned / 24.0
		await get_tree().process_frame
	var citizens := city.find_child("CityCitizens", true, false) as CityCitizens
	var player: Node2D = citizens.player
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
	print("duelling ", best.record["name"])
	# Into the duel through the inner-eye reply, as in capture_character_talk.gd.
	var ui := conversation.ui
	var guard := 0
	while not conversation.runner.is_waiting_for_choice() and guard < 10:
		ui.click_continue_for_test()
		guard += 1
	ui.select_choice_for_test(CharacterConversation.INNER_EYE_CHOICE)
	guard = 0
	while conversation.runner != null and conversation.runner.is_active() and guard < 10:
		ui.click_continue_for_test()
		guard += 1
	await get_tree().create_timer(2.2).timeout
	await _frames(30)
	var host := conversation.host
	if host == null or host.words == null:
		push_error("the duel did not open in the real-time arena")
		get_tree().quit(1)
		return
	# Willpower is SPL-3's business; keep the purse full so the plates show only trust.
	SessionState.state.set_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER, 99)
	for slot in LOADOUT.size():
		host.words.set_slot_spell(slot, LOADOUT[slot])
	var casts := 0
	var saved_meter := false
	while not host.duel.is_over() and casts < MAX_CASTS:
		# Hold the hero's composure so the opponent's blows cannot end the plate early.
		host.duel.hero.health = host.duel.hero.max_health
		var slot := _pick_slot(host)
		if slot >= 0 and host.cast_word(slot):
			casts += 1
			print("cast %s (%s)" % [host.words.spell_ids[slot], host.duel.phase])
		await _frames(40)
		if host.duel.phase == SpiritDuel.PHASE_LINE:
			host.duel.acknowledge()
		if not saved_meter and host.duel.trust >= 40.0:
			await _save(out + "/trust_meter.png")
			saved_meter = true
		print("trust %.1f after %d casts, lights %s" % [host.duel.trust, casts, host.duel.duel_levels])
	await _frames(20)
	print("ending ", host.duel.ending(), " trust ", host.duel.trust)
	await _save(out + "/trust_win.png")
	get_tree().quit(0 if host.duel.ending() == SpiritDuel.ENDING_EASED else 1)


## A free strike first (a raising word that answers no reply builds trust without moving the
## talk); else a raising word that answers a reply other than breaking or leaving. -1: wait.
func _pick_slot(host: SpiritArenaHost) -> int:
	var answering := -1
	for slot in mini(LOADOUT.size(), host.words.slot_count()):
		if not host.words.block_reason(slot).is_empty():
			continue
		var choice := host.words.answering_choice(slot)
		if choice.is_empty():
			return slot
		if answering < 0 and not AVOID_REPLIES.has(String(choice.get("id", ""))):
			answering = slot
	return answering
