class_name QuestPouchController
extends Node

## Keeps the quest-tool HUD in sync with GameState and authored item visibility.

const QuestPouchHudScript := preload("res://scripts/inventory/quest_pouch_hud.gd")
const QuestPouchModelScript := preload("res://scripts/inventory/quest_pouch_model.gd")

var _hud: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hud = QuestPouchHudScript.new()
	_hud.name = "QuestPouchHud"
	add_child(_hud)
	_hud.configure(SessionState.content_db)
	_bind_state(SessionState.state)
	if not SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.connect(_on_state_replaced)
	_refresh()


func _exit_tree() -> void:
	_unbind_state(SessionState.state)
	if SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.disconnect(_on_state_replaced)


func get_hud() -> CanvasLayer:
	return _hud


func _on_state_replaced(previous: GameState, current: GameState, _reason: StringName) -> void:
	_unbind_state(previous)
	_bind_state(current)
	_refresh()


func _bind_state(state: GameState) -> void:
	if state == null:
		return
	if not state.items_changed.is_connected(_refresh):
		state.items_changed.connect(_refresh)
	if not state.equipment_changed.is_connected(_refresh):
		state.equipment_changed.connect(_refresh)
	if not state.forged_record_added.is_connected(_refresh):
		state.forged_record_added.connect(_refresh)


func _unbind_state(state: GameState) -> void:
	if state == null:
		return
	if state.items_changed.is_connected(_refresh):
		state.items_changed.disconnect(_refresh)
	if state.equipment_changed.is_connected(_refresh):
		state.equipment_changed.disconnect(_refresh)
	if state.forged_record_added.is_connected(_refresh):
		state.forged_record_added.disconnect(_refresh)


func _refresh(_unused: Variant = null) -> void:
	if _hud == null:
		return
	_hud.refresh(QuestPouchModelScript.visible_item_ids(SessionState.state, SessionState.content_db))
