class_name DialogueRunner
extends Node

const PresenterScript := preload("res://scripts/dialogue/dialogue_presenter.gd")

## Authored offline dialogue playback: branching choices, conditions, effects,
## once-only nodes, and phase bark resolution. UI is delegated to DialoguePresenter.

signal started(dialogue_id: StringName)
signal finished(dialogue_id: StringName)

const CONTINUE_ACTIONS: Array[StringName] = [
	&"interact",
	&"ui_accept",
]

var _content_db: ContentDB
var _state: GameState
var _evaluator: StateRuleEvaluator
var _presenter: RefCounted
var _dialogue_id := &""
var _nodes_by_id: Dictionary = {}
var _current_node_id := ""
var _active := false
var _waiting_for_choice := false
var _pending_choices: Array = []
var _input_enabled := false


func configure(
	content_db: ContentDB,
	state: GameState,
	presenter: RefCounted,
	evaluator: StateRuleEvaluator = null
) -> void:
	_content_db = content_db
	_state = state
	_presenter = presenter
	_evaluator = evaluator if evaluator != null else StateRuleEvaluator.new()


func is_active() -> bool:
	return _active


func is_waiting_for_choice() -> bool:
	return _waiting_for_choice


func get_dialogue_id() -> StringName:
	return _dialogue_id


func get_current_node_id() -> String:
	return _current_node_id


func start(dialogue_id: StringName) -> bool:
	if _content_db == null or _presenter == null:
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

	_dialogue_id = dialogue_id
	_active = true
	_waiting_for_choice = false
	_pending_choices.clear()
	_enable_advance()
	started.emit(dialogue_id)
	return _enter_node(start_id)


func advance() -> bool:
	if not _active or _waiting_for_choice:
		return false

	if not _pending_choices.is_empty():
		_waiting_for_choice = true
		_presenter.present_choices(_pending_choices)
		_pending_choices.clear()
		return true

	var current: Dictionary = _nodes_by_id.get(_current_node_id, {})
	var next_id := String(current.get("next_node_id", ""))
	if next_id.is_empty():
		_close()
		return true
	return _enter_node(next_id)


func select_choice(choice_id: String) -> bool:
	if not _active or not _waiting_for_choice or choice_id.is_empty():
		return false

	var current: Dictionary = _nodes_by_id.get(_current_node_id, {})
	var selected: Dictionary = {}
	for choice_value: Variant in current.get("choices", []):
		if typeof(choice_value) != TYPE_DICTIONARY:
			continue
		var choice: Dictionary = choice_value
		if String(choice.get("id", "")) == choice_id:
			selected = choice
			break
	if selected.is_empty():
		return false

	var resolved := _resolve_choice(selected)
	if not bool(resolved.get("enabled", false)):
		return false

	_waiting_for_choice = false
	var effects: Array = selected.get("effects", [])
	if not effects.is_empty() and _state != null:
		_evaluator.apply_effects(_runtime_rules(effects), _state)

	var target_id := String(selected.get("target_node_id", ""))
	if target_id.is_empty() or not _nodes_by_id.has(target_id):
		_close()
		return true
	return _enter_node(target_id)


func try_advance(event: InputEvent) -> bool:
	if not _active or _waiting_for_choice or not _input_enabled or not _is_continue_event(event):
		return false
	if _presenter != null and _presenter.has_method("consume_line_advance"):
		if not _presenter.consume_line_advance():
			return true
	return advance()


func advance_for_test() -> void:
	if not _active or _waiting_for_choice:
		return
	if _presenter != null and _presenter.has_method("consume_line_advance"):
		if not _presenter.consume_line_advance():
			return
	advance()


func resolve_bark(
	bark_pool_id: StringName,
	phase_id: StringName = &"",
	location_id: StringName = &""
) -> Dictionary:
	if _content_db == null or _state == null:
		return {}

	var pool := _content_db.get_bark_pool(bark_pool_id)
	if pool.is_empty():
		return {}

	if not _bark_scope_matches(pool, phase_id, location_id):
		return {}

	var selection := String(pool.get("selection", "first_valid_in_order"))
	if selection != "first_valid_in_order":
		return {}

	var entries: Array = pool.get("entries", [])
	var ranked := entries.duplicate()
	ranked.sort_custom(func(a: Variant, b: Variant) -> bool:
		var priority_a := int((a as Dictionary).get("priority", 0)) if a is Dictionary else 0
		var priority_b := int((b as Dictionary).get("priority", 0)) if b is Dictionary else 0
		return priority_a > priority_b
	)

	for entry_value: Variant in ranked:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		var conditions: Array = entry.get("conditions", [])
		if not conditions.is_empty() and not _evaluator.evaluate_conditions(_runtime_rules(conditions), _state):
			continue
		return {
			"bark_pool_id": bark_pool_id,
			"entry_id": String(entry.get("id", "")),
			"speaker_id": StringName(String(entry.get("speaker_id", ""))),
			"speaker_name": _speaker_name(StringName(String(entry.get("speaker_id", "")))),
			"text": String(entry.get("text", "")),
		}
	return {}


