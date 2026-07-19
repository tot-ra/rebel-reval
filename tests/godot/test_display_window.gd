extends "res://tests/godot/test_case.gd"

const DisplayWindowScript := preload("res://scripts/display/display_window.gd")


func test_target_size_uses_screen_fraction() -> void:
	var target := DisplayWindowScript.target_window_size_for_screen(Vector2i(3456, 2234), 0.8)
	assert_eq(target, Vector2i(2764, 1787), "80% of the user's display dimensions")


func test_target_size_falls_back_when_screen_is_unavailable() -> void:
	var target := DisplayWindowScript.target_window_size_for_screen(Vector2i.ZERO)
	assert_eq(target, Vector2i(1920, 1080), "headless or invalid screens keep project defaults")
