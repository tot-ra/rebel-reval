extends "res://tests/godot/test_case.gd"

const Hub := preload("res://scripts/reflection/hingepuu_hub.gd")


func test_enter_leave_restores_exact_city_position_and_modal_state() -> void:
	var state := GameState.new()
	var actor := Node2D.new()
	var hub := Hub.new() as HingepuuHub
	(Engine.get_main_loop() as SceneTree).root.add_child(actor)
	(Engine.get_main_loop() as SceneTree).root.add_child(hub)
	actor.global_position = Vector2(123.25, -98.5)
	assert_true(hub.enter(state, actor))
	assert_true(hub.is_active())
	assert_true(hub.is_in_group("modal_input_overlay"))
	assert_true(hub.leave())
	assert_false(hub.is_active())
	assert_false(hub.is_in_group("modal_input_overlay"))
	assert_eq(actor.global_position, Vector2(123.25, -98.5))
	actor.queue_free()
	hub.queue_free()


func test_saved_return_context_resumes_after_load() -> void:
	var state := GameState.new()
	var actor := Node2D.new()
	var first_hub := Hub.new() as HingepuuHub
	(Engine.get_main_loop() as SceneTree).root.add_child(actor)
	(Engine.get_main_loop() as SceneTree).root.add_child(first_hub)
	actor.global_position = Vector2(900.5, 410.25)
	assert_true(first_hub.enter(state, actor))
	var loaded := GameState.new()
	var errors := loaded.load_payload(state.save_payload())
	assert_true(errors.is_empty())
	assert_eq(loaded.get_location_state(Hub.ACTIVE_KEY), "true")
	var resumed := Hub.new() as HingepuuHub
	(Engine.get_main_loop() as SceneTree).root.add_child(resumed)
	assert_true(resumed.restore_after_load(loaded, actor))
	assert_true(resumed.leave())
	assert_eq(actor.global_position, Vector2(900.5, 410.25))
	actor.queue_free()
	first_hub.queue_free()
	resumed.queue_free()


func test_city_input_has_keyboard_and_gamepad_bindings() -> void:
	assert_true(InputMap.has_action("ui_left"))
	assert_true(InputMap.has_action("ui_right"))
	assert_true(InputMap.has_action("interact"))
	var found_gamepad := false
	for event in InputMap.action_get_events("interact"):
		if event is InputEventJoypadButton:
			found_gamepad = true
	assert_true(found_gamepad)
