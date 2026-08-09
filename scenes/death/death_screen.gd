extends Control

## Brief death epilogue shown after Kalev's health reaches zero.
## The automatic return keeps a failed run from leaving the player at a dead end,
## while the focused button gives keyboard, mouse, and gamepad players control.

const MAIN_MENU_PATH := "res://scenes/menu/main_menu.tscn"
const RETURN_DELAY_SEC := 4.0

@onready var _countdown: Label = $Center/Panel/Content/Countdown
@onready var _return_button: Button = $Center/Panel/Content/ReturnButton

var _remaining_sec := RETURN_DELAY_SEC
var _transition_started := false


func _ready() -> void:
	_return_button.pressed.connect(_return_to_main_menu)
	_return_button.grab_focus()
	_update_countdown()


func _process(delta: float) -> void:
	if _transition_started:
		return
	_remaining_sec = maxf(0.0, _remaining_sec - delta)
	_update_countdown()
	if is_zero_approx(_remaining_sec):
		_return_to_main_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"ui_cancel"):
		_return_to_main_menu()


func _update_countdown() -> void:
	if _countdown == null:
		return
	_countdown.text = "Returning to the main menu in %d" % ceili(_remaining_sec)


func _return_to_main_menu() -> void:
	if _transition_started:
		return
	_transition_started = true
	var error := get_tree().change_scene_to_file(MAIN_MENU_PATH)
	if error != OK:
		_transition_started = false
		push_error("Could not return to the main menu: %s" % error_string(error))
