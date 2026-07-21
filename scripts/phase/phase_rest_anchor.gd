class_name PhaseRestAnchor
extends Node

## Spawns a bed/rest interactable that advances the slice to the next authored phase.

const INTERACTABLE_SCENE := preload("res://scenes/interaction/interactable.tscn")
const PhaseProfileModelScript := preload("res://scripts/phase/phase_profile_model.gd")
const DEFAULT_ANCHOR_ID := &"bed_alcove"

@export var anchor_id: StringName = DEFAULT_ANCHOR_ID
@export var interactable_id: StringName = &"interact.rest.bed_alcove"

var _player: Player
var _interactable: Interactable
var _scene_root: Node2D
var _connected_state: GameState


func setup(scene_root: Node2D, definition: MapDefinition, player: Player) -> void:
	_scene_root = scene_root
	_player = player
	_spawn_interactable(definition)
	if not SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.connect(_on_state_replaced)
	_bind_phase_signal(SessionState.state)


func get_interactable() -> Interactable:
	return _interactable


func _exit_tree() -> void:
	_unbind_phase_signal()
	if SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.disconnect(_on_state_replaced)


func _on_state_replaced(_previous: GameState, current: GameState, _reason: StringName) -> void:
	_bind_phase_signal(current)
	_sync_enabled()


func _on_phase_changed(_previous: StringName, _next: StringName) -> void:
	_sync_enabled()


func _bind_phase_signal(current: GameState) -> void:
	_unbind_phase_signal()
	_connected_state = current
	if _connected_state != null and not _connected_state.phase_changed.is_connected(_on_phase_changed):
		_connected_state.phase_changed.connect(_on_phase_changed)


func _unbind_phase_signal() -> void:
	if _connected_state != null and _connected_state.phase_changed.is_connected(_on_phase_changed):
		_connected_state.phase_changed.disconnect(_on_phase_changed)
	_connected_state = null


func _spawn_interactable(definition: MapDefinition) -> void:
	var anchor_position := MapVerification.anchor_position(definition, anchor_id)
	_interactable = INTERACTABLE_SCENE.instantiate()
	_interactable.name = "PhaseRestBed"
	_interactable.interactable_id = interactable_id
	_interactable.interaction_kind = InteractionKinds.USE
	_interactable.prompt = _rest_prompt()
	_interactable.global_position = anchor_position
	_interactable.set_interact_callback(_on_interact)
	_scene_root.add_child(_interactable)
	_sync_enabled()


func _rest_prompt() -> String:
	if not has_node("/root/SessionState") or SessionState.state == null:
		return "Rest"
	var next := PhaseProfileModelScript.next_phase_id(
		SessionState.state.get_phase(),
		SessionState.content_db
	)
	if next.is_empty():
		return "Rest"
	var profile := PhaseProfileModelScript.resolve_profile(next, SessionState.content_db)
	var title := String(profile.get("title", ""))
	if title.is_empty():
		return "Rest until morning"
	return "Rest until %s" % title.to_lower()


func _sync_enabled() -> void:
	if _interactable == null:
		return
	var enabled := _should_enable()
	if _interactable.enabled != enabled:
		_interactable.enabled = enabled
	if _interactable.prompt != _rest_prompt():
		_interactable.prompt = _rest_prompt()


func _should_enable() -> bool:
	if not has_node("/root/SessionState") or SessionState.state == null:
		return false
	return not PhaseProfileModelScript.next_phase_id(
		SessionState.state.get_phase(),
		SessionState.content_db
	).is_empty()


func _on_interact(_actor: Node) -> void:
	if not has_node("/root/PhaseDirector"):
		return
	PhaseDirector.advance_to_next_phase()
