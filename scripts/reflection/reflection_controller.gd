class_name ReflectionController
extends Node

const OVERLAY_SCENE := preload("res://scenes/ui/reflection_overlay.tscn")
const ModelScript := preload("res://scripts/reflection/reflection_model.gd")

var _overlay: ReflectionOverlay
var _evaluator := StateRuleEvaluator.new()
var _state: GameState


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = OVERLAY_SCENE.instantiate() as ReflectionOverlay
	_overlay.visible = false
	add_child(_overlay)
	_overlay.closed.connect(_on_overlay_closed)
	_overlay.conviction_chosen.connect(_on_conviction_chosen)
	_bind_state(SessionState.state)
	if not SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.connect(_on_state_replaced)


func _exit_tree() -> void:
	_unbind_state()
	if SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.disconnect(_on_state_replaced)


func is_open() -> bool:
	return _overlay != null and _overlay.is_open()


func is_available() -> bool:
	return ModelScript.is_available(_state)


func open() -> void:
	if _overlay == null or _state == null or not is_available():
		return
	_close_other_overlays()
	_overlay.present(ModelScript.build_snapshot(_state))


func close() -> void:
	if _overlay != null and _overlay.is_open():
		_overlay.close()


func _on_state_replaced(_previous: GameState, current: GameState, _reason: StringName) -> void:
	_bind_state(current)
	if is_available():
		call_deferred("open")


func _bind_state(state: GameState) -> void:
	_unbind_state()
	_state = state
	if _state != null and not _state.phase_changed.is_connected(_on_phase_changed):
		_state.phase_changed.connect(_on_phase_changed)
	if is_available():
		call_deferred("open")


func _unbind_state() -> void:
	if _state != null and _state.phase_changed.is_connected(_on_phase_changed):
		_state.phase_changed.disconnect(_on_phase_changed)
	_state = null


func _on_phase_changed(_previous: StringName, _next: StringName) -> void:
	if is_available():
		call_deferred("open")


func _on_conviction_chosen(option_id: String) -> void:
	if _state == null:
		return
	if not ModelScript.apply_conviction(_state, option_id, _evaluator):
		push_warning("Reflection conviction failed: %s" % _evaluator.get_last_error())
		return
	close()
	var menu := get_parent().get_node_or_null("QuickAccessMenu") as QuickAccessMenu
	if menu != null:
		menu.refresh_action_availability()


func _on_overlay_closed() -> void:
	var menu := get_parent().get_node_or_null("QuickAccessMenu") as QuickAccessMenu
	if menu != null:
		menu.refresh_action_availability()


func _close_other_overlays() -> void:
	var inventory := get_parent().get_node_or_null("InventoryController") as InventoryController
	if inventory != null:
		inventory.close()
	var journal := get_parent().get_node_or_null("JournalController") as JournalController
	if journal != null:
		journal.close()
	var world_map := get_parent().get_node_or_null("WorldMapController") as WorldMapController
	if world_map != null:
		world_map.close()
