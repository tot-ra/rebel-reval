class_name MapClickInputController
extends Node

## Central left-click routing for map scenes: world pickups, interactables, then
## click-to-move pathfinding. Scenes opt into world-item and prompt controllers
## through MapViewRuntime.configure_click_input().

var _player: Player
var _view_runtime: MapViewRuntime
var _world_items: WorldItemController
var _pending_interactable: Interactable


func setup(player: Player, view_runtime: MapViewRuntime) -> void:
	_player = player
	_view_runtime = view_runtime
	set_process_unhandled_input(true)
	set_physics_process(true)


func set_world_items(controller: WorldItemController) -> void:
	_world_items = controller


func try_handle_click(event: InputEvent) -> bool:
	if not _is_left_click(event):
		return false
	if _player == null or _view_runtime == null:
		return false
	if _player.is_movement_input_blocked():
		return false
	if _view_runtime.is_camera_drag_active():
		return false
	if _world_items != null and _world_items.try_handle_click(event):
		return true
	return try_handle_logic_click(_view_runtime.logic_position_at_screen(event.position))


func try_handle_logic_click(logic_position: Vector2) -> bool:
	if _player == null or _view_runtime == null:
		return false
	if _player.is_movement_input_blocked():
		return false
	if _view_runtime.is_camera_drag_active():
		return false

	var interactable := Interactable.find_at_logic_position(logic_position, get_tree())
	if interactable != null:
		return _handle_interactable_click(interactable)

	_player.request_navigation_target(logic_position)
	return true


func _unhandled_input(event: InputEvent) -> void:
	if try_handle_click(event):
		get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	_try_complete_pending_interaction()


func _handle_interactable_click(interactable: Interactable) -> bool:
	if interactable.interact(_player):
		return true
	_pending_interactable = interactable
	_player.request_navigation_target(interactable.global_position)
	return true


func _try_complete_pending_interaction() -> void:
	if _pending_interactable == null or _player == null:
		return
	if not is_instance_valid(_pending_interactable) or not _pending_interactable.is_enabled():
		_pending_interactable = null
		return
	if not _pending_interactable.is_actor_in_range(_player):
		return
	if _pending_interactable.interact(_player):
		_pending_interactable = null


static func _is_left_click(event: InputEvent) -> bool:
	if not event is InputEventMouseButton:
		return false
	var mouse_button := event as InputEventMouseButton
	return mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed
