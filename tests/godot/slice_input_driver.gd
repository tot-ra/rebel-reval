class_name SliceInputDriver
extends RefCounted

## Pushes slice bindings through real InputEvents only - never `Input.action_press`.
## WHY: P2-017 verify requires recorded runs without synthetic action fallbacks.

const BindingSettings := preload("res://scripts/settings/input_binding_settings.gd")
const InputCatalogScript := preload("res://scripts/slice/vertical_slice_input_catalog.gd")

enum DeviceProfile { KEYBOARD_MOUSE, GAMEPAD }

var recorded_steps: Array[String] = []
var fallback_used: bool = false

var _device: DeviceProfile
var _bindings: InputBindingSettings
var _held_events: Array[InputEvent] = []


func _init(device: DeviceProfile) -> void:
	_device = device
	_bindings = BindingSettings.default_settings()
	_bindings.apply_to_input_map()


func device_name() -> String:
	return "keyboard_mouse" if _device == DeviceProfile.KEYBOARD_MOUSE else "gamepad"


func binding_device() -> StringName:
	return (
		BindingSettings.DEVICE_KEYBOARD_MOUSE
		if _device == DeviceProfile.KEYBOARD_MOUSE
		else BindingSettings.DEVICE_GAMEPAD
	)


func assert_no_fallback_used() -> void:
	if fallback_used:
		push_error("slice input run used Input.action_press fallbacks")


func tap_action(action: StringName) -> void:
	recorded_steps.append("%s:tap:%s" % [device_name(), String(action)])
	for event: InputEvent in _primary_events(action):
		_push_pressed(event)
		_push_released(event)


func press_action(action: StringName) -> void:
	recorded_steps.append("%s:press:%s" % [device_name(), String(action)])
	for event: InputEvent in _primary_events(action):
		var held := event.duplicate() as InputEvent
		if held is InputEventJoypadMotion:
			(held as InputEventJoypadMotion).axis_value = _motion_sign(held as InputEventJoypadMotion)
		else:
			held.pressed = true
		_held_events.append(held)
		_dispatch(held)


func release_action(action: StringName) -> void:
	recorded_steps.append("%s:release:%s" % [device_name(), String(action)])
	var remaining: Array[InputEvent] = []
	for held: InputEvent in _held_events:
		if not _event_matches_action(held, action):
			remaining.append(held)
			continue
		var released := held.duplicate() as InputEvent
		if released is InputEventJoypadMotion:
			(released as InputEventJoypadMotion).axis_value = 0.0
		else:
			released.pressed = false
		_dispatch(released)
	_held_events = remaining


func release_all() -> void:
	for held: InputEvent in _held_events.duplicate():
		for action: StringName in InputCatalogScript.action_ids():
			if _event_matches_action(held, action):
				release_action(action)
				break
	_held_events.clear()


func move_player(player: Player, direction: Vector2, delta: float = 0.05, steps: int = 4) -> void:
	var actions: Array[StringName] = []
	if direction.x > 0.0:
		actions.append(&"ui_right")
	elif direction.x < 0.0:
		actions.append(&"ui_left")
	if direction.y > 0.0:
		actions.append(&"ui_down")
	elif direction.y < 0.0:
		actions.append(&"ui_up")
	for action: StringName in actions:
		press_action(action)
	for _i in steps:
		player._physics_process(delta)
	for action: StringName in actions:
		release_action(action)


func dispatch_to_node(node: Node, action: StringName) -> void:
	recorded_steps.append("%s:dispatch:%s" % [device_name(), String(action)])
	for event: InputEvent in _primary_events(action):
		var pressed := event.duplicate() as InputEvent
		pressed.pressed = true
		if node.has_method("_unhandled_input"):
			node._unhandled_input(pressed)


func dispatch_event_to_node(node: Node, event: InputEvent) -> void:
	recorded_steps.append("%s:dispatch_event" % device_name())
	if node.has_method("_unhandled_input"):
		node._unhandled_input(event)


func primary_events(action: StringName) -> Array[InputEvent]:
	var events := _bindings.events_for(action, binding_device())
	if events.is_empty():
		push_error("%s needs a %s binding" % [String(action), device_name()])
		return []
	return [events[0]]


func _primary_events(action: StringName) -> Array[InputEvent]:
	return primary_events(action)


func _push_pressed(event: InputEvent) -> void:
	var pressed := event.duplicate() as InputEvent
	if pressed is InputEventJoypadMotion:
		(pressed as InputEventJoypadMotion).axis_value = _motion_sign(pressed as InputEventJoypadMotion)
	else:
		pressed.pressed = true
	_dispatch(pressed)


func _push_released(event: InputEvent) -> void:
	var released := event.duplicate() as InputEvent
	if released is InputEventJoypadMotion:
		(released as InputEventJoypadMotion).axis_value = 0.0
	else:
		released.pressed = false
	_dispatch(released)


func _dispatch(event: InputEvent) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	Input.parse_input_event(event)
	tree.root.push_input(event, true)


func _event_matches_action(event: InputEvent, action: StringName) -> bool:
	for bound: InputEvent in _bindings.events_for(action, binding_device()):
		if event.as_text() == bound.as_text():
			return true
		if event is InputEventKey and bound is InputEventKey:
			return (event as InputEventKey).physical_keycode == (bound as InputEventKey).physical_keycode
		if event is InputEventJoypadButton and bound is InputEventJoypadButton:
			return (event as InputEventJoypadButton).button_index == (
				bound as InputEventJoypadButton
			).button_index
		if event is InputEventJoypadMotion and bound is InputEventJoypadMotion:
			var motion := event as InputEventJoypadMotion
			var bound_motion := bound as InputEventJoypadMotion
			return motion.axis == bound_motion.axis and signf(motion.axis_value) == signf(
				bound_motion.axis_value
			)
	return false


static func _motion_sign(motion: InputEventJoypadMotion) -> float:
	return 1.0 if motion.axis_value >= 0.0 else -1.0
