class_name SpiritArenaHost
extends CanvasLayer
## Screen host for a SpiritDuel (ADR 0033, SD-04). Opening it freezes the world
## (SceneTree.paused) and shows the line, composure/pressure bars, a telegraph arc with
## guard/dodge prompts for incoming blows, and the replies as a hotbar of spell cards with
## a countdown ring (SD-18); closing restores the previous pause state. Input: hold
## `player_guard`, press `player_dodge`, `interact` continues a spoken line, slot keys
## `spellforge_element_1..5` pick cards. Keyboard/mouse and gamepad both work through the
## existing input actions and focusable cards.

signal opened(dialogue_id: StringName)
signal closed(outcome: Dictionary)

const BAR_SIZE := Vector2(260.0, 14.0)
const OBSERVE_BEAT_SEC := 2.4
## Typing speed of a cast reply's spoken caption when there are no dialogue settings.
const CAPTION_CHARS_PER_SEC := 48.0
## Full-screen tint over the world while the arena is open (was an opaque 0.82 curtain).
const DIM_ALPHA := 0.22
## Height of the darker top and bottom frame bands, as a share of the screen height.
const FRAME_TOP_SHARE := 0.34
const FRAME_BOTTOM_SHARE := 0.5
const FRAME_ALPHA := 0.88
const SPELL_ACTIONS: Array[StringName] = [
	&"spellforge_element_1",
	&"spellforge_element_2",
	&"spellforge_element_3",
	&"spellforge_element_4",
	&"spellforge_element_5",
]

var duel := SpiritDuel.new()
var observation := SpiritObservation.new()
var freeze_world := true
## The 3D disc the duel is fought in, when attach_arena() was used.
var arena_3d: SpiritArena3D
## Real-time fighter positions (SA3D-2), when attach_arena() was given the hero.
var motion: SpiritArenaMotion
## Set before attach_arena() when the 3D fighters are glTF character rigs, whose model front is
## +Z (Godot's -Z convention would turn the opponent's back to the hero and misread guard facing).
var model_front_plus_z := false

var _runner: Node
var _was_paused := false
var _open := false
var _observing := false
var _observe_wait := 0.0
var _dim: ColorRect
var _spell_model: SpellforgeModel
var _spell_hint := ""
var _line_label: Label
var _move_label: Label
var _hint_label: Label
var _composure_bar: ProgressBar
var _pressure_bar: ProgressBar
var _telegraph_row: Control
var _telegraph_arc: SpiritTelegraphArc
var _telegraph_prompt: Label
var _reply_ring: SpiritReplyRing
var _caption_label: Label
var _caption_chars := 0.0
var _voice_player: AudioStreamPlayer
var _choices_box: HBoxContainer
## Presentation-only cast and blow effects (R-1332); bound while a duel is open.
var _vfx: SpiritArenaVfx
## The opponent's spirit form (R-1335), full screen behind the text column.
var _form_view: SpiritFormView
## Reply cards of the current hotbar in on-screen order (slot keys 1..n).
var _cards: Array[SpiritSpellCard] = []
## Enter/A is both `ui_accept` (picks the focused card) and `interact` (continues a line);
## the frame a reply was cast must not also skip the opponent's next line.
var _answered_frame := -1
var _decal: SpiritTelegraphDecal
var _hero_body: Node
var _opponent_body: Node
var _cell_size := 1
var _freeze_before := true


func _init() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()


func is_open() -> bool:
	return _open


