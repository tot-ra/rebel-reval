extends "res://tests/godot/test_case.gd"

const Sight := preload("res://scripts/combat/spirit_sight.gd")
const Settings := preload("res://scripts/settings/gameplay_accessibility_settings.gd")
const Bindings := preload("res://scripts/settings/input_binding_settings.gd")

var _host: Node3D
var _sight: Node
var _environment: Environment
var _sun: DirectionalLight3D


func before_each() -> void:
	super.before_each()
	_host = Node3D.new()
	_tree().root.add_child(_host)
	_environment = Environment.new()
	_environment.adjustment_enabled = false
	_environment.adjustment_saturation = 0.83
	_environment.ambient_light_energy = 0.72
	_environment.ambient_light_color = Color(0.7, 0.6, 0.4)
	_sun = DirectionalLight3D.new()
	_sun.light_energy = 1.3
	_host.add_child(_sun)
	_sight = Sight.new()
	_sight.follow_session = false
	_sight.state = GameState.new()
	_sight.environment_override = _environment
	_sight.sun_override = _sun
	_host.add_child(_sight)


func after_each() -> void:
	_host.free()
	super.after_each()


func test_toggle_and_exact_restore_without_accumulation() -> void:
	var original := _properties()
	assert_true(_sight.toggle())
	assert_true(_sight.state.spirit_sight)
	assert_true(_sight.state.in_spirit_world)
	_sight.blend = 1.0
	_sight.compose_grade()
	assert_approx(_environment.adjustment_saturation, 0.25)
	assert_approx(_environment.ambient_light_energy, 0.72 * 0.6)
	assert_approx(_sun.light_energy, 1.3 * 0.6)
	_sight.compose_grade()
	assert_approx(_sun.light_energy, 1.3 * 0.6)
	_sight.leave_immediately()
	assert_eq(_properties(), original)
	assert_false(_sight.state.in_spirit_world)


func test_normal_exit_tweens_back_and_rapid_reversal_restores() -> void:
	var original := _properties()
	_sight.toggle()
	await _tree().create_timer(0.7).timeout
	assert_approx(_sight.blend, 1.0)
	_sight.toggle()
	await _tree().create_timer(0.1).timeout
	assert_true(_sight.blend > 0.0 and _sight.blend < 1.0)
	_sight.toggle()
	_sight.toggle()
	await _tree().create_timer(0.7).timeout
	assert_approx(_sight.blend, 0.0)
	_sight.leave_immediately()
	assert_eq(_properties(), original)


func test_weather_updates_are_not_frozen_or_multiplied() -> void:
	_sight.toggle()
	_sight.blend = 1.0
	_sight.compose_grade()
	_sight._restore_grade()
	_environment.adjustment_saturation = 1.17
	_environment.ambient_light_energy = 0.22
	_sun.light_energy = 0.05
	var physical := _properties()
	_sight.compose_grade()
	assert_approx(_sun.light_energy, 0.03)
	_sight.leave_immediately()
	assert_eq(_properties(), physical)


func test_save_load_is_physical_and_encounter_ownership_is_independent() -> void:
	_sight.toggle()
	var state: GameState = _sight.state
	var payload := state.save_payload()
	assert_false(payload.has("spirit_sight"))
	assert_false(payload.has("in_spirit_world"))
	assert_false(payload.has("spirit_encounter_active"))
	state.in_spirit_world = true
	_sight.leave_immediately()
	assert_true(state.in_spirit_world)
	state.in_spirit_world = false
	assert_false(state.in_spirit_world)
	state.spirit_sight = true
	state.in_spirit_world = true
	state.load_payload(payload)
	assert_false(state.spirit_sight)
	assert_false(state.in_spirit_world)


func test_dialogue_modal_cutscene_and_pause_reject_and_cancel() -> void:
	for group: StringName in [&"demo_dialogue_active", &"modal_input_overlay", &"cutscene_active"]:
		assert_true(_sight.toggle())
		var blocker := Control.new()
		_host.add_child(blocker)
		blocker.add_to_group(group)
		_sight.enforce_availability()
		assert_false(_sight.state.spirit_sight)
		assert_false(_sight.toggle())
		blocker.free()
	assert_true(_sight.toggle())
	_tree().paused = true
	_sight.enforce_availability()
	assert_false(_sight.state.spirit_sight)
	_tree().paused = false


