extends "res://tests/godot/test_case.gd"

const TextScaleScript := preload("res://scripts/dialogue/dialogue_text_scale.gd")
const SettingsScript := preload("res://scripts/settings/dialogue_settings.gd")
const RunnerScript := preload("res://scripts/dialogue/dialogue_runner.gd")
const UiPresenterScript := preload("res://scripts/dialogue/dialogue_ui_presenter.gd")
const UiScript := preload("res://scripts/dialogue/dialogue_ui.gd")
const DIALOGUE_ID := &"dialogue.test_ui.branching"
const FLAG_TRUSTED := &"flag.test_ui_trusted"

const CONTENT_DIRS: Array[String] = [
	"res://content/examples/valid",
	"res://content/examples/support",
]


func test_keyboard_completes_branching_dialogue_at_all_text_scales() -> void:
	for scale_name in TextScaleScript.supported_scale_names():
		_run_branching_dialogue_with_scale(scale_name, "keyboard")


func test_mouse_completes_branching_dialogue_at_all_text_scales() -> void:
	for scale_name in TextScaleScript.supported_scale_names():
		_run_branching_dialogue_with_scale(scale_name, "mouse")


func test_gamepad_completes_branching_dialogue_at_all_text_scales() -> void:
	for scale_name in TextScaleScript.supported_scale_names():
		_run_branching_dialogue_with_scale(scale_name, "gamepad")


func test_disabled_choice_reason_is_visible_when_focused() -> void:
	var setup := _make_setup("normal")
	setup.ui.present_choices([
		{
			"id": "enabled",
			"text": "Open",
			"enabled": true,
			"disabled_reason": "",
		},
		{
			"id": "locked",
			"text": "Locked",
			"enabled": false,
			"disabled_reason": "You do not have the ledger.",
		},
	])
	setup.ui.focus_choice_for_test(1)
	assert_eq(setup.ui.get_disabled_reason(), "You do not have the ledger.")
	_cleanup_setup(setup)


func test_backlog_records_presented_lines() -> void:
	var setup := _make_setup("normal")
	setup.ui.present_line(&"char.mart", "Mart", "First line.", "node_a")
	setup.ui.present_line(&"char.kalev", "Kalev", "Second line.", "node_b")
	assert_eq(setup.ui.get_backlog_entry_count(), 2)
	setup.ui.toggle_backlog_for_test()
	assert_true(setup.ui.is_showing())
	_cleanup_setup(setup)


func _run_branching_dialogue_with_scale(scale_name: String, input_mode: String) -> void:
	var setup := _make_setup(scale_name)
	setup.ui.set_text_scale(scale_name)
	assert_true(setup.runner.start(DIALOGUE_ID))
	assert_true(setup.ui.is_showing())
	assert_eq(setup.ui.get_text_scale(), scale_name)
	assert_eq(setup.ui.get_speaker_label_text(), "Mart")

	_advance_line(setup, input_mode)
	assert_true(setup.runner.is_waiting_for_choice())
	assert_true(setup.ui.is_choice_mode())

	match input_mode:
		"keyboard":
			_select_choice_keyboard(setup, "trust_mart")
		"mouse":
			setup.ui.select_choice_for_test("trust_mart")
		"gamepad":
			_select_choice_gamepad(setup, "trust_mart")

	assert_true(setup.state.get_flag(FLAG_TRUSTED))
	assert_false(setup.runner.is_waiting_for_choice())
	_advance_line(setup, input_mode)
	assert_false(setup.runner.is_active())
	assert_false(setup.ui.is_showing())
	_cleanup_setup(setup)


func _advance_line(setup: Dictionary, input_mode: String) -> void:
	match input_mode:
		"keyboard":
			_send_action(setup.runner, &"interact")
		"mouse":
			setup.runner.advance_for_test()
		"gamepad":
			_send_joy_button(setup.runner, JOY_BUTTON_A)
		_:
			setup.runner.advance_for_test()


func _select_choice_keyboard(setup: Dictionary, choice_id: String) -> void:
	if choice_id == "trust_mart":
		_send_action(setup.ui, &"ui_accept")
	else:
		setup.ui.select_choice_for_test(choice_id)


func _select_choice_gamepad(setup: Dictionary, choice_id: String) -> void:
	if choice_id == "trust_mart":
		_send_joy_button(setup.ui, JOY_BUTTON_A)
	else:
		setup.ui.select_choice_for_test(choice_id)


func _make_setup(scale_name: String) -> Dictionary:
	var root := _make_root()
	var ui = UiScript.new()
	root.add_child(ui)
	ui.set_text_scale(scale_name)
	var settings = SettingsScript.default_settings()
	settings.text_scale = scale_name
	settings.text_speed = "instant"
	ui.apply_settings(settings)

	var db := ContentDB.new()
	assert_true(db.load_from_directories(CONTENT_DIRS))

	var state := GameState.new()
	var runner = RunnerScript.new()
	root.add_child(runner)

	var presenter: RefCounted = UiPresenterScript.new()
	presenter.configure(ui, runner)
	runner.configure(db, state, presenter)

	return {
		"root": root,
		"ui": ui,
		"runner": runner,
		"state": state,
	}


func _cleanup_setup(setup: Dictionary) -> void:
	_cleanup_node(setup.get("root"))


func _make_root() -> Node:
	var root := Node.new()
	(_tree().root as Node).add_child(root)
	return root


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _cleanup_node(node: Node) -> void:
	if is_instance_valid(node):
		node.free()


func _send_action(target: Node, action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	target._unhandled_input(event)


func _send_joy_button(target: Node, button_index: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	event.pressed = true
	target._unhandled_input(event)
