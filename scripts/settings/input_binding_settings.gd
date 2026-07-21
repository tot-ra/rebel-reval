class_name InputBindingSettings
extends RefCounted

## Persistent, device-separated bindings for every player-facing vertical-slice action.
## InputMap remains the runtime authority; this model only serializes and applies it.

const SelfScript := preload("res://scripts/settings/input_binding_settings.gd")

const DEVICE_KEYBOARD_MOUSE := &"keyboard_mouse"
const DEVICE_GAMEPAD := &"gamepad"

const ACTION_DEFINITIONS: Array[Dictionary] = [
	{"id": &"ui_up", "label": "Move / focus up", "category": "Movement"},
	{"id": &"ui_down", "label": "Move / focus down", "category": "Movement"},
	{"id": &"ui_left", "label": "Move / focus left", "category": "Movement"},
	{"id": &"ui_right", "label": "Move / focus right", "category": "Movement"},
	{"id": &"ui_shift", "label": "Walk", "category": "Movement"},
	{"id": &"interact", "label": "Interact / continue", "category": "Interaction"},
	{"id": &"ui_accept", "label": "Confirm", "category": "Interaction"},
	{"id": &"ui_cancel", "label": "Back / close", "category": "Interaction"},
	{"id": &"ui_page_up", "label": "Dialogue backlog", "category": "Interaction"},
	{"id": &"player_attack", "label": "Attack", "category": "Combat"},
	{"id": &"player_guard", "label": "Guard", "category": "Combat"},
	{"id": &"player_dodge", "label": "Dodge", "category": "Combat"},
	{"id": &"toggle_inventory", "label": "Inventory", "category": "Views"},
	{"id": &"toggle_journal", "label": "Journal", "category": "Views"},
	{"id": &"toggle_camera_view", "label": "Camera view", "category": "Views"},
	{"id": &"toggle_minimap", "label": "Minimap", "category": "Views"},
	{"id": &"toggle_world_map", "label": "Map", "category": "Views"},
	{"id": &"toggle_controls", "label": "Controls", "category": "Views"},
]

var _bindings: Dictionary = {}


static func default_settings() -> InputBindingSettings:
	var settings := SelfScript.new() as InputBindingSettings
	settings._bindings = {
		"ui_up": {
			DEVICE_KEYBOARD_MOUSE: [_key(KEY_UP), _key(KEY_W)],
			DEVICE_GAMEPAD: [_joy_motion(JOY_AXIS_LEFT_Y, -1.0)],
		},
		"ui_down": {
			DEVICE_KEYBOARD_MOUSE: [_key(KEY_DOWN), _key(KEY_S)],
			DEVICE_GAMEPAD: [_joy_motion(JOY_AXIS_LEFT_Y, 1.0)],
		},
		"ui_left": {
			DEVICE_KEYBOARD_MOUSE: [_key(KEY_LEFT), _key(KEY_A)],
			DEVICE_GAMEPAD: [_joy_motion(JOY_AXIS_LEFT_X, -1.0)],
		},
		"ui_right": {
			DEVICE_KEYBOARD_MOUSE: [_key(KEY_RIGHT), _key(KEY_D)],
			DEVICE_GAMEPAD: [_joy_motion(JOY_AXIS_LEFT_X, 1.0)],
		},
		"ui_shift": {
			DEVICE_KEYBOARD_MOUSE: [_key(KEY_SHIFT)],
			DEVICE_GAMEPAD: [_joy_button(JOY_BUTTON_LEFT_STICK)],
		},
		"interact": {
			DEVICE_KEYBOARD_MOUSE: [_key(KEY_E), _key(KEY_ENTER), _key(KEY_KP_ENTER)],
			DEVICE_GAMEPAD: [_joy_button(JOY_BUTTON_A)],
		},
		"ui_accept": {
			DEVICE_KEYBOARD_MOUSE: [_key(KEY_ENTER), _key(KEY_KP_ENTER), _key(KEY_SPACE)],
			DEVICE_GAMEPAD: [_joy_button(JOY_BUTTON_A)],
		},
		"ui_cancel": {
			DEVICE_KEYBOARD_MOUSE: [_key(KEY_ESCAPE)],
			DEVICE_GAMEPAD: [_joy_button(JOY_BUTTON_B)],
		},
		"ui_page_up": {
			DEVICE_KEYBOARD_MOUSE: [_key(KEY_TAB), _key(KEY_PAGEUP)],
			DEVICE_GAMEPAD: [_joy_button(JOY_BUTTON_DPAD_LEFT)],
		},
		"player_attack": {
			DEVICE_KEYBOARD_MOUSE: [_key(KEY_SPACE)],
			DEVICE_GAMEPAD: [_joy_button(JOY_BUTTON_X)],
		},
		"player_guard": {
			DEVICE_KEYBOARD_MOUSE: [_key(KEY_F), _mouse_button(MOUSE_BUTTON_RIGHT)],
			DEVICE_GAMEPAD: [_joy_button(JOY_BUTTON_LEFT_SHOULDER)],
		},
		"player_dodge": {
			DEVICE_KEYBOARD_MOUSE: [_key(KEY_Q)],
			DEVICE_GAMEPAD: [_joy_button(JOY_BUTTON_RIGHT_SHOULDER)],
		},
		"toggle_inventory": {
			DEVICE_KEYBOARD_MOUSE: [_key(KEY_I)],
			DEVICE_GAMEPAD: [_joy_button(JOY_BUTTON_Y)],
		},
		"toggle_journal": {
			DEVICE_KEYBOARD_MOUSE: [_key(KEY_J)],
			DEVICE_GAMEPAD: [_joy_button(JOY_BUTTON_BACK)],
		},
		"toggle_camera_view": {
			DEVICE_KEYBOARD_MOUSE: [_key(KEY_C)],
			DEVICE_GAMEPAD: [_joy_button(JOY_BUTTON_RIGHT_STICK)],
		},
		"toggle_minimap": {
			DEVICE_KEYBOARD_MOUSE: [_key(KEY_N)],
			DEVICE_GAMEPAD: [_joy_button(JOY_BUTTON_DPAD_UP)],
		},
		"toggle_world_map": {
			DEVICE_KEYBOARD_MOUSE: [_key(KEY_M)],
			DEVICE_GAMEPAD: [_joy_button(JOY_BUTTON_DPAD_DOWN)],
		},
		"toggle_controls": {
			DEVICE_KEYBOARD_MOUSE: [_key(KEY_K)],
			DEVICE_GAMEPAD: [_joy_button(JOY_BUTTON_START)],
		},
	}
	return settings