func test_reduced_motion_crossfade_and_intensity_roundtrip() -> void:
	_sight.reduced_motion = true
	assert_approx(_sight.transition_duration(), 0.2)
	_sight.toggle()
	await _until_blend(1.0)
	assert_approx(_sight.blend, 1.0)
	_sight.compose_grade()
	assert_true(_sight._material.get_shader_parameter("reduced_motion"))
	_sight.intensity = 0.0
	_sight.compose_grade()
	assert_false(_environment.adjustment_enabled)
	assert_true(_sight.state.spirit_sight, "Intensity never changes the gameplay layer")
	var settings := Settings.from_dict({"spirit_sight_intensity": 0.4})
	assert_approx(settings.duplicate_settings().spirit_sight_intensity, 0.4)
	assert_approx(Settings.from_dict(settings.to_dict()).spirit_sight_intensity, 0.4)
	assert_approx(Settings.from_dict({"spirit_sight_intensity": 3.0}).spirit_sight_intensity, 1.0)


func test_v_l3_defaults_and_old_walk_binding_migrate() -> void:
	var bindings := Bindings.default_settings()
	var keyboard := bindings.events_for(&"player_spirit_sight", Bindings.DEVICE_KEYBOARD_MOUSE)
	var gamepad := bindings.events_for(&"player_spirit_sight", Bindings.DEVICE_GAMEPAD)
	assert_eq((keyboard[0] as InputEventKey).physical_keycode, KEY_V)
	assert_eq((gamepad[0] as InputEventJoypadButton).button_index, JOY_BUTTON_LEFT_STICK)
	var old := {"version": 2, "actions": {
		"ui_shift": {"gamepad": [{"type": "joy_button", "button": JOY_BUTTON_LEFT_STICK}]},
	}}
	var migrated := Bindings.from_dict(old)
	assert_true(migrated.events_for(&"ui_shift", Bindings.DEVICE_GAMEPAD).is_empty())
	old["actions"]["ui_shift"]["gamepad"][0]["button"] = JOY_BUTTON_Y
	assert_eq(
		(Bindings.from_dict(old).events_for(&"ui_shift", Bindings.DEVICE_GAMEPAD)[0]
		as InputEventJoypadButton).button_index, JOY_BUTTON_Y
	)


func test_player_walk_combat_swim_scripted_move_and_interact_exit() -> void:
	var player := Player.new()
	_host.add_child(player)
	var controller: Node = player.get_node("SpiritSight")
	controller.environment_override = _environment
	controller.sun_override = _sun
	assert_true(controller.toggle())
	assert_true(player.is_walking())
	assert_false(player.request_heavy_attack())
	assert_false(player.try_start_dodge())
	assert_false(player.try_start_roll())
	player.begin_attack_charge()
	assert_false(player.is_attack_charging())
	var item: Interactable = load("res://scenes/interaction/interactable.tscn").instantiate()
	_host.add_child(item)
	item.set_interact_callback(func(_actor: Node) -> void:
		assert_false(SessionState.state.spirit_sight, "Exit must precede object use")
	)
	assert_true(item.interact(player))
	assert_false(SessionState.state.spirit_sight)
	assert_true(controller.toggle())
	player._swim.medium = PlayerSwimState.Medium.SWIM
	controller.enforce_availability()
	assert_false(SessionState.state.spirit_sight)
	assert_false(controller.toggle())
	player._swim.medium = PlayerSwimState.Medium.DIVE
	assert_false(controller.toggle())
	player._swim.medium = PlayerSwimState.Medium.WALK
	player.combat_input_enabled = false
	assert_false(controller.toggle())
	player.combat_input_enabled = true
	assert_true(controller.toggle())
	var replacement := GameState.new()
	SessionState.replace_state(replacement, &"test")
	assert_false(replacement.spirit_sight)
	assert_approx(controller.blend, 0.0)


func test_keyboard_and_gamepad_toggle_events() -> void:
	Bindings.default_settings().apply_to_input_map()
	var keyboard := InputEventKey.new()
	keyboard.physical_keycode = KEY_V
	keyboard.pressed = true
	_sight._unhandled_input(keyboard)
	assert_true(_sight.state.spirit_sight)
	keyboard.echo = true
	_sight._unhandled_input(keyboard)
	assert_true(_sight.state.spirit_sight)
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_LEFT_STICK
	pad.pressed = true
	_sight._unhandled_input(pad)
	assert_false(_sight.state.spirit_sight)



## Polls frames instead of awaiting Tween.finished: a killed tween never emits, which hangs the run.
func _until_blend(target: float) -> void:
	var deadline := Time.get_ticks_msec() + 1000
	while absf(_sight.blend - target) > 0.00001 and Time.get_ticks_msec() < deadline:
		await _tree().process_frame
	assert_almost_eq(_sight.blend, target, 0.00001, "spirit_sight=%s" % _sight.state.spirit_sight)


func _properties() -> Array:
	return [_environment.adjustment_enabled, _environment.adjustment_saturation,
		_environment.ambient_light_energy, _environment.ambient_light_color, _sun.light_energy]


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func assert_approx(actual: float, expected: float) -> void:
	assert_almost_eq(actual, expected, 0.00001)