## ADR 0038: fight inside a bounded 3D disc around `at` instead of over the frozen world. Call
## before open(); close() restores the hidden room. With a `hero` (SA3D-2) the duel is real time:
## the world is not paused and locomotion stays live, the hero is clamped to the disc, the
## `opponent` (optional; a virtual one stands 4 m off otherwise) moves by its line, telegraphs
## become floor decals and a blow lands by position and guard facing. A Node2D fighter is a
## logic-plane body mapped through MapViewBridge with `cell_size`; a Node3D one is used as is.
## `radius` sizes the disc (a small staged room uses less than the street default).
func attach_arena(
	world_root: Node, at: Vector3, keep: Array[Node3D], is_indoors: bool, hero: Node = null, opponent: Node = null, cell_size := 1, radius := SpiritArena3D.DEFAULT_RADIUS  # gdlint: ignore=max-line-length
) -> bool:
	detach_arena()
	arena_3d = SpiritArena3D.new()
	if not arena_3d.open(world_root, at, keep, is_indoors, radius):
		arena_3d.free()
		arena_3d = null
		return false
	if hero != null:
		_hero_body = hero
		_opponent_body = opponent
		_cell_size = maxi(1, cell_size)
		motion = SpiritArenaMotion.new(arena_3d)
		motion.hero_position = _read_position(hero, at)
		motion.opponent_position = (
			_read_position(opponent, at) if opponent != null else at + Vector3(0.0, 0.0, -4.0)
		)
		_decal = SpiritTelegraphDecal.new()
		arena_3d.add_child(_decal)
		duel.hit_check = motion.hit_check
		_freeze_before = freeze_world
		freeze_world = false
	return true


func detach_arena() -> void:
	if motion != null:
		duel.hit_check = Callable()
		freeze_world = _freeze_before
	motion = null
	_decal = null
	_hero_body = null
	_opponent_body = null
	if arena_3d != null and arena_3d.is_open():
		arena_3d.close()
	arena_3d = null


func telegraph_decal() -> SpiritTelegraphDecal:
	return _decal


## Open the arena for `dialogue_id`. False (and nothing changes) when it is not a duel.
func open(content_db: ContentDB, state: GameState, dialogue_id: StringName) -> bool:
	if _open:
		return false
	_runner = DialogueRunner.new()
	_runner.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_runner)
	_form_view.bind(duel)
	_form_view.visible = true
	duel.line_presented.connect(_on_line)
	duel.choices_ready.connect(_on_choices)
	duel.phase_changed.connect(_on_phase)
	duel.finished.connect(_on_finished)
	duel.exchange_resolved.connect(_on_exchange)
	duel.reply_pressure_enabled = _reply_pressure_setting()
	if not duel.begin(_runner, content_db, state, dialogue_id):
		_teardown()
		return false
	_open = true
	visible = true
	_enter_modal()
	_spell_model = SpellforgeModel.new() as SpellforgeModel
	_spell_model.configure(state, content_db)
	_show_spell_hint()
	if freeze_world and is_inside_tree():
		_was_paused = get_tree().paused
		get_tree().paused = true
	_vfx.bind(duel, self, _composure_bar, _pressure_bar)
	opened.emit(dialogue_id)
	_refresh_bars()
	return true


## Watch a conflict between other people as a spirit duel (no input needed; `interact`
## skips ahead). The hero learns the moves he sees and may side with a speaker once.
func observe(content_db: ContentDB, state: GameState, dialogue_id: StringName) -> bool:
	if _open:
		return false
	_runner = DialogueRunner.new()
	_runner.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_runner)
	observation.line_seen.connect(_on_line)
	observation.finished.connect(_on_observation_finished)
	if not observation.begin(_runner, content_db, state, dialogue_id):
		_teardown()
		return false
	_open = true
	_observing = true
	_observe_wait = OBSERVE_BEAT_SEC
	visible = true
	_enter_modal()
	if freeze_world and is_inside_tree():
		_was_paused = get_tree().paused
		get_tree().paused = true
	_hint_label.text = "You look closer... (interact to skip ahead)"
	_telegraph_row.visible = false
	_form_view.visible = false
	_composure_bar.visible = false
	_clear_choices()
	for speaker_id: Variant in _runner.get_participants():
		var button := Button.new()
		button.text = "Side with %s" % String(speaker_id)
		button.pressed.connect(
			func() -> void:
				if observation.intervene(StringName(String(speaker_id))):
					_hint_label.text = "You sided with %s" % String(speaker_id)
		)
		_choices_box.add_child(button)
	_refresh_bars()
	opened.emit(dialogue_id)
	return true


func close() -> void:
	if not _open:
		return
	# Closing mid-duel abandons it and leaves the spirit world.
	if _observing:
		observation.close()
	else:
		duel.close()
	var outcome := (observation.last_outcome if _observing else duel.last_outcome).duplicate()
	_open = false
	_observing = false
	_telegraph_row.visible = true
	_caption_label.text = ""
	_composure_bar.visible = true
	_leave_modal()
	_spell_model = null
	visible = false
	if freeze_world and is_inside_tree():
		get_tree().paused = _was_paused
	_teardown()
	detach_arena()
	closed.emit(outcome)


