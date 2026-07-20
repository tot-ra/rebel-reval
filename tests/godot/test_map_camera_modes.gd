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
	_free_map_scene(scene_root)


func test_interior_ceiling_hides_for_top_down_and_shows_in_first_person() -> void:
	var scene_root := Node2D.new()
	var map_root := Node2D.new()
	var actors := Node2D.new()
	var player := PLAYER_SCENE.instantiate() as Player
	scene_root.add_child(map_root)
	scene_root.add_child(actors)
	actors.add_child(player)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene_root)

	var definition := KalevSmithyDefinition.create()
	var bootstrap := {
		"definition": definition,
		"grid": MapBuilder.build(definition),
		"assembled": {"buildings": [], "props": []},
	}
	var runtime := MapViewRuntime.install(scene_root, bootstrap, map_root, player)
	assert_true(runtime.view.has_node("InteriorShell/Ceiling"), "smithy must build a shared ceiling shell")
	assert_false(
		runtime.view.is_interior_shell_visible(),
		"top-down gameplay must hide the ceiling for floor readability"
	)
	assert_true(
		runtime.view.uses_interior_top_down_background(),
		"top-down interiors must clear to black instead of sky"
	)
	var world_env := runtime.view.get_node("ViewEnvironment") as WorldEnvironment
	assert_eq(world_env.environment.background_mode, Environment.BG_COLOR)
	assert_eq(world_env.environment.background_color, MapView3D.BACKGROUND_INTERIOR_TOP_DOWN_COLOR)

	var camera_toggle := InputEventKey.new()
	camera_toggle.physical_keycode = KEY_C
	camera_toggle.pressed = true
	runtime._unhandled_input(camera_toggle)
	assert_true(runtime.is_first_person(), "test setup must enter first-person view")
	assert_true(
		runtime.view.is_interior_shell_visible(),
		"first-person must show the raised ceiling shell"
	)
	assert_false(
		runtime.view.uses_interior_top_down_background(),
		"first-person must restore the sky dome for window views"
	)
	assert_eq(world_env.environment.background_mode, Environment.BG_SKY)

	runtime._unhandled_input(camera_toggle)
	assert_false(runtime.is_first_person(), "pressing C again must restore third-person view")
	assert_false(
		runtime.view.is_interior_shell_visible(),
		"returning to top-down must hide the ceiling again"
	)
	assert_true(
		runtime.view.uses_interior_top_down_background(),
		"returning to top-down must restore the black void"
	)
	assert_eq(world_env.environment.background_mode, Environment.BG_COLOR)
	_free_map_scene(scene_root)


func test_first_person_movement_follows_camera_yaw_via_gameplay_rotation() -> void:
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

	var camera_toggle := InputEventKey.new()
	camera_toggle.physical_keycode = KEY_C
	camera_toggle.pressed = true
	runtime._unhandled_input(camera_toggle)
	assert_true(runtime.is_first_person(), "test setup must enter first-person view")

	var screen_up_before := player.movement_direction_for_screen_input(Vector2.UP)
	runtime._camera_controller.rotate_view_degrees(45.0)
	runtime._apply_view_rotation(0.016)
	var screen_up_after := player.movement_direction_for_screen_input(Vector2.UP)

	assert_false(
		screen_up_after.is_equal_approx(screen_up_before),
		"first-person keyboard movement must follow camera yaw from the gameplay rotation path"
	)
	assert_true(
		is_equal_approx(screen_up_after.length(), 1.0),
		"re-projected first-person movement must stay normalized"
	)
	_free_map_scene(scene_root)


func test_first_person_mouse_drag_looks_vertically_and_clamps_pitch() -> void:
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
	var camera := runtime.view.view_camera()
	runtime.set_first_person(true)
	var yaw_before := camera.rotation_degrees.y
	var screen_up_before_pitch := player.movement_direction_for_screen_input(Vector2.UP)

	# The first sample arms right-drag; separate vertical and horizontal samples
	# prove that each mouse axis controls only its matching camera axis.
	runtime._apply_mouse_rotation_from_position(Vector2(100.0, 200.0), true)
	runtime._apply_mouse_rotation_from_position(Vector2(100.0, 100.0), true)
	assert_true(
		is_equal_approx(
			camera.rotation_degrees.x,
			MapViewRuntime.FIRST_PERSON_PITCH_DEGREES + 100.0 * MapViewRuntime.MOUSE_ROTATE_DEGREES_PER_PIXEL
		),
		"first-person right-drag must look up and down"
	)
	assert_true(
		player.movement_direction_for_screen_input(Vector2.UP).is_equal_approx(screen_up_before_pitch),
		"vertical look must not change ground-plane movement"
	)

	runtime._apply_mouse_rotation_from_position(Vector2(60.0, 100.0), true)
	assert_true(
		is_equal_approx(
			camera.rotation_degrees.y,
			wrapf(yaw_before + 40.0 * MapViewRuntime.MOUSE_ROTATE_DEGREES_PER_PIXEL, -180.0, 180.0)
		),
		"first-person right-drag must keep horizontal look"
	)

	runtime._apply_mouse_rotation_from_position(Vector2(60.0, -1000.0), true)
	assert_true(
		is_equal_approx(camera.rotation_degrees.x, MapViewRuntime.FIRST_PERSON_MAX_PITCH_DEGREES),
		"looking up must stop before the camera flips"
	)
	runtime._apply_mouse_rotation_from_position(Vector2(60.0, 2000.0), true)
	assert_true(
		is_equal_approx(camera.rotation_degrees.x, MapViewRuntime.FIRST_PERSON_MIN_PITCH_DEGREES),
		"looking down must stop before the camera flips"
	)

	runtime._apply_mouse_rotation_from_position(Vector2(60.0, 2000.0), false)
	runtime.set_first_person(false)
	runtime._apply_mouse_rotation_from_position(Vector2(60.0, 100.0), true)
	runtime._apply_mouse_rotation_from_position(Vector2(60.0, 0.0), true)
	assert_true(
		is_equal_approx(camera.rotation_degrees.x, MapView3D.CAMERA_PITCH_DEGREES),
		"third-person right-drag must keep the authored dimetric pitch"
	)
	_free_map_scene(scene_root)


func test_quick_access_camera_button_toggles_first_person() -> void:
	var scene_root := Node2D.new()
	var map_root := Node2D.new()
	var actors := Node2D.new()
	var player := PLAYER_SCENE.instantiate() as Player
	scene_root.add_child(map_root)
	scene_root.add_child(actors)
	actors.add_child(player)
	var menu := QuickAccessMenu.new()
	player.add_child(menu)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene_root)

	var definition := KalevSmithyDefinition.create()
	var bootstrap := {
		"definition": definition,
		"grid": MapBuilder.build(definition),
		"assembled": {"buildings": [], "props": []},
	}
	var runtime := MapViewRuntime.install(scene_root, bootstrap, map_root, player)
	menu._refresh_availability()

	var camera_button := menu.find_child("CameraButton", true, false) as Button
	assert_false(camera_button.disabled, "camera button must be available on 3D maps")
	camera_button.pressed.emit()
	assert_true(runtime.is_first_person(), "quick access must switch to first-person view")

	camera_button.pressed.emit()
	assert_false(runtime.is_first_person(), "quick access must restore third-person view")
	_free_map_scene(scene_root)
