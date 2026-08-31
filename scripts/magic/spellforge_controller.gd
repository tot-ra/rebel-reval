class_name SpellforgeController
extends Node

## Connects remappable player input and the HUD to the existing deterministic
## resolver/executor pipeline. The cookbook is optional; quick forging stays active
## during ordinary gameplay.

const TOGGLE_ACTION := &"toggle_spellforge"
const SELECT_ACTIONS: Dictionary = {
	&"spellforge_element_1": 0,
	&"spellforge_element_2": 1,
	&"spellforge_element_3": 2,
	&"spellforge_element_4": 3,
	&"spellforge_element_5": 4,
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
	if not event.is_pressed() or event.is_echo():
		return
	if is_open():
		_handle_cookbook_input(event)
		return
	if _gameplay_input_blocked():
		return
	for action: StringName in SELECT_ACTIONS:
		if event.is_action_pressed(action):
			_select_catalog_index(int(SELECT_ACTIONS[action]))
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(&"spellforge_remove"):
		_on_remove_requested()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"spellforge_cast") and not _model.selected_sequence().is_empty():
		_on_cast_requested(_mouse_aim_direction(event))
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


func _on_cast_requested(aim_direction := Vector2.ZERO) -> void:
	var direction: Vector2 = aim_direction
	if direction.is_zero_approx() and _caster != null and _caster.has_method("view_facing"):
		direction = _caster.call("view_facing") as Vector2
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	_model.cast(_caster, direction.normalized())
	_hud.refresh()


func _select_catalog_index(index: int) -> void:
	var elements := _model.catalog_elements()
	if index < 0 or index >= elements.size():
		return
	_model.select_element(elements[index])
	_hud.refresh()


func _handle_cookbook_input(event: InputEvent) -> void:
	for action: StringName in SELECT_ACTIONS:
		if event.is_action_pressed(action):
			_select_catalog_index(int(SELECT_ACTIONS[action]))
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(&"spellforge_remove"):
		_on_remove_requested()
		get_viewport().set_input_as_handled()
	# A left click belongs to cookbook buttons while the collection is open.
	elif event.is_action_pressed(&"spellforge_cast") and not _is_left_click(event):
		_on_cast_requested()
		get_viewport().set_input_as_handled()


func _mouse_aim_direction(event: InputEvent) -> Vector2:
	if not _is_left_click(event) or _caster == null:
		return Vector2.ZERO
	return _caster.get_global_mouse_position() - _caster.global_position


func _gameplay_input_blocked() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	for overlay: Node in tree.get_nodes_in_group(&"modal_input_overlay"):
		if overlay is CanvasItem and (overlay as CanvasItem).visible:
			return true
	return false


static func _is_left_click(event: InputEvent) -> bool:
	if not event is InputEventMouseButton:
		return false
	var button := event as InputEventMouseButton
	return button.button_index == MOUSE_BUTTON_LEFT and button.pressed


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