func _process(delta: float) -> void:
	if not _open:
		return
	if _observing:
		_observe_wait -= delta
		if Input.is_action_just_pressed(&"interact") or _observe_wait <= 0.0:
			_observe_wait = OBSERVE_BEAT_SEC
			if observation.is_over():
				if Input.is_action_just_pressed(&"interact"):
					close()
			else:
				observation.step()
		return
	_tick_motion(delta)
	duel.tick(delta)
	_process_spell_keys()
	_type_caption(delta)
	if duel.phase == SpiritDuel.PHASE_TELEGRAPH:
		duel.set_guard(Input.is_action_pressed(&"player_guard"))
		# In the 3D arena the dodge is the hero's own roll out of the zone, not i-frames.
		if motion == null and Input.is_action_just_pressed(&"player_dodge"):
			duel.dodge()
	elif (
		Input.is_action_just_pressed(&"interact")
		and Engine.get_process_frames() != _answered_frame
		and duel.acknowledge()
	):
		pass
	_refresh_bars()


## Number keys cast learned spells through the duel while the arena is open; the world
## Spellforge controller stands down because the arena counts as a modal overlay.
func _process_spell_keys() -> void:
	if _spell_model == null:
		return
	# While the reply hotbar is up the slot keys pick a card instead of casting loose magic,
	# so a spell reply's cast and its spoken line are always one act.
	if not _cards.is_empty():
		for index in mini(_cards.size(), SPELL_ACTIONS.size()):
			if InputMap.has_action(SPELL_ACTIONS[index]) and Input.is_action_just_pressed(SPELL_ACTIONS[index]):  # gdlint: ignore=max-line-length
				pick_slot(index)
				return
		return
	for index in SPELL_ACTIONS.size():
		if not InputMap.has_action(SPELL_ACTIONS[index]):
			continue
		if not Input.is_action_just_pressed(SPELL_ACTIONS[index]):
			continue
		# Defending must never also cast: the default gamepad slots 3 and 4 are the same
		# shoulder buttons as guard and dodge, so during a telegraph the defence wins.
		var telegraphing := duel.phase == SpiritDuel.PHASE_TELEGRAPH
		if telegraphing and _shares_defense_binding(SPELL_ACTIONS[index]):
			continue
		var spells := _spell_model.learned_spells()
		if index < spells.size():
			var result := duel.cast_spell(StringName(String(spells[index]["id"])))
			if bool(result.get("ok", false)):
				_hint_label.text = "%s cast." % String(spells[index].get("name", ""))
			else:
				_hint_label.text = "%s fails (%s)." % [
					String(spells[index].get("name", "")), String(result.get("reason", ""))
				]


func _show_spell_hint() -> void:
	var names: Array[String] = []
	var spells := _spell_model.learned_spells()
	for index in mini(spells.size(), SPELL_ACTIONS.size()):
		names.append("%d %s" % [index + 1, String(spells[index].get("name", ""))])
	_spell_hint = "Spells: " + ", ".join(names) if not names.is_empty() else ""


## A modal overlay freezes locomotion. The real-time arena must not (the hero moves), but it
## still keeps the world Spellforge quiet so a slot key is not cast twice.
func _enter_modal() -> void:
	var group := &"spell_input_overlay" if motion != null else &"modal_input_overlay"
	if not _dim.is_in_group(group):
		_dim.add_to_group(group)


func _leave_modal() -> void:
	for group: StringName in [&"modal_input_overlay", &"spell_input_overlay"]:
		if _dim.is_in_group(group):
			_dim.remove_from_group(group)


## SA3D-2: pull the hero back onto the disc, step the opponent's footwork, fill the decal.
func _tick_motion(delta: float) -> void:
	if motion == null:
		return
	_sync_hero()
	motion.step(delta)
	if _opponent_body != null and is_instance_valid(_opponent_body):
		_write_position(_opponent_body, motion.opponent_position)
		if _opponent_body is Node3D and (_opponent_body as Node3D).is_inside_tree():
			var look := Vector3(motion.hero_position.x, motion.opponent_position.y, motion.hero_position.z)
			if look.distance_to(motion.opponent_position) > 0.01:
				(_opponent_body as Node3D).look_at(look, Vector3.UP, model_front_plus_z)
	if _decal != null and _decal.visible:
		_decal.set_progress(duel.telegraph_progress())


