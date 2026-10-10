extends "res://tests/godot/test_case.gd"

## SD-18 (R-1333): the spirit arena shows replies as a hotbar of spell cards picked by slot key,
## gamepad (slot button or focus + confirm) and mouse; short willpower disables a card with a
## reason; the reply countdown chips composure once and can be switched off; the telegraph arc
## prompts with the bound guard/dodge keys; a reply's voice clip plays through the hook.

const CONFRONT := &"dialogue.prologue.porter_confrontation"
const CONTENT_DIRS: Array[String] = [
	"res://content/prologue",
	"res://content/examples/valid",
	"res://content/examples/support",
]
const VOICE_SAMPLE := "res://sounds/door.mp3"

var _state: GameState
var _db: ContentDB
var _host: SpiritArenaHost


func before_each() -> void:
	super.before_each()
	# Start every test on a fresh frame: an action stays "just pressed" for the whole frame
	# it was pressed in, so a tap from the previous test would otherwise reach this host.
	await _tree().process_frame
	_state = GameState.new()
	_db = ContentDB.new()
	assert_true(_db.load_from_directories(CONTENT_DIRS))
	for grant_id: StringName in AlmshouseOpening.STARTER_GRANTS:
		MagicResolver.apply_grant_operation(_state, _db, grant_id)
	_state.set_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER, 8)
	_host = SpiritArenaHost.new()
	_host.freeze_world = false
	_tree().root.add_child(_host)


func after_each() -> void:
	if is_instance_valid(_host):
		_host.close()
		_host.free()
	UserSettings.reload_gameplay_accessibility_settings()
	super.after_each()


func test_replies_are_spell_cards_with_cost_key_colour_and_caption() -> void:
	_open_to_answer()
	var cards := _host.cards()
	assert_eq(cards.size(), 4)
	var fire := cards[0]
	assert_eq(fire.choice_id, "fire_hands")
	assert_eq(fire.spell_id, "spell.pagan.fireball")
	assert_true(fire.caption.begins_with("Look at your own hands"), "voiced line is the caption")
	assert_ne(fire.element_color, SpiritSpellCard.NEUTRAL_COLOR, "shame element colour")
	assert_false(fire.disabled)
	assert_true(fire.has_focus(), "first castable card takes focus for gamepad")
	assert_true(_card_text(fire).contains("2 willpower"), "cost on the card")
	assert_true(_card_text(fire).contains(_first_key(&"spellforge_element_1")), "slot key shown")
	var shove := cards[3]
	assert_eq(shove.spell_id, "")
	assert_eq(shove.caption, "", "a plain reply has no spoken caption")
	assert_true((_host.find_child("ReplyRing", true, false) as Control).visible)


func test_slot_key_casts_its_card_and_types_the_caption() -> void:
	_open_to_answer()
	_tap(&"spellforge_element_2")
	assert_ne(_host.duel.phase, SpiritDuel.PHASE_ANSWER, "key 2 cast the iron skin reply")
	assert_eq(_willpower(), 6)
	assert_true(_host.cast_caption().contains("Your rod does not frighten me"))


func test_gamepad_slot_button_casts_its_card() -> void:
	var pad := _first_pad_event(&"spellforge_element_1")
	if pad == null:
		skip("spellforge_element_1 has no gamepad binding")
		return
	_open_to_answer()
	pad.pressed = true
	Input.parse_input_event(pad)
	Input.flush_buffered_events()
	_host._process(0.0)
	var release := pad.duplicate() as InputEventJoypadButton
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	assert_ne(_host.duel.phase, SpiritDuel.PHASE_ANSWER, "gamepad slot 1 cast fireball")
	assert_eq(_willpower(), 6)


func test_gamepad_focus_and_confirm_picks_the_focused_card() -> void:
	var confirm := _first_pad_event(&"ui_accept")
	if confirm == null:
		skip("ui_accept has no gamepad binding")
		return
	_open_to_answer()
	assert_true(_host.cards()[0].has_focus())
	_push(confirm)
	assert_ne(_host.duel.phase, SpiritDuel.PHASE_ANSWER, "confirm on the focused card casts it")
	assert_true(_host.cast_caption().contains("Look at your own hands"))


