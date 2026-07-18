extends "res://tests/godot/map_view_3d_test_base.gd"

## Camera-mode integration kept separate from the broader runtime test so its
## result does not depend on actor-facing assertions.


func test_c_toggles_first_person_and_restores_third_person() -> void:
	var scene_root := Node2D.new()
	var map_root := Node2D.new()
	var actors := Node2D.new()
	var player := PLAYER_SCENE.instantiate() as Player
	scene_root.add_child(map_root)
	scene_root.add_child(actors)
	actors.add_child(player)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene_root)

	var definition := LowerTownSlice.create()
	var bootstrap := {
		"definition": definition,
		"grid": MapBuilder.build(definition),
		"assembled": {"buildings": [], "props": []},
	}
	var runtime := MapViewRuntime.install(scene_root, bootstrap, map_root, player)
	var rig := runtime.get_node("PlayerRig") as SharedCharacterRig
	var camera := runtime.view.view_camera()
	var third_person_size := camera.size
	var third_person_yaw := camera.rotation_degrees.y

	var camera_toggle := InputEventKey.new()
	camera_toggle.physical_keycode = KEY_C
	camera_toggle.pressed = true
	runtime._unhandled_input(camera_toggle)

	assert_true(runtime.is_first_person(), "C must switch to first-person view")
	assert_eq(camera.projection, Camera3D.PROJECTION_PERSPECTIVE)
	assert_true(is_equal_approx(camera.fov, MapViewRuntime.FIRST_PERSON_FOV_DEGREES))
	assert_true(is_equal_approx(camera.rotation_degrees.x, MapViewRuntime.FIRST_PERSON_PITCH_DEGREES))
	assert_true(is_equal_approx(camera.rotation_degrees.y, third_person_yaw), "switching view must preserve yaw")
	assert_true(
		camera.position.is_equal_approx(rig.position + Vector3.UP * MapViewRuntime.FIRST_PERSON_EYE_HEIGHT),
		"first-person camera must sit at the player's eye height"
	)
	assert_false(rig.visible, "the player rig must not obstruct first-person view")

	var first_person_fov := camera.fov
	runtime.zoom_view_steps(1.0)
	assert_true(
		is_equal_approx(camera.fov, first_person_fov),
		"orthographic wheel zoom must not alter first-person view"
	)

	runtime._unhandled_input(camera_toggle)
	assert_false(runtime.is_first_person(), "pressing C again must restore third-person view")
	assert_eq(camera.projection, Camera3D.PROJECTION_ORTHOGONAL)
	assert_true(is_equal_approx(camera.size, third_person_size))
	assert_true(is_equal_approx(camera.rotation_degrees.x, MapView3D.CAMERA_PITCH_DEGREES))
	assert_true(is_equal_approx(camera.rotation_degrees.y, third_person_yaw), "returning must preserve yaw")
	assert_true(rig.visible, "the player rig must return in third-person view")
	scene_root.free()