static func from_dict(data: Dictionary) -> InputBindingSettings:
	var settings := default_settings()
	var actions_value: Variant = data.get("actions", {})
	if typeof(actions_value) != TYPE_DICTIONARY:
		return settings
	var actions := actions_value as Dictionary
	for definition: Dictionary in ACTION_DEFINITIONS:
		var action := String(definition["id"])
		var action_value: Variant = actions.get(action, {})
		if typeof(action_value) != TYPE_DICTIONARY:
			continue
		var action_data := action_value as Dictionary
		for device: StringName in [DEVICE_KEYBOARD_MOUSE, DEVICE_GAMEPAD]:
			var serialized_value: Variant = action_data.get(String(device), [])
			if typeof(serialized_value) != TYPE_ARRAY:
				continue
			var decoded: Array[InputEvent] = []
			for entry: Variant in serialized_value as Array:
				if typeof(entry) != TYPE_DICTIONARY:
					continue
				var event := _event_from_dict(entry as Dictionary)
				if is_supported_event(event, device):
					decoded.append(event)
			if not decoded.is_empty():
				settings._bindings[action][device] = decoded
	return settings


func duplicate_settings() -> InputBindingSettings:
	return from_dict(to_dict())


func to_dict() -> Dictionary:
	var actions: Dictionary = {}
	for definition: Dictionary in ACTION_DEFINITIONS:
		var action := String(definition["id"])
		var serialized_devices: Dictionary = {}
		for device: StringName in [DEVICE_KEYBOARD_MOUSE, DEVICE_GAMEPAD]:
			var serialized_events: Array[Dictionary] = []
			for event: InputEvent in events_for(StringName(action), device):
				var serialized := _event_to_dict(event)
				if not serialized.is_empty():
					serialized_events.append(serialized)
			serialized_devices[String(device)] = serialized_events
		actions[action] = serialized_devices
	return {"actions": actions}


func events_for(action: StringName, device: StringName) -> Array[InputEvent]:
	var result: Array[InputEvent] = []
	var action_bindings: Dictionary = _bindings.get(String(action), {})
	var values: Variant = action_bindings.get(device, [])
	if typeof(values) != TYPE_ARRAY:
		return result
	for event: Variant in values as Array:
		if event is InputEvent:
			result.append((event as InputEvent).duplicate() as InputEvent)
	return result


func replace_device_binding(action: StringName, device: StringName, event: InputEvent) -> bool:
	if not has_action(action) or not is_supported_event(event, device):
		return false
	_bindings[String(action)][device] = [event.duplicate() as InputEvent]
	return true


func apply_to_input_map() -> void:
	for definition: Dictionary in ACTION_DEFINITIONS:
		var action: StringName = definition["id"]
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		for device: StringName in [DEVICE_KEYBOARD_MOUSE, DEVICE_GAMEPAD]:
			for event: InputEvent in events_for(action, device):
				InputMap.action_add_event(action, event)


func binding_text(action: StringName, device: StringName) -> String:
	var names: PackedStringArray = []
	for event: InputEvent in events_for(action, device):
		names.append(event_text(event))
	return " / ".join(names) if not names.is_empty() else "Unbound"


static func action_definitions() -> Array[Dictionary]:
	return ACTION_DEFINITIONS.duplicate(true)


static func has_action(action: StringName) -> bool:
	for definition: Dictionary in ACTION_DEFINITIONS:
		if definition["id"] == action:
			return true
	return false


