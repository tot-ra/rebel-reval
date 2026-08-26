class_name SpellforgeController
extends Node

## Connects remappable player input and the HUD to the existing deterministic
## resolver/executor pipeline. Removing this optional node leaves the slice intact.

const TOGGLE_ACTION := &"toggle_spellforge"
const SELECT_ACTIONS: Dictionary = {
	&"spellforge_element_1": 0,
	&"spellforge_element_2": 1,
	&"spellforge_element_3": 2,
}
const ModelScript := preload("res://scripts/magic/spellforge_model.gd")
const HudScript := preload("res://scripts/magic/spellforge_hud.gd")

var _model: SpellforgeModel
var _hud: SpellforgeHud
var _caster: Node2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_caster = get_parent() as Node2D
	_model = ModelScript.new() as SpellforgeModel
	_model.configure(SessionState.state, SessionState.content_db)
	_hud = HudScript.new() as SpellforgeHud
	_hud.name = "SpellforgeHud"
	_hud.configure(_model)
	add_child(_hud)
	_hud.element_requested.connect(_on_element_requested)
	_hud.remove_requested.connect(_on_remove_requested)
	_hud.cast_requested.connect(_on_cast_requested)
	if not SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.connect(_on_state_replaced)


func _exit_tree() -> void:
	if SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.disconnect(_on_state_replaced)


func _input(event: InputEvent) -> void:
	if not is_open() or not event.is_pressed() or event.is_echo():
		return
	for action: StringName in SELECT_ACTIONS:
		if event.is_action_pressed(action):
			_select_learned_index(int(SELECT_ACTIONS[action]))
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(&"spellforge_remove"):
		_on_remove_requested()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"spellforge_cast"):
		_on_cast_requested()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed(TOGGLE_ACTION):
		get_viewport().set_input_as_handled()
		toggle()


func is_open() -> bool:
	return _hud != null and _hud.is_open()


func open() -> void:
	if _hud == null or _hud.is_open():
		return
	_close_sibling_overlays()
	_hud.open()


func close() -> void:
	if _hud != null:
		_hud.close()


func toggle() -> void:
	if is_open():
		close()
	else:
		open()


func model() -> SpellforgeModel:
	return _model


func _on_state_replaced(_previous: GameState, current: GameState, _reason: StringName) -> void:
	_model.configure(current, SessionState.content_db)
	_hud.refresh()


func _on_element_requested(element_id: StringName) -> void:
	_model.select_element(element_id)
	_hud.refresh()


func _on_remove_requested() -> void:
	_model.remove_last()
	_hud.refresh()


func _on_cast_requested() -> void:
	var direction := Vector2.RIGHT
	if _caster != null and _caster.has_method("view_facing"):
		direction = _caster.call("view_facing") as Vector2
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	_model.cast(_caster, direction.normalized())
	_hud.refresh()


func _select_learned_index(index: int) -> void:
	var learned := _model.learned_elements()
	if index < 0 or index >= learned.size():
		return
	_model.select_element(learned[index])
	_hud.refresh()


func _close_sibling_overlays() -> void:
	var owner := get_parent()
	for controller_name in [
		"InventoryController",
		"JournalController",
		"WorldMapController",
		"ReflectionController",
	]:
		var controller := owner.get_node_or_null(controller_name)
		if controller != null and controller.has_method("close"):
			controller.call("close")
