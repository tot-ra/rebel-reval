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


func test_runtime_restores_shared_cycle_from_music_director() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	MusicDirector.set_cycle_progress(0.77)
	MusicDirector.set_cycle_elapsed_days(2)
	var runtime := MapViewRuntime.new()
	tree.root.add_child(runtime)
	runtime._restore_cycle_from_music_director()
	assert_true(
		is_equal_approx(runtime.cycle_progress, 0.77),
		"new districts must continue the shared sky clock"
	)
	assert_eq(runtime.cycle_elapsed_days, 2, "new districts must keep completed calendar days")
	runtime.free()
	MusicDirector.clear_cycle_progress()
	var idle := MapViewRuntime.new()
	tree.root.add_child(idle)
	idle._restore_cycle_from_music_director()
	assert_true(
		is_equal_approx(idle.cycle_progress, DayNightCycle.DEFAULT_PROGRESS),
		"inactive MusicDirector must leave the runtime at its default morning"
	)
	idle.free()


func test_runtime_midnight_advances_view_date_and_lunar_phase() -> void:
	var definition := SmithyCourtyard.create()
	var runtime := MapViewRuntime.new()
	runtime.view = MapView3D.create(definition, MapBuilder.build(definition), MapView3D.TIME_NIGHT)
	runtime.add_child(runtime.view)
	runtime.cycle_progress = 23.5 / 24.0
	runtime.view.set_calendar_date(runtime._current_calendar_date())
	var previous_phase := SkyWeather3D.lunar_phase(runtime.view.sky_weather().calendar_date)

	runtime._process(2.0)

	assert_eq(runtime.cycle_elapsed_days, 1, "crossing midnight must count a completed solar day")
	assert_eq(
		runtime.view.sky_weather().calendar_date,
		{"day": 22, "month": 4, "year": 1343},
		"the rendered sky must receive the next campaign date at midnight"
	)
	var phase_step := fposmod(
		SkyWeather3D.lunar_phase(runtime.view.sky_weather().calendar_date) - previous_phase,
		1.0
	)
	assert_true(phase_step > 0.03 and phase_step < 0.04, "the visible moon phase must advance with the date")
	assert_true(
		is_equal_approx(runtime.cycle_progress, 0.3 / 24.0),
		"the sun clock must continue after midnight without losing elapsed time"
	)
	runtime.free()
	MusicDirector.clear_cycle_progress()


func test_time_speed_ladder_steps_up_and_down_and_clamps() -> void:
	var runtime := MapViewRuntime.new()
	assert_true(is_equal_approx(runtime.effective_time_speed(), 1.0), "time must default to real-time pacing")
	runtime.time_speed_up()
	assert_true(is_equal_approx(runtime.time_speed, 2.0), "speeding up must step one rung faster")
	runtime.time_speed_down()
	runtime.time_speed_down()
	assert_true(is_equal_approx(runtime.time_speed, 0.5), "slowing down must step below real-time")
	# The ladder must clamp at both ends instead of running off.
	for step in 20:
		runtime.time_speed_up()
	assert_true(is_equal_approx(runtime.time_speed, MapViewRuntime.TIME_SPEED_LADDER[-1]), "fastest speed must clamp")
	for step in 20:
		runtime.time_speed_down()
	assert_true(is_equal_approx(runtime.time_speed, MapViewRuntime.TIME_SPEED_LADDER[0]), "slowest speed must clamp")
	runtime.free()


func test_pause_freezes_flow_but_keeps_the_chosen_speed() -> void:
	var runtime := MapViewRuntime.new()
	runtime.time_speed_up()
	runtime.time_speed_up()
	assert_true(is_equal_approx(runtime.time_speed, 4.0), "precondition: a fast speed is chosen")
	runtime.toggle_time_pause()
	assert_true(runtime.time_paused, "pausing must set the paused flag")
	assert_true(is_equal_approx(runtime.effective_time_speed(), 0.0), "a paused clock must not advance")
	assert_true(is_equal_approx(runtime.time_speed, 4.0), "pausing must not discard the chosen speed")
	runtime.toggle_time_pause()
	assert_false(runtime.time_paused, "toggling again must resume")
	assert_true(is_equal_approx(runtime.effective_time_speed(), 4.0), "resuming must restore the chosen speed")
	runtime.free()


func test_speeding_up_while_paused_resumes_and_reset_returns_to_realtime() -> void:
	var runtime := MapViewRuntime.new()
	runtime.set_time_paused(true)
	runtime.time_speed_up()
	assert_false(runtime.time_paused, "nudging the speed must resume a paused clock so the key always does something")
	runtime.set_time_speed(8.0)
	runtime.set_time_paused(true)
	runtime.reset_time_flow()
	assert_false(runtime.time_paused, "reset must unpause")
	assert_true(is_equal_approx(runtime.effective_time_speed(), 1.0), "reset must return to real-time pacing")
	runtime.free()


func test_pausing_holds_the_sun_and_sky_still() -> void:
	var definition := SmithyCourtyard.create()
	var tree := Engine.get_main_loop() as SceneTree
	var runtime := MapViewRuntime.new()
	tree.root.add_child(runtime)
	runtime.view = MapView3D.create(definition, MapBuilder.build(definition), MapView3D.TIME_DAY)
	runtime.add_child(runtime.view)
	runtime.set_time_paused(true)
	var frozen_progress := runtime.cycle_progress
	for step in 30:
		runtime._process(1.0)
	assert_true(
		is_equal_approx(runtime.cycle_progress, frozen_progress),
		"a paused clock must hold the sun still no matter how many frames pass"
	)
	assert_true(
		is_equal_approx(runtime.view.sky_weather().time_scale, 0.0),
		"pausing must also freeze the sky's clouds, weather, and lightning"
	)
	runtime.free()
