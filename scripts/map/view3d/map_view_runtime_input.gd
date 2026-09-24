class_name MapViewRuntimeInput
extends RefCounted

## Gameplay input routing for MapViewRuntime: click-to-move controller install and
## camera zoom / mode shortcuts that must stay off the editor-time map graph.

const CLICK_INPUT_SCRIPT_PATH := "res://scripts/map/map_click_input_controller.gd"

var _host: MapViewRuntime
var _player: CharacterBody2D
var _click_input: Node


func configure(runtime_host: MapViewRuntime, player: CharacterBody2D) -> void:
	_host = runtime_host
	_player = player


func click_input() -> Node:
	return _click_input


func install_click_input() -> void:
	if _host == null:
		return
	var click_input_script := load(CLICK_INPUT_SCRIPT_PATH) as Script
	if click_input_script == null:
		push_error("MapViewRuntimeInput could not load the click input controller")
		return
	_click_input = click_input_script.new() as Node
	_click_input.name = "MapClickInput"
	_host.add_child(_click_input)
	_click_input.call("setup", _player, _host)


func configure_click_input(world_items: Node = null) -> void:
	if _click_input == null:
		return
	if world_items != null:
		_click_input.call("set_world_items", world_items)


func handle_unhandled_input(event: InputEvent) -> void:
	if _host == null:
		return
	if event.is_action_pressed(&"toggle_camera_view") and not event.is_echo():
		_host.toggle_camera_view()
		_host.get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if _handle_time_control_key((event as InputEventKey).keycode):
			_host.get_viewport().set_input_as_handled()
			return
	if event is InputEventKey:
		return
	if event is InputEventMagnifyGesture:
		_host.zoom_from_magnify_factor((event as InputEventMagnifyGesture).factor)
		_host.get_viewport().set_input_as_handled()
		return
	if event is InputEventPanGesture:
		_host.zoom_from_pan_delta((event as InputEventPanGesture).delta)
		_host.get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		var wheel_steps := 0.0
		var wheel_factor := mouse_button.factor if mouse_button.factor > 0.0 else 1.0
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			wheel_steps = wheel_factor
		elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			wheel_steps = -wheel_factor
		else:
			return
		_host.zoom_view_steps(wheel_steps)
		_host.get_viewport().set_input_as_handled()


func _handle_time_control_key(keycode: Key) -> bool:
	match keycode:
		KEY_BACKSLASH:
			_host.reset_time_flow()
		_:
			return false
	return true