func _sync_hero() -> void:
	if _hero_body == null or not is_instance_valid(_hero_body):
		return
	var read := _read_position(_hero_body, motion.hero_position)
	var clamped := motion.clamp_hero(read)
	if not clamped.is_equal_approx(read):
		_write_position(_hero_body, clamped)
	if _hero_body.has_method(&"facing_direction"):
		var facing: Vector2 = _hero_body.call(&"facing_direction")
		motion.hero_facing = Vector3(facing.x, 0.0, facing.y)
	elif _hero_body is Node3D:
		var basis_z := (_hero_body as Node3D).global_basis.z
		motion.hero_facing = basis_z if model_front_plus_z else -basis_z


func _read_position(body: Node, fallback: Vector3) -> Vector3:
	if body is Node3D:
		return (body as Node3D).global_position
	if body is Node2D:
		return MapViewBridge.logic_to_world((body as Node2D).global_position, _cell_size, fallback.y)
	return fallback


func _write_position(body: Node, at: Vector3) -> void:
	if body is Node3D:
		(body as Node3D).global_position = at
	elif body is Node2D:
		(body as Node2D).global_position = MapViewBridge.world_to_logic(at, _cell_size)


func _unhandled_input(event: InputEvent) -> void:
	if _open and event.is_action_pressed(&"interact") and duel.phase == SpiritDuel.PHASE_WON:
		if duel.acknowledge() or duel.is_over():
			close()
		get_viewport().set_input_as_handled()


func form_view() -> SpiritFormView:
	return _form_view


func vfx() -> SpiritArenaVfx:
	return _vfx


func _teardown() -> void:
	_vfx.unbind()
	_form_view.unbind()
	if observation.line_seen.is_connected(_on_line):
		observation.line_seen.disconnect(_on_line)
	if observation.finished.is_connected(_on_observation_finished):
		observation.finished.disconnect(_on_observation_finished)
	for connection: Array in [
		[duel.exchange_resolved, _on_exchange],
		[duel.line_presented, _on_line],
		[duel.choices_ready, _on_choices],
		[duel.phase_changed, _on_phase],
		[duel.finished, _on_finished],
	]:
		if (connection[0] as Signal).is_connected(connection[1]):
			(connection[0] as Signal).disconnect(connection[1])
	if _runner != null:
		_runner.queue_free()
		_runner = null


func _on_line(speaker_id: StringName, text: String, move: Dictionary) -> void:
	_line_label.text = ("%s: %s" % [String(speaker_id), text]) if _observing else text
	_move_label.text = ""
	if not move.is_empty():
		_move_label.text = "%s of %s" % [String(move.get("kind", "")), String(move.get("element", ""))]
	if speaker_id == duel.hero_id:
		_move_label.text = "you: " + _move_label.text
	elif motion != null:
		motion.set_line(move)
	if not _observing:
		_clear_choices()


func _on_choices(choices: Array) -> void:
	_clear_choices()
	for choice_value: Variant in choices:
		var choice: Dictionary = choice_value
		var spell_id := String(choice.get("spell_id", ""))
		var title := String(choice.get("text", ""))
		var cost_text := ""
		if not spell_id.is_empty():
			# The spell is the choice; the spoken line only voices it (the card's caption).
			var record := _content_db_spell(spell_id)
			var cost: Dictionary = record.get("cost", {})
			title = String(record.get("name", spell_id))
			cost_text = "%d %s" % [
				int(cost.get("amount", 0)),
				String(cost.get("resource", "resource.willpower")).trim_prefix("resource."),
			]
		var slot_action: StringName = (
			SPELL_ACTIONS[_cards.size()] if _cards.size() < SPELL_ACTIONS.size() else &""
		)
		var card := SpiritSpellCard.new()
		card.binding_hint = _binding_label(slot_action)
		card.setup(
			choice, title, cost_text, _slot_key_label(slot_action), duel.reply_block_reason(choice)
		)
		card.pressed.connect(_on_choice_pressed.bind(card.choice_id))
		_cards.append(card)
		_choices_box.add_child(card)
	_reply_ring.visible = duel.reply_pressure_enabled and not _cards.is_empty()
	for card in _cards:
		if not card.disabled:
			card.grab_focus()
			break