static func is_supported_event(event: InputEvent, device: StringName) -> bool:
	if event == null:
		return false
	if device == DEVICE_KEYBOARD_MOUSE:
		return event is InputEventKey or (
			event is InputEventMouseButton
			and not _is_wheel_button((event as InputEventMouseButton).button_index)
		)
	if device == DEVICE_GAMEPAD:
		return event is InputEventJoypadButton or (
			event is InputEventJoypadMotion
			and absf((event as InputEventJoypadMotion).axis_value) >= 0.5
		)
	return false


static func event_text(event: InputEvent) -> String:
	if event is InputEventKey:
		var key := event as InputEventKey
		var code := key.physical_keycode if key.physical_keycode != 0 else key.keycode
		return OS.get_keycode_string(code)
	if event is InputEventMouseButton:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT:
				return "Mouse Left"
			MOUSE_BUTTON_RIGHT:
				return "Mouse Right"
			MOUSE_BUTTON_MIDDLE:
				return "Mouse Middle"
			_:
				return "Mouse %d" % (event as InputEventMouseButton).button_index
	if event is InputEventJoypadButton:
		return _joy_button_text((event as InputEventJoypadButton).button_index)
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		var direction := "+" if motion.axis_value > 0.0 else "-"
		return "Left Stick %s%s" % ["X" if motion.axis == JOY_AXIS_LEFT_X else "Y", direction]
	return event.as_text()


static func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	return event


static func _mouse_button(button_index: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	return event


static func _joy_button(button_index: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	return event


static func _joy_motion(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event


static func _event_to_dict(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key := event as InputEventKey
		return {
			"type": "key",
			"physical_keycode": int(key.physical_keycode),
			"keycode": int(key.keycode),
			"alt": key.alt_pressed,
			"shift": key.shift_pressed,
			"ctrl": key.ctrl_pressed,
			"meta": key.meta_pressed,
		}
	if event is InputEventMouseButton:
		return {"type": "mouse_button", "button": (event as InputEventMouseButton).button_index}
	if event is InputEventJoypadButton:
		return {"type": "joy_button", "button": (event as InputEventJoypadButton).button_index}
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		return {"type": "joy_motion", "axis": motion.axis, "value": motion.axis_value}
	return {}


static func _event_from_dict(data: Dictionary) -> InputEvent:
	match String(data.get("type", "")):
		"key":
			var key := InputEventKey.new()
			key.physical_keycode = int(data.get("physical_keycode", 0)) as Key
			key.keycode = int(data.get("keycode", 0)) as Key
			key.alt_pressed = bool(data.get("alt", false))
			key.shift_pressed = bool(data.get("shift", false))
			key.ctrl_pressed = bool(data.get("ctrl", false))
			key.meta_pressed = bool(data.get("meta", false))
			if key.physical_keycode == 0 and key.keycode == 0:
				return null
			return key
		"mouse_button":
			var mouse := InputEventMouseButton.new()
			mouse.button_index = int(data.get("button", 0)) as MouseButton
			return mouse if mouse.button_index > 0 else null
		"joy_button":
			var button := InputEventJoypadButton.new()
			button.button_index = int(data.get("button", -1)) as JoyButton
			return button if button.button_index >= 0 else null
		"joy_motion":
			var motion := InputEventJoypadMotion.new()
			motion.axis = int(data.get("axis", -1)) as JoyAxis
			motion.axis_value = clampf(float(data.get("value", 0.0)), -1.0, 1.0)
			return motion if motion.axis >= 0 and absf(motion.axis_value) >= 0.5 else null
		_:
			return null


static func _joy_button_text(button: JoyButton) -> String:
	match button:
		JOY_BUTTON_A:
			return "Gamepad A"
		JOY_BUTTON_B:
			return "Gamepad B"
		JOY_BUTTON_X:
			return "Gamepad X"
		JOY_BUTTON_Y:
			return "Gamepad Y"
		JOY_BUTTON_BACK:
			return "Gamepad Back"
		JOY_BUTTON_START:
			return "Gamepad Start"
		JOY_BUTTON_LEFT_STICK:
			return "Left Stick Press"
		JOY_BUTTON_RIGHT_STICK:
			return "Right Stick Press"
		JOY_BUTTON_LEFT_SHOULDER:
			return "Left Shoulder"
		JOY_BUTTON_RIGHT_SHOULDER:
			return "Right Shoulder"
		JOY_BUTTON_DPAD_UP:
			return "D-pad Up"
		JOY_BUTTON_DPAD_DOWN:
			return "D-pad Down"
		JOY_BUTTON_DPAD_LEFT:
			return "D-pad Left"
		JOY_BUTTON_DPAD_RIGHT:
			return "D-pad Right"
		_:
			return "Gamepad %d" % button


static func _is_wheel_button(button: MouseButton) -> bool:
	return button in [
		MOUSE_BUTTON_WHEEL_UP,
		MOUSE_BUTTON_WHEEL_DOWN,
		MOUSE_BUTTON_WHEEL_LEFT,
		MOUSE_BUTTON_WHEEL_RIGHT,
	]
