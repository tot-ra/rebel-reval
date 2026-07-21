class_name InteractionController
extends Node

const INTERACT_ACTION := &"interact"

@export var actor: Node2D
@export var prompt_label: Label

var _focused: Interactable = null


func _ready() -> void:
	if actor == null:
		actor = get_parent() as Node2D
	_update_prompt()


func _process(_delta: float) -> void:
	_update_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_interact_event(event):
		return
	if _is_dialogue_active():
		return
	if not try_interact():
		return
	get_viewport().set_input_as_handled()


func get_focused_interactable() -> Interactable:
	return _focused


func try_interact() -> bool:
	if _focused == null or actor == null:
		return false
	if _is_actor_input_blocked():
		return false
	return _focused.interact(actor)


func _is_actor_input_blocked() -> bool:
	if actor == null:
		return false
	if _is_dialogue_active():
		return true
	var commission := actor.get_node_or_null("ForgeCommissionController") as ForgeCommissionController
	return commission != null and commission.is_open()


func _is_dialogue_active() -> bool:
	return not get_tree().get_nodes_in_group(&"demo_dialogue_active").is_empty()


func _is_interact_event(event: InputEvent) -> bool:
	if not event.is_pressed() or event.is_echo():
		return false
	if event.is_action(INTERACT_ACTION):
		return event.is_action_pressed(INTERACT_ACTION)
	return false


func _update_focus() -> void:
	if actor == null:
		_set_focused_interactable(null)
		return

	var next_focus := _find_best_interactable()
	_set_focused_interactable(next_focus)
	_update_prompt()


func _find_best_interactable() -> Interactable:
	var best: Interactable = null
	var best_distance := INF

	for node in get_tree().get_nodes_in_group(&"interactable"):
		var interactable := node as Interactable
		if interactable == null or not interactable.is_enabled():
			continue
		if not interactable.is_actor_in_range(actor):
			continue

		var distance := actor.global_position.distance_squared_to(interactable.global_position)
		if distance < best_distance:
			best_distance = distance
			best = interactable

	return best


func _set_focused_interactable(next_focus: Interactable) -> void:
	if _focused == next_focus:
		return
	if _focused != null:
		_focused.set_focused(false)
	_focused = next_focus
	if _focused != null:
		_focused.set_focused(true)


func _update_prompt() -> void:
	if prompt_label == null:
		return
	if _focused == null:
		prompt_label.visible = false
		prompt_label.text = ""
		return
	prompt_label.visible = true
	prompt_label.text = _focused.get_prompt()
