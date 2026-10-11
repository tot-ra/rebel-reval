class_name PlayerActionInput
extends RefCounted

static var _guard_toggle_active := false
static var _guard_was_pressed := false
## Physics frame in which each action edge was last handed out (see _consume).
static var _edge_frames: Dictionary = {}


static func reset_guard_toggle() -> void:
	_guard_toggle_active = false
	_guard_was_pressed = false


## Dodge and roll presses. The attack press is read by the player's charge
## clock (read_attack_just_pressed) because a tap and a hold are different verbs.
static func read_pressed_actions() -> Array[PlayerActionKind.Kind]:
	var pressed: Array[PlayerActionKind.Kind] = []
	if _consume(PlayerActionKind.ACTION_DODGE, true):
		pressed.append(PlayerActionKind.Kind.DODGE)
	if (
		InputMap.has_action(PlayerActionKind.ACTION_ROLL)
		and _consume(PlayerActionKind.ACTION_ROLL, true)
	):
		pressed.append(PlayerActionKind.Kind.ROLL)
	return pressed


## Left click never attacks through the input map: MapClickInputController owns
## it and decides per camera mode whether it means attack, interact, or (top-down
## only) travel. Keyboard and gamepad bindings still trigger attacks directly.
static func read_attack_just_pressed() -> bool:
	return not _is_left_mouse_pressed() and _consume(PlayerActionKind.ACTION_ATTACK, true)


static func read_attack_just_released() -> bool:
	return not _is_left_mouse_pressed() and _consume(PlayerActionKind.ACTION_ATTACK, false)


## WHY: Input.is_action_just_pressed/just_released stay true for every read in
## the same physics frame, and a tap inside one frame reports both. Handing each
## edge out once per frame stops repeated reads from replaying one press as
## several attacks or dodges (phantom stamina spend).
static func _consume(action: StringName, press: bool) -> bool:
	var edge := (
		Input.is_action_just_pressed(action) if press else Input.is_action_just_released(action)
	)
	if not edge:
		return false
	var key := "%s:%s" % [action, "press" if press else "release"]
	var frame := Engine.get_physics_frames()
	if int(_edge_frames.get(key, -1)) == frame:
		return false
	_edge_frames[key] = frame
	return true


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
