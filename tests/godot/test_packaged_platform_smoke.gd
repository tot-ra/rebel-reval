extends "res://tests/godot/test_case.gd"

const PlatformSmokeScript := preload("res://scripts/demo/packaged_platform_smoke.gd")


func test_packaged_platform_smoke_requires_explicit_user_argument() -> void:
	assert_false(PlatformSmokeScript.is_requested(PackedStringArray()))
	assert_false(PlatformSmokeScript.is_requested(PackedStringArray(["--unrelated"])))
	assert_true(
		PlatformSmokeScript.is_requested(
			PackedStringArray([PlatformSmokeScript.USER_ARGUMENT])
		)
	)


func test_main_menu_ships_packaged_platform_smoke_entrypoint() -> void:
	var menu_scene := load("res://scenes/menu/main_menu.tscn") as PackedScene
	assert_true(menu_scene != null)
	var menu := menu_scene.instantiate()
	assert_true(menu != null)
	var verifier := menu.get_node_or_null("PackagedPlatformSmoke")
	assert_true(verifier != null)
	assert_true(verifier.get_script() == PlatformSmokeScript)
	menu.free()