func test_mouse_click_picks_a_card() -> void:
	_open_to_answer()
	# One await only: the harness follows a test's first await, not later ones.
	await _tree().process_frame
	var card := _host.cards()[2]
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = card.get_global_rect().get_center()
	click.global_position = click.position
	click.pressed = true
	_tree().root.push_input(click, true)
	click.pressed = false
	_tree().root.push_input(click, true)
	assert_ne(_host.duel.phase, SpiritDuel.PHASE_ANSWER, "click cast earth tremor")
	assert_true(_host.cast_caption().contains("Stand still"))


func test_short_willpower_disables_spell_cards_with_a_reason() -> void:
	_state.set_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER, 0)
	_open_to_answer()
	var cards := _host.cards()
	for index in 3:
		assert_true(cards[index].disabled, "spell card %d disabled" % index)
		assert_true(cards[index].block_reason.contains("willpower"), cards[index].block_reason)
		assert_eq(cards[index].tooltip_text, cards[index].block_reason)
	assert_false(cards[3].disabled, "the plain reply stays available")
	assert_true(cards[3].has_focus(), "focus skips disabled cards")
	_tap(&"spellforge_element_1")
	assert_eq(_host.duel.phase, SpiritDuel.PHASE_ANSWER, "a blocked card does not cast")
	assert_eq(_willpower(), 0)
	assert_true(_hint().contains("willpower"), "the hint explains why")
	assert_false(_host.pick_slot(0))


func test_cards_recheck_willpower_each_round() -> void:
	_state.set_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER, 3)
	_open_to_answer()
	assert_true(_host.pick_slot(0), "fireball for 2")
	_host.duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_eq(_host.duel.phase, SpiritDuel.PHASE_ANSWER)
	var cards := _host.cards()
	assert_true(cards[0].disabled, "1 willpower left is not enough")
	assert_false(cards[3].disabled, "say nothing still works")


func test_reply_timer_chips_composure_once_and_keeps_the_window_open() -> void:
	_open_to_answer()
	assert_true(_host.duel.reply_pressure_enabled)
	var before := _host.duel.hero.health
	_host.duel.tick(SpiritDuel.REPLY_WINDOW_SEC * 0.5)
	assert_almost_eq(_host.duel.reply_window_progress(), 0.5, 0.001)
	_host.duel.tick(SpiritDuel.REPLY_WINDOW_SEC)
	assert_eq(_host.duel.hero.health, before - SpiritDuel.HESITATION_COMPOSURE)
	_host.duel.tick(SpiritDuel.REPLY_WINDOW_SEC * 3.0)
	assert_eq(_host.duel.hero.health, before - SpiritDuel.HESITATION_COMPOSURE, "only once")
	assert_eq(_host.duel.phase, SpiritDuel.PHASE_ANSWER, "not a hard timeout")
	assert_true(_hint().contains("hesitate"))
	assert_true(_host.pick_slot(0), "the replies are still open")


func test_hesitation_never_breaks_composure() -> void:
	_open_to_answer()
	_host.duel.hero.health = 3.0
	_host.duel.tick(SpiritDuel.REPLY_WINDOW_SEC + 1.0)
	assert_eq(_host.duel.hero.health, 1.0)
	assert_eq(_host.duel.phase, SpiritDuel.PHASE_ANSWER)


func test_accessibility_setting_turns_the_reply_timer_off() -> void:
	var gameplay = UserSettings.gameplay.duplicate_settings()
	gameplay.reply_timer_pressure = false
	UserSettings.apply_gameplay_accessibility_settings(gameplay, false)
	_open_to_answer()
	assert_false(_host.duel.reply_pressure_enabled)
	assert_false((_host.find_child("ReplyRing", true, false) as Control).visible, "no ring")
	var before := _host.duel.hero.health
	_host.duel.tick(SpiritDuel.REPLY_WINDOW_SEC * 5.0)
	assert_eq(_host.duel.hero.health, before)
	assert_eq(_host.duel.reply_window_progress(), 0.0)