## Pick the reply card in hotbar slot `index` (0-based), as slot key `index + 1` does.
## A blocked card explains itself instead of casting. False when nothing was picked.
func pick_slot(index: int) -> bool:
	if index < 0 or index >= _cards.size():
		return false
	return _on_choice_pressed(_cards[index].choice_id)


## Reply cards currently on the hotbar (tests and captures).
func cards() -> Array[SpiritSpellCard]:
	return _cards.duplicate()


## The spoken line of the last cast reply as typed over the arena.
func cast_caption() -> String:
	return _caption_label.text


func _on_choice_pressed(choice_id: String) -> bool:
	var picked: SpiritSpellCard = null
	for card in _cards:
		if card.choice_id == choice_id:
			picked = card
	if picked != null and picked.disabled:
		_hint_label.text = picked.block_reason
		return false
	if not duel.answer(choice_id):
		if not duel.last_cast_failure.is_empty():
			_hint_label.text = SpellforgeModel.failure_text(duel.last_cast_failure)
		return false
	_answered_frame = Engine.get_process_frames()
	if picked != null and not picked.caption.is_empty():
		_show_caption(picked.caption)
		play_reply_voice(picked.voice_path)
	return true


## The cast reply's spoken line is typed out over the arena at the dialogue text speed
## (instant with reduced motion or instant text speed, Settings -> Dialogue).
func _show_caption(line: String) -> void:
	_caption_label.text = "\"%s\"" % line
	var dialogue: Object = _dialogue_settings()
	var instant := dialogue != null and bool(dialogue.call("reveal_instantly"))
	_caption_chars = 0.0
	_caption_label.visible_characters = -1 if instant else 0


func _type_caption(delta: float) -> void:
	if _caption_label.visible_characters < 0:
		return
	var dialogue: Object = _dialogue_settings()
	var speed := (
		float(dialogue.call("chars_per_second")) if dialogue != null else CAPTION_CHARS_PER_SEC
	)
	_caption_chars += delta * speed
	if _caption_chars >= _caption_label.text.length():
		_caption_label.visible_characters = -1
	else:
		_caption_label.visible_characters = int(_caption_chars)


## Voice cue hook: a reply with an offline `voice_path` is spoken on the Voice bus when the
## file exists and voice playback is on. No clip is authored yet, so today this is a no-op.
func play_reply_voice(path: String) -> bool:
	if path.is_empty() or not ResourceLoader.exists(path):
		return false
	var dialogue: Object = _dialogue_settings()
	if dialogue != null and not bool(dialogue.get("voice_enabled")):
		return false
	var stream := load(path) as AudioStream
	if stream == null:
		return false
	_voice_player.stream = stream
	_voice_player.play()
	return true


func _on_exchange(result: Dictionary) -> void:
	if String(result.get("kind", "")) == "hesitation":
		_hint_label.text = "You hesitate... the words come slower. Cast a reply."


## Bound keys for `action`, keyboard/mouse first then gamepad, e.g. "1 / X".
## `max_keys` trims the keyboard/mouse side when the line has no room for every alias.
func _binding_label(action: StringName, max_keys: int = 2) -> String:
	if action.is_empty() or not InputMap.has_action(action):
		return ""
	var keys: Array[String] = []
	var pads: Array[String] = []
	for event: InputEvent in InputMap.action_get_events(action):
		var label := InputBindingSettings.event_text(event)
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			pads.append(label)
		else:
			keys.append(label)
	return " / ".join(keys.slice(0, max_keys) + pads.slice(0, 1))


## True when `action` is bound to an event that guard or dodge also uses, so pressing it
## during a telegraph is a defence and not a cast.
func _shares_defense_binding(action: StringName) -> bool:
	for defense: StringName in [&"player_guard", &"player_dodge"]:
		if not InputMap.has_action(defense):
			continue
		for event: InputEvent in InputMap.action_get_events(action):
			if InputMap.action_has_event(defense, event):
				return true
	return false