func _enter_node(node_id: String, depth: int = 0) -> bool:
	if depth > _nodes_by_id.size():
		_close()
		return false
	if not _nodes_by_id.has(node_id):
		_close()
		return false

	var node: Dictionary = _nodes_by_id[node_id]
	if _node_once_seen(_dialogue_id, node):
		var skip_id := String(node.get("next_node_id", ""))
		if skip_id.is_empty():
			_close()
			return false
		return _enter_node(skip_id, depth + 1)

	if not _node_conditions_met(node):
		_close()
		return false

	_current_node_id = node_id
	_apply_node_effects(node)
	_mark_node_seen(_dialogue_id, node)

	var text := String(node.get("text", ""))
	var choices := _resolve_choices(node)
	var speaker_id := StringName(String(node.get("speaker_id", "")))
	if not text.is_empty():
		_presenter.present_line(
			speaker_id,
			_speaker_name(speaker_id),
			text,
			node_id
		)
		if not choices.is_empty():
			_pending_choices = choices
		return true

	if not choices.is_empty():
		_waiting_for_choice = true
		_presenter.present_choices(choices)
		return true

	var next_id := String(node.get("next_node_id", ""))
	if not next_id.is_empty():
		return _enter_node(next_id, depth + 1)

	_close()
	return true


func _node_once_seen(dialogue_id: StringName, node: Dictionary) -> bool:
	return bool(node.get("once", false)) \
		and _state != null \
		and _state.has_dialogue_node_seen(dialogue_id, String(node.get("id", "")))


func _node_conditions_met(node: Dictionary) -> bool:
	var conditions: Array = node.get("conditions", [])
	if conditions.is_empty():
		return true
	return _evaluator.evaluate_conditions(_runtime_rules(conditions), _state)


func _resolve_choices(node: Dictionary) -> Array:
	var resolved: Array = []
	for choice_value: Variant in node.get("choices", []):
		if typeof(choice_value) != TYPE_DICTIONARY:
			continue
		resolved.append(_resolve_choice(choice_value as Dictionary))
	return resolved


func _resolve_choice(choice: Dictionary) -> Dictionary:
	var conditions: Array = choice.get("conditions", [])
	var enabled := true
	if not conditions.is_empty():
		enabled = _evaluator.evaluate_conditions(_runtime_rules(conditions), _state)
	return {
		"id": String(choice.get("id", "")),
		"text": String(choice.get("text", "")),
		"target_node_id": String(choice.get("target_node_id", "")),
		"enabled": enabled,
		"disabled_reason": String(choice.get("disabled_reason", "")),
	}


func _apply_node_effects(node: Dictionary) -> void:
	var effects: Array = node.get("effects", [])
	if effects.is_empty() or _state == null:
		return
	_evaluator.apply_effects(_runtime_rules(effects), _state)


func _mark_node_seen(dialogue_id: StringName, node: Dictionary) -> void:
	if _state == null or not bool(node.get("once", false)):
		return
	_state.mark_dialogue_node_seen(dialogue_id, String(node.get("id", "")))


func _bark_scope_matches(pool: Dictionary, phase_id: StringName, location_id: StringName) -> bool:
	var phase_ids: Array = pool.get("phase_ids", [])
	if not phase_ids.is_empty():
		if phase_id.is_empty():
			return false
		var phase_match := false
		for value in phase_ids:
			if StringName(String(value)) == phase_id:
				phase_match = true
				break
		if not phase_match:
			return false

	var location_ids: Array = pool.get("location_ids", [])
	if not location_ids.is_empty():
		if location_id.is_empty():
			return false
		var location_match := false
		for value in location_ids:
			if StringName(String(value)) == location_id:
				location_match = true
				break
		if not location_match:
			return false
	return true


func _runtime_rules(authored_rules: Variant) -> Array:
	var runtime_rules: Array = []
	if typeof(authored_rules) != TYPE_ARRAY:
		return runtime_rules
	for value in authored_rules as Array:
		if typeof(value) != TYPE_DICTIONARY:
			runtime_rules.append(value)
			continue
		var rule := (value as Dictionary).duplicate(true)
		if typeof(rule.get("amount")) == TYPE_FLOAT:
			var amount := float(rule["amount"])
			if amount == floor(amount):
				rule["amount"] = int(amount)
		runtime_rules.append(rule)
	return runtime_rules


func _speaker_name(speaker_id: StringName) -> String:
	if _content_db == null or speaker_id.is_empty():
		return String(speaker_id)
	var character := _content_db.get_character(speaker_id)
	if character.is_empty():
		return String(speaker_id)
	return String(character.get("name", speaker_id))


func _close() -> void:
	var finished_id := _dialogue_id
	_active = false
	_waiting_for_choice = false
	_pending_choices.clear()
	_input_enabled = false
	_current_node_id = ""
	_dialogue_id = &""
	_nodes_by_id.clear()
	set_process_unhandled_input(false)
	if _presenter != null:
		_presenter.close()
	finished.emit(finished_id)


func _enable_advance() -> void:
	_input_enabled = true
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if try_advance(event):
		get_viewport().set_input_as_handled()


func _is_continue_event(event: InputEvent) -> bool:
	if not event.is_pressed() or event.is_echo():
		return false
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		return mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
	for action: StringName in CONTINUE_ACTIONS:
		if event.is_action(action):
			return event.is_action_pressed(action)
	return false
