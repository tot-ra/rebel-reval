extends "res://tests/godot/test_case.gd"

const PackagedWalkthroughScript := preload("res://scripts/demo/packaged_demo_walkthrough.gd")


func test_packaged_walkthrough_requires_explicit_user_argument() -> void:
	assert_false(PackagedWalkthroughScript.is_requested(PackedStringArray()))
	assert_false(PackagedWalkthroughScript.is_requested(PackedStringArray(["--unrelated"])))
	assert_true(
		PackagedWalkthroughScript.is_requested(
			PackedStringArray([PackagedWalkthroughScript.USER_ARGUMENT])
		)
	)


func test_packaged_walkthrough_extracts_optional_capture_directory() -> void:
	assert_eq(PackagedWalkthroughScript.capture_directory(PackedStringArray()), "")
	assert_eq(
		PackagedWalkthroughScript.capture_directory(
			PackedStringArray(["--capture-demo-dir=/tmp/reval demo"])
		),
		"/tmp/reval demo"
	)


func test_main_menu_ships_packaged_walkthrough_entrypoint() -> void:
	var menu_scene := load("res://scenes/menu/main_menu.tscn") as PackedScene
	assert_true(menu_scene != null)
	var menu := menu_scene.instantiate()
	assert_true(menu != null)
	var verifier := menu.get_node_or_null("PackagedDemoWalkthrough")
	assert_true(verifier != null)
	assert_true(verifier.get_script() == PackagedWalkthroughScript)
	menu.free()
