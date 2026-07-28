extends "res://tests/godot/test_case.gd"


func test_debug_overlay_starts_hidden_and_toggles_visibility() -> void:
	var overlay := DebugOverlay.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(overlay)

	assert_false(overlay.visible, "debug overlay must start hidden")
	overlay.toggle_visibility()
	assert_true(overlay.visible, "toggle must show the overlay")
	overlay.toggle_visibility()
	assert_false(overlay.visible, "second toggle must hide the overlay")
	var reset := overlay.find_child("ResetButton", true, false) as Button
	var small_showcase := overlay.find_child("SmallAssetShowcaseButton", true, false) as Button
	var large_showcase := overlay.find_child("LargeAssetShowcaseButton", true, false) as Button
	assert_true(reset != null, "debug overlay must keep time reset available")
	assert_true(small_showcase != null, "debug overlay must expose the small-asset gallery")
	assert_true(large_showcase != null, "debug overlay must expose the large-asset gallery")
	assert_eq(small_showcase.text, "Open small assets")
	assert_eq(large_showcase.text, "Open large assets")
	assert_eq(small_showcase.focus_mode, Control.FOCUS_ALL)
	assert_eq(large_showcase.focus_mode, Control.FOCUS_ALL)
	overlay.queue_free()


func test_time_controls_change_runtime_without_touching_game_state() -> void:
	var runtime := MapViewRuntime.new()
	var overlay := DebugOverlay.new()

	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(overlay)
	overlay.set_runtime(runtime)

	var state_before := GameState.new()
	state_before.set_flag(&"flag.debug_probe", true)
	SessionState.state = state_before

	overlay.visible = true
	(overlay.find_child("FasterButton", true, false) as Button).pressed.emit()
	assert_true(
		is_equal_approx(runtime.effective_time_speed(), 2.0),
		"faster button must step the runtime clock"
	)
	assert_true(
		state_before.get_flag(&"flag.debug_probe"),
		"time controls must not mutate GameState"
	)

	(overlay.find_child("PauseButton", true, false) as Button).pressed.emit()
	assert_true(runtime.time_paused, "pause button must freeze the runtime clock")
	(overlay.find_child("ResetButton", true, false) as Button).pressed.emit()
	assert_false(runtime.time_paused, "reset must unpause")
	assert_true(
		is_equal_approx(runtime.effective_time_speed(), 1.0),
		"reset must return to real-time pacing"
	)

	overlay.queue_free()
	runtime.free()
