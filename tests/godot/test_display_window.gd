extends "res://tests/godot/test_case.gd"

const DisplayWindowScript := preload("res://scripts/display/display_window.gd")


func test_target_size_fits_screen_fraction_at_design_aspect_ratio() -> void:
	var target := DisplayWindowScript.target_window_size_for_screen(Vector2i(3456, 2234), 0.8)
	assert_eq(target, Vector2i(2764, 1555), "window fits within 80% without distorting 16:9 UI")


func test_target_size_is_height_limited_on_wide_displays() -> void:
	var target := DisplayWindowScript.target_window_size_for_screen(Vector2i(3440, 1440), 0.8)
	assert_eq(target, Vector2i(2048, 1152), "window uses the limiting display dimension")


func test_target_size_falls_back_when_screen_is_unavailable() -> void:
	var target := DisplayWindowScript.target_window_size_for_screen(Vector2i.ZERO)
	assert_eq(target, Vector2i(1920, 1080), "headless or invalid screens keep project defaults")
