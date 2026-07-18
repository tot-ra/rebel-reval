class_name PlayerActionInput
extends RefCounted

static func read_pressed_actions() -> Array[PlayerActionKind.Kind]:
	var pressed: Array[PlayerActionKind.Kind] = []
	# Left click is reserved for click-to-move in gameplay scenes. Keyboard and
	# gamepad bindings still trigger attacks.
	if read_attack_just_pressed():
		pressed.append(PlayerActionKind.Kind.ATTACK)
	if Input.is_action_just_pressed(PlayerActionKind.ACTION_DODGE):
		pressed.append(PlayerActionKind.Kind.DODGE)
	return pressed


static func read_attack_just_pressed() -> bool:
	return Input.is_action_just_pressed(PlayerActionKind.ACTION_ATTACK) and not _is_left_mouse_pressed()


static func read_attack_just_released() -> bool:
	return (
		Input.is_action_just_released(PlayerActionKind.ACTION_ATTACK)
		and not _is_left_mouse_pressed()
	)


static func read_attack_held() -> bool:
	return Input.is_action_pressed(PlayerActionKind.ACTION_ATTACK) and not _is_left_mouse_pressed()


static func read_guard_held() -> bool:
	return Input.is_action_pressed(PlayerActionKind.ACTION_GUARD)


static func _is_left_mouse_pressed() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
