class_name DemoDialogueRunner
extends Node

## Linear demo dialogue playback from authored JSON. Intentionally narrow: no
## branching UI, conditions, or bark routing. Superseded by P1-011 DialogueRunner.

signal started()
signal finished()

const CONTINUE_ACTIONS: Array[StringName] = [
	&"interact",
	&"ui_accept",
]

var _content_db: ContentDB
var _state: GameState
var _evaluator: StateRuleEvaluator
var _box: DemoDialogueBox
var _interaction_controller: InteractionController
var _nodes_by_id: Dictionary = {}
var _current_node_id := ""
var _active := false
var _input_enabled := false


func configure(
	content_db: ContentDB,
	state: GameState,
	dialogue_box: DemoDialogueBox,
	interaction_controller: InteractionController = null,
	evaluator: StateRuleEvaluator = null
) -> void:
	_content_db = content_db
	_state = state
	_box = dialogue_box
	_interaction_controller = interaction_controller
	_evaluator = evaluator if evaluator != null else StateRuleEvaluator.new()


func is_active() -> bool:
	return _active


func start(dialogue_id: StringName) -> bool:
	if _content_db == null or _box == null:
		return false

	var dialogue := _content_db.get_dialogue(dialogue_id)
	if dialogue.is_empty():
		return false

	_nodes_by_id.clear()
	for node_value: Variant in dialogue.get("nodes", []):
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_value
		var node_id := String(node.get("id", ""))
		if node_id.is_empty():
			continue
		_nodes_by_id[node_id] = node

	var start_id := String(dialogue.get("start_node_id", ""))
	if start_id.is_empty() or not _nodes_by_id.has(start_id):
		return false

	_active = true
	add_to_group(&"demo_dialogue_active")
	_enable_advance()
	_set_interaction_enabled(false)
	started.emit()
	return _show_node(start_id)


func try_advance(event: InputEvent) -> bool:
	if not _active or not _input_enabled or not _is_continue_event(event):
		return false
	return _advance()


func _enable_advance() -> void:
	_input_enabled = true
	set_process_unhandled_input(true)


func advance_for_test() -> void:
	if _active:
		_advance()


func _unhandled_input(event: InputEvent) -> void:
	if try_advance(event):
		get_viewport().set_input_as_handled()


func _advance() -> bool:
	var current: Dictionary = _nodes_by_id.get(_current_node_id, {})
	var next_id := String(current.get("next_node_id", ""))
	if next_id.is_empty():
		_close()
		return true
	return _show_node(next_id)


func _show_node(node_id: String) -> bool:
	if not _nodes_by_id.has(node_id):
		_close()
		return false

	var node: Dictionary = _nodes_by_id[node_id]
	_current_node_id = node_id
	var speaker_id := StringName(String(node.get("speaker_id", "")))
	_box.show_line(_speaker_name(speaker_id), String(node.get("text", "")))

	var effects: Array = node.get("effects", [])
	if not effects.is_empty() and _state != null:
		_evaluator.apply_effects(effects, _state)
	return true


func _speaker_name(speaker_id: StringName) -> String:
	if _content_db == null or speaker_id.is_empty():
		return String(speaker_id)
	var character := _content_db.get_character(speaker_id)
	if character.is_empty():
		return String(speaker_id)
	return String(character.get("name", speaker_id))


func _close() -> void:
	_active = false
	_input_enabled = false
	_current_node_id = ""
	set_process_unhandled_input(false)
	remove_from_group(&"demo_dialogue_active")
	if _box != null:
		_box.hide_box()
	_set_interaction_enabled(true)
	finished.emit()


func _set_interaction_enabled(enabled: bool) -> void:
	if _interaction_controller == null:
		return
	_interaction_controller.set_process(enabled)
	_interaction_controller.set_process_unhandled_input(enabled)
	if _interaction_controller.prompt_label != null:
		_interaction_controller.prompt_label.visible = enabled and _interaction_controller.get_focused_interactable() != null


func _is_continue_event(event: InputEvent) -> bool:
	if not event.is_pressed() or event.is_echo():
		return false
	for action: StringName in CONTINUE_ACTIONS:
		if event.is_action(action):
			return event.is_action_pressed(action)
	if event is InputEventJoypadButton:
		var button_event := event as InputEventJoypadButton
		return button_event.pressed and button_event.button_index == JOY_BUTTON_A
	return false
