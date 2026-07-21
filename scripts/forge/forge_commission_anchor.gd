class_name ForgeCommissionAnchor
extends Node

## Spawns a ledger interactable that opens a content-defined forge commission.

const INTERACTABLE_SCENE := preload("res://scenes/interaction/interactable.tscn")
const DEFAULT_COMMISSION_ID := &"commission.watch_buckle_repair"
const DEFAULT_ANCHOR_ID := &"ledger"

@export var commission_id: StringName = DEFAULT_COMMISSION_ID
@export var anchor_id: StringName = DEFAULT_ANCHOR_ID

var _player: Player
var _interactable: Interactable
var _scene_root: Node2D


func setup(scene_root: Node2D, definition: MapDefinition, player: Player) -> void:
	_scene_root = scene_root
	_player = player
	_connect_commission_controller()
	_spawn_interactable(definition)
	if not SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.connect(_on_state_replaced)


func _connect_commission_controller() -> void:
	if _player == null:
		return
	var controller := _player.get_node_or_null("ForgeCommissionController") as ForgeCommissionController
	if controller == null:
		return
	if not controller.commission_finished.is_connected(_on_commission_finished):
		controller.commission_finished.connect(_on_commission_finished)


func _on_commission_finished(_commission_id: StringName) -> void:
	_sync_enabled()


func _exit_tree() -> void:
	if _player != null:
		var controller := _player.get_node_or_null("ForgeCommissionController") as ForgeCommissionController
		if controller != null and controller.commission_finished.is_connected(_on_commission_finished):
			controller.commission_finished.disconnect(_on_commission_finished)
	if SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.disconnect(_on_state_replaced)


func _on_state_replaced(_previous: GameState, _current: GameState, _reason: StringName) -> void:
	_sync_enabled()


func _process(_delta: float) -> void:
	_sync_enabled()


func get_interactable() -> Interactable:
	return _interactable


func _spawn_interactable(definition: MapDefinition) -> void:
	var anchor_position := MapVerification.anchor_position(definition, anchor_id)
	_interactable = INTERACTABLE_SCENE.instantiate()
	_interactable.name = "LedgerCommission"
	_interactable.interactable_id = StringName(
		"interact.commission.%s" % String(commission_id).replace("commission.", "")
	)
	_interactable.interaction_kind = InteractionKinds.USE
	_interactable.prompt = _commission_prompt()
	_interactable.global_position = anchor_position
	_interactable.set_interact_callback(_on_interact)
	_scene_root.add_child(_interactable)
	_sync_enabled()


func _commission_prompt() -> String:
	if not has_node("/root/SessionState"):
		return "Review commission"
	var commission := SessionState.content_db.get_commission(commission_id)
	var title := String(commission.get("title", ""))
	return title if not title.is_empty() else "Review commission"


func _sync_enabled() -> void:
	if _interactable == null:
		return
	var enabled := _should_enable()
	if _interactable.enabled != enabled:
		_interactable.enabled = enabled


func _should_enable() -> bool:
	if _player == null:
		return false
	var controller := _player.get_node_or_null("ForgeCommissionController") as ForgeCommissionController
	if controller != null and controller.is_open():
		return false
	if not has_node("/root/SessionState"):
		return true
	return not ForgeCommissionModel.is_commission_resolved(SessionState.state, commission_id)


func _on_interact(_actor: Node) -> void:
	if _player == null:
		return
	var controller := _player.get_node_or_null("ForgeCommissionController") as ForgeCommissionController
	if controller == null or controller.is_open():
		return
	controller.open_commission(commission_id)
