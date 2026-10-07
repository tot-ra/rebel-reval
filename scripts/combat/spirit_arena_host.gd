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

var duel := SpiritDuel.new()
var freeze_world := true

var _runner: Node
var _was_paused := false
var _open := false
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
	if freeze_world and is_inside_tree():
		_was_paused = get_tree().paused
		get_tree().paused = true
	opened.emit(dialogue_id)
	_refresh_bars()
	return true


func close() -> void:
	if not _open:
		return
	var outcome := duel.last_outcome.duplicate()
	_open = false
	visible = false
	if freeze_world and is_inside_tree():
		get_tree().paused = _was_paused
	_teardown()
	closed.emit(outcome)


func _process(delta: float) -> void:
	if not _open:
		return
	duel.tick(delta)
	if duel.phase == SpiritDuel.PHASE_TELEGRAPH:
		duel.set_guard(Input.is_action_pressed(&"player_guard"))
		if Input.is_action_just_pressed(&"player_dodge"):
			duel.dodge()
	elif Input.is_action_just_pressed(&"interact") and duel.acknowledge():
		pass
	_refresh_bars()


func _unhandled_input(event: InputEvent) -> void:
	if _open and event.is_action_pressed(&"interact") and duel.phase == SpiritDuel.PHASE_WON:
		if duel.acknowledge() or duel.is_over():
			close()
		get_viewport().set_input_as_handled()


func _teardown() -> void:
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
	_line_label.text = text
	_move_label.text = ""
	if not move.is_empty():
		_move_label.text = "%s of %s" % [String(move.get("kind", "")), String(move.get("element", ""))]
	if speaker_id == duel.hero_id:
		_move_label.text = "you: " + _move_label.text
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
			_hint_label.text = "Hold guard (parry just before the blow) or press dodge"
		SpiritDuel.PHASE_ANSWER:
			_hint_label.text = "Choose a reply"
		SpiritDuel.PHASE_LINE:
			_hint_label.text = "Continue"
		SpiritDuel.PHASE_WON:
			_hint_label.text = "The duel is over. Continue"
		SpiritDuel.PHASE_LOST:
			_hint_label.text = "Your composure broke. Retry"
			_show_retry()


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
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.10, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
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
