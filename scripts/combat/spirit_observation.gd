class_name SpiritObservation
extends "res://scripts/dialogue/dialogue_presenter.gd"
## Observation mode (ADR 0033, SD-06): the hero "looks closer" at a conflict between
## other people and sees it as a spirit duel. It plays a tagged dialogue record with
## no input, teaches the hero each move he sees (`GameState.learn_move`), and lets him
## side with one speaker once before it ends. Choices inside an observed record are
## taken in authored order (first enabled), so the outcome is deterministic.

signal line_seen(speaker_id: StringName, text: String, move: Dictionary)
signal move_seen(speaker_id: StringName, move: Dictionary, newly_learned: bool)
signal finished(outcome: Dictionary)

var hero_id: StringName = &"char.apprentice"
var last_outcome: Dictionary = {}

var _runner: Node
var _state: GameState
var _dialogue_id: StringName = &""
var _seen: Array[StringName] = []
var _learned: Array[StringName] = []
var _intervened_for: StringName = &""
var _finished := true


## `learn_move` id for a move tag: `move.<kind>.<element>`.
static func move_id(move: Dictionary) -> StringName:
	if move.is_empty():
		return &""
	return StringName("move.%s.%s" % [move.get("kind", ""), move.get("element", "")])


## Flag set when the hero sides with `speaker_id` in `dialogue_id`.
static func intervention_flag(dialogue_id: StringName, speaker_id: StringName) -> StringName:
	return StringName("flag.duel.%s.sided_with.%s" % [dialogue_id, speaker_id])


func begin(runner: Node, content_db: ContentDB, state: GameState, dialogue_id: StringName) -> bool:
	_runner = runner
	_state = state
	_dialogue_id = dialogue_id
	_seen.clear()
	_learned.clear()
	_intervened_for = &""
	last_outcome = {}
	_runner.configure(content_db, state, self)
	if content_db == null or content_db.get_dialogue(dialogue_id).get("duel", {}).is_empty():
		_finished = true
		return false
	_finished = false
	state.in_spirit_world = true
	if not _runner.start(dialogue_id):
		_finished = true
		state.in_spirit_world = false
		return false
	return true


func is_over() -> bool:
	return _finished


## Advance one beat. False once the observation is over.
func step() -> bool:
	if _finished:
		return false
	return _runner.advance()


## Watch the whole conflict.
func play_all() -> Dictionary:
	var guard := 0
	while not _finished and guard < 256:
		step()
		guard += 1
	return last_outcome


## Side with a speaker of the observed conflict (once, before it ends).
func intervene(speaker_id: StringName) -> bool:
	if _finished or _intervened_for != &"" or speaker_id == &"":
		return false
	var participants: Array = _runner.get_participants()
	if not participants.has(String(speaker_id)):
		return false
	_intervened_for = speaker_id
	_state.set_flag(intervention_flag(_dialogue_id, speaker_id), true)
	return true


func present_line(
	speaker_id: StringName, _speaker_name: String, text: String, node_id: String
) -> void:
	var move: Dictionary = _runner.get_current_move()
	var readable: bool = _runner.current_speech_readable()
	line_seen.emit(speaker_id, text, move if readable else SpiritDuel.kind_only(move))
	# A conflict in a language the hero does not follow teaches him nothing: he cannot tell its element.
	if not move.is_empty() and readable:
		var id := move_id(move)
		var is_new := _state.learn_move(id)
		if not _seen.has(id):
			_seen.append(id)
		if is_new:
			_learned.append(id)
		move_seen.emit(speaker_id, move, is_new)
	if _runner.get_duel().get("resolution_node_ids", []).has(node_id):
		_finish(StringName(node_id))


func present_choices(choices: Array) -> void:
	for choice_value: Variant in choices:
		var choice: Dictionary = choice_value
		if bool(choice.get("enabled", false)):
			_runner.select_choice(String(choice.get("id", "")))
			return


func close() -> void:
	if not _finished:
		_finish(&"")


func consume_line_advance() -> bool:
	return false


func _finish(node_id: StringName) -> void:
	_finished = true
	if _state != null:
		_state.in_spirit_world = false
	last_outcome = {
		"dialogue_id": String(_dialogue_id),
		"resolution_node_id": String(node_id),
		"moves_seen": _seen.duplicate(),
		"moves_learned": _learned.duplicate(),
		"intervened_for": String(_intervened_for),
	}
	finished.emit(last_outcome)
