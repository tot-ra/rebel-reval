extends "res://tests/godot/map_view_3d_test_base.gd"

## MapViewRuntime integration: flat-art hiding, camera orbit, and input projection.


func test_runtime_hides_flat_map_visuals_without_disabling_collision() -> void:
	var terrain := Node2D.new()
	var building := StaticBody2D.new()
	var visuals := Node2D.new()
	visuals.name = "Visuals"
	building.add_child(visuals)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(32.0, 32.0)
	collision.shape = shape
	building.add_child(collision)
	var prop := Node2D.new()
	var bootstrap := {
		"assembled": {
			"terrain": terrain,
			"buildings": [building],
			"props": [prop],
		},
	}

	MapViewRuntime._hide_flat_map_visuals(bootstrap)

	assert_false(terrain.visible, "flat terrain must not overlay the 3D view")
	assert_true(building.visible, "building collision host must stay active")
	assert_false(visuals.visible, "flat building art must not overlay the 3D view")
	assert_false(prop.visible, "flat prop art must not overlay the 3D view")
	assert_false(collision.disabled, "hiding flat art must preserve logic-plane collision")
	terrain.free()
	building.free()
	prop.free()


func test_runtime_maps_keyboard_to_screen_axes_and_preserves_facing_on_stop() -> void:
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
	var screen_up_in_logic := player.movement_direction_for_screen_input(Vector2.UP)
	assert_true(
		screen_up_in_logic.is_equal_approx(Vector2(-1.0, -1.0).normalized()),
		"the fixed camera must project Up to the screen's top edge"
	)

	var rig := runtime.get_node("PlayerRig") as SharedCharacterRig
	runtime._sync_player(true)
	var expected_spawn := player.view_facing()
	assert_true(
		is_equal_approx(rig.rotation.y, atan2(expected_spawn.x, expected_spawn.y)),
		"an idle player rig with no movement history must follow the player's authored facing"
	)

	var move_direction := Vector2(1.0, 0.0)
	player.velocity = move_direction * (MapViewRuntime.WALK_ANIMATION_MIN_SPEED + 1.0)
	player._facing_direction = move_direction
	runtime._sync_player(false, 0.016)
	player.velocity = Vector2.ZERO
	runtime.rotate_view_degrees(45.0)
	runtime._sync_player(false, 0.016)
	assert_true(
		is_equal_approx(rig.rotation.y, atan2(move_direction.x, move_direction.y)),
		"an idle player rig must keep the last movement direction after stopping"
	)

	var yaw_before := camera.rotation_degrees.y
	runtime.rotate_view_degrees(30.0)
	assert_true(
		is_equal_approx(camera.rotation_degrees.y, wrapf(yaw_before + 30.0, -180.0, 180.0)),
		"rotate_view_degrees must orbit the camera by the requested angle"
	)
	var rotated_up := player.movement_direction_for_screen_input(Vector2.UP)
	assert_false(
		rotated_up.is_equal_approx(screen_up_in_logic),
		"rotating the view must re-project keyboard movement"
	)
	assert_true(
		is_equal_approx(rotated_up.length(), 1.0),
		"re-projected movement must stay normalized"
	)

	var yaw_before_drag := camera.rotation_degrees.y
	runtime._apply_mouse_rotation_from_position(Vector2(100.0, 200.0), true)
	runtime._apply_mouse_rotation_from_position(Vector2(0.0, 200.0), true)
	assert_true(
		is_equal_approx(
			camera.rotation_degrees.y,
			wrapf(yaw_before_drag + 100.0 * MapViewRuntime.MOUSE_ROTATE_DEGREES_PER_PIXEL, -180.0, 180.0)
		),
		"right-click drag must orbit the camera horizontally"
	)
	runtime._apply_mouse_rotation_from_position(Vector2(0.0, 200.0), false)
	scene_root.free()


func test_runtime_accepts_mouse_wheel_and_trackpad_zoom_input() -> void:
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
	var default_camera_size := camera.size

	var wheel_up := InputEventMouseButton.new()
	wheel_up.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_up.pressed = false
	wheel_up.factor = 1.0
	runtime._unhandled_input(wheel_up)
	assert_true(camera.size < default_camera_size, "mouse wheel up must zoom toward the player")

	var wheel_down := InputEventMouseButton.new()
	wheel_down.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel_down.pressed = false
	wheel_down.factor = 1.0
	runtime._unhandled_input(wheel_down)
	assert_true(
		is_equal_approx(camera.size, default_camera_size),
		"opposite wheel steps must restore the previous zoom level"
	)

	var magnify_in := InputEventMagnifyGesture.new()
	magnify_in.factor = 1.1
	runtime._unhandled_input(magnify_in)
	assert_true(
		camera.size < default_camera_size,
		"trackpad pinch spread must zoom toward the player"
	)

	var magnify_out := InputEventMagnifyGesture.new()
	magnify_out.factor = 1.0 / 1.1
	runtime._unhandled_input(magnify_out)
	assert_true(
		is_equal_approx(camera.size, default_camera_size),
		"opposite pinch steps must restore the previous zoom level"
	)

	var pan_up := InputEventPanGesture.new()
	pan_up.delta = Vector2(0.0, -1.0)
	runtime._unhandled_input(pan_up)
	assert_true(
		camera.size < default_camera_size,
		"trackpad two-finger scroll up must zoom toward the player"
	)

	var pan_down := InputEventPanGesture.new()
	pan_down.delta = Vector2(0.0, 1.0)
	runtime._unhandled_input(pan_down)
	assert_true(
		is_equal_approx(camera.size, default_camera_size),
		"opposite trackpad scroll must restore the previous zoom level"
	)

	runtime.zoom_view_steps(100.0)
	assert_true(
		is_equal_approx(camera.size, MapViewRuntime.ZOOM_MIN_ORTHOGRAPHIC_SIZE),
		"zooming in must stop at the close-up limit"
	)
	runtime.zoom_view_steps(-200.0)
	assert_true(
		is_equal_approx(camera.size, MapViewRuntime.ZOOM_MAX_ORTHOGRAPHIC_SIZE),
		"zooming out must stop at the overview limit"
	)
	scene_root.free()
