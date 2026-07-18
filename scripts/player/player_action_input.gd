class_name PlayerActionInput
extends RefCounted

static func read_pressed_actions() -> Array[PlayerActionKind.Kind]:
	var pressed: Array[PlayerActionKind.Kind] = []
	if Input.is_action_just_pressed(PlayerActionKind.ACTION_ATTACK):
		pressed.append(PlayerActionKind.Kind.ATTACK)
	if Input.is_action_just_pressed(PlayerActionKind.ACTION_DODGE):
		pressed.append(PlayerActionKind.Kind.DODGE)
	return pressed


static func read_guard_held() -> bool:
	return Input.is_action_pressed(PlayerActionKind.ACTION_GUARD)
