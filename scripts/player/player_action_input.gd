class_name PlayerActionInput
extends RefCounted

static var _guard_toggle_active := false
static var _guard_was_pressed := false


static func reset_guard_toggle() -> void:
	_guard_toggle_active = false
	_guard_was_pressed = false


static func read_pressed_actions() -> Array[PlayerActionKind.Kind]:
	var pressed: Array[PlayerActionKind.Kind] = []
	# Left click never attacks through the input map: MapClickInputController owns
	# it and decides per camera mode whether it means attack, interact, or (top-down
	# only) travel. Keyboard and gamepad bindings still trigger attacks directly.
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
	var pressed := Input.is_action_pressed(PlayerActionKind.ACTION_GUARD)
	if _guard_uses_hold():
		_guard_was_pressed = pressed
		return pressed
	var just_pressed := pressed and not _guard_was_pressed
	_guard_was_pressed = pressed
	if just_pressed:
		_guard_toggle_active = not _guard_toggle_active
	return _guard_toggle_active


static func _guard_uses_hold() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or not tree.root.has_node("/root/UserSettings"):
		return true
	var settings: Node = tree.root.get_node("/root/UserSettings")
	if not ("gameplay" in settings):
		return true
	var gameplay: Variant = settings.get("gameplay")
	if gameplay == null or not gameplay.has_method("guard_uses_hold"):
		return true
	return bool(gameplay.guard_uses_hold())


static func _is_left_mouse_pressed() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