## Just the keyboard key of `action` ("1"), for the narrow slot badge on a reply card.
func _slot_key_label(action: StringName) -> String:
	if action.is_empty() or not InputMap.has_action(action):
		return ""
	for event: InputEvent in InputMap.action_get_events(action):
		if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
			return InputBindingSettings.event_text(event)
	return ""


func _reply_pressure_setting() -> bool:
	var gameplay: Variant = _user_setting(&"gameplay")
	return gameplay == null or bool((gameplay as Object).get("reply_timer_pressure"))


func _dialogue_settings() -> Object:
	var dialogue: Variant = _user_setting(&"dialogue")
	return dialogue as Object if dialogue is Object else null


func _user_setting(property: StringName) -> Variant:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or not tree.root.has_node("UserSettings"):
		return null
	return tree.root.get_node("UserSettings").get(property)


func _content_db_spell(spell_id: String) -> Dictionary:
	if duel.content_db() == null:
		return {}
	return (
		duel.content_db().get_spell(StringName(spell_id))
		if spell_id.begins_with("spell.")
		else duel.content_db().get_rite(StringName(spell_id))
	)


func _on_phase(phase: StringName) -> void:
	if motion != null:
		if phase == SpiritDuel.PHASE_TELEGRAPH:
			_sync_hero()
			_decal.show_zone(motion.lock_zone(duel.incoming_move()), arena_3d.center)
		else:
			motion.clear_zone()
			_decal.hide_zone()
	match phase:
		SpiritDuel.PHASE_TELEGRAPH:
			_caption_label.text = ""
			if motion != null:
				_telegraph_prompt.text = "Guard [%s] facing them, or step out of the red" % (
					_binding_label(&"player_guard")
				)
			else:
				_telegraph_prompt.text = "Guard [%s] hold, parry in the gold    Dodge [%s]" % [
					_binding_label(&"player_guard"), _binding_label(&"player_dodge")
				]
			_hint_label.text = _spell_hint
		SpiritDuel.PHASE_ANSWER:
			# The gamepad slot buttons do not fit on the cards, so the hint names the
			# confirm binding that works for the focused card.
			_hint_label.text = "Cast a reply: slot key, click, or focus and confirm [%s]." % (
				_binding_label(&"ui_accept", 1)
			)
		SpiritDuel.PHASE_LINE:
			_hint_label.text = "Continue"
		SpiritDuel.PHASE_WON:
			_hint_label.text = "The duel is over. Continue"
		SpiritDuel.PHASE_LOST:
			_hint_label.text = "Your composure broke. Retry"
			_show_retry()


func _on_observation_finished(outcome: Dictionary) -> void:
	var learned: Array = outcome.get("moves_learned", [])
	_hint_label.text = "You learned: %s. Press interact to leave." % (
		", ".join(learned.map(func(id: Variant) -> String: return String(id))) if not learned.is_empty()
		else "nothing new"
	)
	_clear_choices()


func _on_finished(_outcome: Dictionary) -> void:
	_refresh_bars()


func _show_retry() -> void:
	_clear_choices()
	var button := Button.new()
	button.text = "Retry"
	button.pressed.connect(
		func() -> void:
			if duel.retry():
				_vfx.resync()
				_clear_choices()
	)
	_choices_box.add_child(button)
	button.grab_focus()


func _clear_choices() -> void:
	_cards.clear()
	_reply_ring.visible = false
	for child in _choices_box.get_children():
		_choices_box.remove_child(child)
		child.queue_free()


func _refresh_bars() -> void:
	_composure_bar.max_value = duel.hero.max_health
	_composure_bar.value = duel.hero.health
	_pressure_bar.max_value = duel.opponent.max_health
	_pressure_bar.value = duel.opponent.health
	var telegraphing := not _observing and duel.phase == SpiritDuel.PHASE_TELEGRAPH
	# In the 3D arena the floor decal is the telegraph (ADR 0038); the 2D arc stays for the overlay.
	_telegraph_arc.visible = telegraphing and motion == null
	_telegraph_prompt.visible = telegraphing
	_telegraph_arc.progress = duel.telegraph_progress()
	if duel.telegraph_sec > 0.0:
		_telegraph_arc.parry_fraction = duel.hero.parry_window_sec / duel.telegraph_sec
	_reply_ring.progress = duel.reply_window_progress()