func test_telegraph_arc_prompts_with_the_bound_guard_and_dodge_keys() -> void:
	assert_true(_host.open_scripted(_db, _state, CONFRONT))
	assert_eq(_host.duel.phase, SpiritDuel.PHASE_TELEGRAPH)
	_host._process(0.0)
	var arc := _host.find_child("TelegraphArc", true, false) as SpiritTelegraphArc
	var prompt := _host.find_child("TelegraphPrompt", true, false) as Label
	assert_true(arc.visible and prompt.visible)
	assert_true(prompt.text.contains(_first_key(&"player_guard")), prompt.text)
	assert_true(prompt.text.contains(_first_key(&"player_dodge")), prompt.text)
	_host.duel.tick(SpiritDuel.TELEGRAPH_SEC * 0.5)
	_host._process(0.0)
	assert_almost_eq(arc.progress, 0.5, 0.01)
	_host.duel.tick(SpiritDuel.TELEGRAPH_SEC)
	_host._process(0.0)
	assert_false(arc.visible, "no arc while answering")


func test_gamepad_guard_during_a_telegraph_does_not_also_cast_its_slot_spell() -> void:
	# The default gamepad guard and slot 3 are both the left shoulder: defending must not
	# spend willpower on Iron Skin.
	var guard_pad := _first_pad_event(&"player_guard")
	if guard_pad == null or not _shares_pad(&"spellforge_element_3", guard_pad):
		skip("guard and slot 3 do not share a gamepad button")
		return
	assert_true(_host.open_scripted(_db, _state, CONFRONT))
	assert_eq(_host.duel.phase, SpiritDuel.PHASE_TELEGRAPH)
	guard_pad.pressed = true
	Input.parse_input_event(guard_pad)
	Input.flush_buffered_events()
	_host._process(0.0)
	assert_eq(_willpower(), 8, "guarding cast nothing")
	assert_true(_host.duel._guard_elapsed >= 0.0, "the press guarded instead")
	var release := guard_pad.duplicate() as InputEventJoypadButton
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()


func _shares_pad(action: StringName, event: InputEvent) -> bool:
	return InputMap.has_action(action) and InputMap.action_has_event(action, event)


func test_voice_hook_plays_an_existing_clip_only() -> void:
	assert_false(_host.play_reply_voice(""))
	assert_false(_host.play_reply_voice("res://does/not/exist.ogg"))
	if not ResourceLoader.exists(VOICE_SAMPLE):
		skip("sample clip missing")
		return
	var dialogue = UserSettings.dialogue
	var voice_was: bool = dialogue.voice_enabled
	dialogue.voice_enabled = true
	assert_true(_host.play_reply_voice(VOICE_SAMPLE))
	dialogue.voice_enabled = false
	assert_false(_host.play_reply_voice(VOICE_SAMPLE), "voice playback off")
	dialogue.voice_enabled = voice_was


func _open_to_answer() -> void:
	assert_true(_host.open_scripted(_db, _state, CONFRONT))
	_host.duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_eq(_host.duel.phase, SpiritDuel.PHASE_ANSWER)


func _willpower() -> int:
	return _state.get_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER)


func _hint() -> String:
	return (_host.find_child("Hint", true, false) as Label).text


func _card_text(card: Control) -> String:
	var parts: Array[String] = []
	for label: Node in card.find_children("*", "Label", true, false):
		parts.append((label as Label).text)
	return " ".join(parts)


func _first_key(action: StringName) -> String:
	for event: InputEvent in InputMap.action_get_events(action):
		if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
			return InputBindingSettings.event_text(event)
	return ""


func _first_pad_event(action: StringName) -> InputEventJoypadButton:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			return (event as InputEventJoypadButton).duplicate() as InputEventJoypadButton
	return null


func _tap(action: StringName) -> void:
	Input.action_press(action)
	_host._process(0.0)
	Input.action_release(action)


func _push(event: InputEvent) -> void:
	event.pressed = true
	_tree().root.push_input(event, true)
	event.pressed = false
	_tree().root.push_input(event, true)


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree
