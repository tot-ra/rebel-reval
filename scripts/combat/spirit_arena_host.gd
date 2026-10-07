class_name SpiritArenaHost
extends CanvasLayer
## Screen host for a SpiritDuel (ADR 0033, SD-04). Opening it freezes the world
## (SceneTree.paused) and shows the telegraphed line, composure/pressure bars and
## the reply wheel; closing restores the previous pause state. Input: hold
## `player_guard`, press `player_dodge`, `interact` continues a spoken line.
## Keyboard/mouse and gamepad both work through the existing input actions and
## focusable buttons.

signal opened(dialogue_id: StringName)
signal closed(outcome: Dictionary)

const BAR_SIZE := Vector2(260.0, 14.0)
const OBSERVE_BEAT_SEC := 2.4
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
var _telegraph_bar: ProgressBar
var _choices_box: VBoxContainer


func _init() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()


func is_open() -> bool:
	return _open


## Open the arena for `dialogue_id`. False (and nothing changes) when it is not a duel.
func open(content_db: ContentDB, state: GameState, dialogue_id: StringName) -> bool:
	if _open:
		return false
	_runner = DialogueRunner.new()
	_runner.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_runner)
	duel.line_presented.connect(_on_line)
	duel.choices_ready.connect(_on_choices)
	duel.phase_changed.connect(_on_phase)
	duel.finished.connect(_on_finished)
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
	_telegraph_bar.visible = false
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
	_telegraph_bar.visible = true
	_composure_bar.visible = true
	_leave_modal()
	_spell_model = null
	visible = false
	if freeze_world and is_inside_tree():
		get_tree().paused = _was_paused
	_teardown()
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
	duel.tick(delta)
	_process_spell_keys()
	if duel.phase == SpiritDuel.PHASE_TELEGRAPH:
		duel.set_guard(Input.is_action_pressed(&"player_guard"))
		if Input.is_action_just_pressed(&"player_dodge"):
			duel.dodge()
	elif Input.is_action_just_pressed(&"interact") and duel.acknowledge():
		pass
	_refresh_bars()


## Number keys cast learned spells through the duel while the arena is open; the world
## Spellforge controller stands down because the arena counts as a modal overlay.
func _process_spell_keys() -> void:
	if _spell_model == null:
		return
	for index in SPELL_ACTIONS.size():
		if not InputMap.has_action(SPELL_ACTIONS[index]):
			continue
		if not Input.is_action_just_pressed(SPELL_ACTIONS[index]):
			continue
		var spells := _spell_model.learned_spells()
		if index < spells.size():
			var result := duel.cast_spell(StringName(String(spells[index]["id"])))
			if bool(result.get("ok", false)):
				_hint_label.text = "%s cast." % String(spells[index].get("name", ""))


func _show_spell_hint() -> void:
	var names: Array[String] = []
	var spells := _spell_model.learned_spells()
	for index in mini(spells.size(), SPELL_ACTIONS.size()):
		names.append("%d %s" % [index + 1, String(spells[index].get("name", ""))])
	_spell_hint = "Spells: " + ", ".join(names) if not names.is_empty() else ""


func _enter_modal() -> void:
	if not _dim.is_in_group(&"modal_input_overlay"):
		_dim.add_to_group(&"modal_input_overlay")


func _leave_modal() -> void:
	if _dim.is_in_group(&"modal_input_overlay"):
		_dim.remove_from_group(&"modal_input_overlay")


func _unhandled_input(event: InputEvent) -> void:
	if _open and event.is_action_pressed(&"interact") and duel.phase == SpiritDuel.PHASE_WON:
		if duel.acknowledge() or duel.is_over():
			close()
		get_viewport().set_input_as_handled()


func _teardown() -> void:
	if observation.line_seen.is_connected(_on_line):
		observation.line_seen.disconnect(_on_line)
	if observation.finished.is_connected(_on_observation_finished):
		observation.finished.disconnect(_on_observation_finished)
	for connection: Array in [
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
	if not _observing:
		_clear_choices()


func _on_choices(choices: Array) -> void:
	_clear_choices()
	for choice_value: Variant in choices:
		var choice: Dictionary = choice_value
		var move: Dictionary = choice.get("move", {})
		var button := Button.new()
		button.text = String(choice.get("text", ""))
		if not move.is_empty():
			button.text += "  [%s / %s]" % [move.get("kind", ""), move.get("element", "")]
		button.disabled = not bool(choice.get("enabled", false))
		button.pressed.connect(_on_choice_pressed.bind(String(choice.get("id", ""))))
		_choices_box.add_child(button)
	for child in _choices_box.get_children():
		if not (child as Button).disabled:
			(child as Button).grab_focus()
			break


func _on_choice_pressed(choice_id: String) -> void:
	duel.answer(choice_id)


func _on_phase(phase: StringName) -> void:
	match phase:
		SpiritDuel.PHASE_TELEGRAPH:
			_hint_label.text = (
				"Hold guard (parry just before the blow) or press dodge. " + _spell_hint
			)
		SpiritDuel.PHASE_ANSWER:
			_hint_label.text = "Choose a reply. " + _spell_hint
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
				_clear_choices()
	)
	_choices_box.add_child(button)
	button.grab_focus()


func _clear_choices() -> void:
	for child in _choices_box.get_children():
		_choices_box.remove_child(child)
		child.queue_free()


func _refresh_bars() -> void:
	_composure_bar.max_value = duel.hero.max_health
	_composure_bar.value = duel.hero.health
	_pressure_bar.max_value = duel.opponent.max_health
	_pressure_bar.value = duel.opponent.health
	_telegraph_bar.value = duel.telegraph_progress()


func _build_ui() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0.05, 0.04, 0.10, 0.82)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
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
	_telegraph_bar = _make_bar(column, "Blow", Color(0.90, 0.75, 0.35))
	_telegraph_bar.max_value = 1.0
	_choices_box = VBoxContainer.new()
	column.add_child(_choices_box)
	_hint_label = Label.new()
	column.add_child(_hint_label)
	_composure_bar = _make_bar(column, "Your composure", Color(0.40, 0.65, 0.85))


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