func _build_ui() -> void:
	# A light spirit-world tint instead of an opaque curtain, so the staged scene behind the
	# duel (almshouse hall, frozen street) stays readable (R-1334). Dark bands at the top and
	# bottom keep the text legible where the UI sits; the middle stays clear for the actors.
	_dim = ColorRect.new()
	_dim.color = Color(0.05, 0.04, 0.10, DIM_ALPHA)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	_add_frame_band(true)
	_add_frame_band(false)
	_form_view = SpiritFormView.new()
	_form_view.name = "SpiritForm"
	add_child(_form_view)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 80.0
	column.offset_right = -80.0
	column.offset_top = 60.0
	column.offset_bottom = -60.0
	column.add_theme_constant_override("separation", 14)
	add_child(column)
	_pressure_bar = _make_bar(column, "Their pressure", Color(0.75, 0.30, 0.28))
	_line_label = Label.new()
	_line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line_label.add_theme_font_size_override("font_size", 26)
	column.add_child(_line_label)
	_move_label = Label.new()
	column.add_child(_move_label)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	_telegraph_row = VBoxContainer.new()
	column.add_child(_telegraph_row)
	_telegraph_arc = SpiritTelegraphArc.new()
	_telegraph_arc.name = "TelegraphArc"
	_telegraph_arc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_telegraph_row.add_child(_telegraph_arc)
	_telegraph_prompt = Label.new()
	_telegraph_prompt.name = "TelegraphPrompt"
	_telegraph_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_telegraph_prompt.add_theme_font_size_override("font_size", 18)
	_telegraph_prompt.add_theme_color_override("font_color", SpiritTelegraphArc.PARRY)
	_telegraph_row.add_child(_telegraph_prompt)
	_caption_label = Label.new()
	_caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption_label.add_theme_font_size_override("font_size", 20)
	_caption_label.add_theme_color_override("font_color", Color(0.98, 0.90, 0.70))
	column.add_child(_caption_label)
	var reply_row := HBoxContainer.new()
	reply_row.alignment = BoxContainer.ALIGNMENT_CENTER
	reply_row.add_theme_constant_override("separation", 12)
	column.add_child(reply_row)
	_reply_ring = SpiritReplyRing.new()
	_reply_ring.name = "ReplyRing"
	_reply_ring.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_reply_ring.visible = false
	reply_row.add_child(_reply_ring)
	_choices_box = HBoxContainer.new()
	_choices_box.add_theme_constant_override("separation", 10)
	reply_row.add_child(_choices_box)
	_voice_player = AudioStreamPlayer.new()
	_voice_player.bus = AudioBusService.BUS_VOICE
	add_child(_voice_player)
	_hint_label = Label.new()
	_hint_label.name = "Hint"
	column.add_child(_hint_label)
	_composure_bar = _make_bar(column, "Your composure", Color(0.40, 0.65, 0.85))
	# Above the text column so numbers and flashes read over the bars.
	_vfx = SpiritArenaVfx.new()
	_vfx.name = "ArenaVfx"
	add_child(_vfx)


func _add_frame_band(top: bool) -> void:
	var gradient := Gradient.new()
	var dark := Color(0.03, 0.02, 0.06, FRAME_ALPHA)
	var clear := Color(dark, 0.0)
	gradient.colors = PackedColorArray([dark, clear] if top else [clear, dark])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	texture.width = 4
	texture.height = 64
	var band := TextureRect.new()
	band.texture = texture
	band.stretch_mode = TextureRect.STRETCH_SCALE
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.anchor_left = 0.0
	band.anchor_right = 1.0
	band.anchor_top = 0.0 if top else 1.0 - FRAME_BOTTOM_SHARE
	band.anchor_bottom = FRAME_TOP_SHARE if top else 1.0
	add_child(band)


func _make_bar(parent: Control, caption: String, color: Color) -> ProgressBar:
	var label := Label.new()
	label.text = caption
	parent.add_child(label)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = BAR_SIZE
	bar.show_percentage = false
	bar.add_theme_stylebox_override("fill", _fill_style(color))
	parent.add_child(bar)
	return bar


func _fill_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	return style
