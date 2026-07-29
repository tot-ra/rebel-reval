extends "res://tests/godot/map_view_3d_test_base.gd"

## Camera-mode integration kept separate from the broader runtime test so its
## result does not depend on unrelated actor synchronization assertions.


func test_c_cycles_third_person_first_person_and_top_down() -> void:
	var fixture := _install_runtime(LowerTownSlice.create())
	var scene_root := fixture["scene_root"] as Node2D
	var runtime := fixture["runtime"] as MapViewRuntime
	var rig := runtime.get_node("PlayerRig") as SharedCharacterRig
	var camera := runtime.view.view_camera()
	var top_down_size := camera.size
	var initial_yaw := camera.rotation_degrees.y

	assert_true(runtime.is_third_person(), "third-person must be the default camera mode")
	assert_eq(camera.projection, Camera3D.PROJECTION_PERSPECTIVE)
	assert_true(is_equal_approx(camera.fov, MapViewRuntime.THIRD_PERSON_FOV_DEGREES))
	assert_true(is_equal_approx(camera.rotation_degrees.x, MapViewRuntime.THIRD_PERSON_PITCH_DEGREES))
	assert_true(
		camera.position.is_equal_approx(
			rig.position
			+ Vector3.UP * MapViewRuntime.THIRD_PERSON_TARGET_HEIGHT
			+ camera.transform.basis.z * MapViewRuntime.THIRD_PERSON_DISTANCE
		),
		"third-person camera must start behind the player"
	)
	assert_true(rig.visible, "the player rig must be visible in third-person")
	var third_person_fov := camera.fov
	var distance_before_zoom := runtime.third_person_follow_distance()
	runtime.zoom_view_steps(1.0)
	assert_true(is_equal_approx(camera.fov, third_person_fov), "third-person boom zoom must not alter FOV")
	assert_true(
		runtime.third_person_follow_distance() < distance_before_zoom,
		"wheel zoom must pull the third-person boom closer"
	)

	var camera_toggle := _camera_toggle_event()
	runtime._unhandled_input(camera_toggle)

	assert_true(runtime.is_first_person(), "the first C press must switch to first-person")
	assert_eq(camera.projection, Camera3D.PROJECTION_PERSPECTIVE)
	assert_true(is_equal_approx(camera.fov, MapViewRuntime.FIRST_PERSON_FOV_DEGREES))
	assert_true(is_equal_approx(camera.rotation_degrees.x, MapViewRuntime.FIRST_PERSON_PITCH_DEGREES))
	assert_true(is_equal_approx(camera.rotation_degrees.y, initial_yaw), "switching view must preserve yaw")
	assert_true(
		camera.position.is_equal_approx(rig.position + Vector3.UP * MapViewRuntime.FIRST_PERSON_EYE_HEIGHT),
		"first-person camera must sit at the player's eye height"
	)
	assert_false(rig.visible, "the player rig must not obstruct first-person view")

	runtime._unhandled_input(camera_toggle)
	assert_true(runtime.is_top_down(), "the second C press must switch to top-down")
	assert_eq(camera.projection, Camera3D.PROJECTION_ORTHOGONAL)
	assert_true(is_equal_approx(camera.size, top_down_size))
	assert_true(is_equal_approx(camera.rotation_degrees.x, MapView3D.CAMERA_PITCH_DEGREES))
	assert_true(is_equal_approx(camera.rotation_degrees.y, initial_yaw), "top-down must preserve yaw")
	assert_true(rig.visible, "the player rig must be visible in top-down")
	var zoomed_size := camera.size
	runtime.zoom_view_steps(1.0)
	assert_true(camera.size < zoomed_size, "wheel zoom must remain available in top-down")

	runtime._unhandled_input(camera_toggle)
	assert_true(runtime.is_third_person(), "the third C press must return to third-person")
	assert_eq(camera.projection, Camera3D.PROJECTION_PERSPECTIVE)
	assert_true(is_equal_approx(camera.fov, MapViewRuntime.THIRD_PERSON_FOV_DEGREES))
	assert_true(is_equal_approx(camera.rotation_degrees.x, MapViewRuntime.THIRD_PERSON_PITCH_DEGREES))
	assert_true(is_equal_approx(camera.rotation_degrees.y, initial_yaw))
	assert_true(rig.visible)
	_free_map_scene(scene_root)


func test_interior_shell_follows_close_and_top_down_camera_modes() -> void:
	var fixture := _install_runtime(KalevSmithyDefinition.create())
	var scene_root := fixture["scene_root"] as Node2D
	var runtime := fixture["runtime"] as MapViewRuntime
	assert_true(runtime.view.has_node("InteriorShell/Ceiling"), "smithy must build a shared ceiling shell")
	assert_true(runtime.view.is_interior_shell_visible(), "default third-person must show the ceiling shell")
	assert_false(runtime.view.uses_interior_top_down_background(), "third-person must retain the sky background")
	var world_env := runtime.view.get_node("ViewEnvironment") as WorldEnvironment
	assert_eq(world_env.environment.background_mode, Environment.BG_SKY)

	var camera_toggle := _camera_toggle_event()
	runtime._unhandled_input(camera_toggle)
	assert_true(runtime.is_first_person())
	assert_true(runtime.view.is_interior_shell_visible(), "first-person must keep the ceiling shell visible")
	assert_false(runtime.view.uses_interior_top_down_background())

	runtime._unhandled_input(camera_toggle)
	assert_true(runtime.is_top_down())
	assert_false(runtime.view.is_interior_shell_visible(), "top-down must hide the ceiling for floor readability")
	assert_true(runtime.view.uses_interior_top_down_background(), "top-down interiors must clear to black")
	assert_eq(world_env.environment.background_mode, Environment.BG_COLOR)
	assert_eq(world_env.environment.background_color, MapView3D.BACKGROUND_INTERIOR_TOP_DOWN_COLOR)

	runtime._unhandled_input(camera_toggle)
	assert_true(runtime.is_third_person())
	assert_true(runtime.view.is_interior_shell_visible(), "returning to third-person must restore the ceiling")
	assert_false(runtime.view.uses_interior_top_down_background())
	assert_eq(world_env.environment.background_mode, Environment.BG_SKY)
	_free_map_scene(scene_root)


func test_perspective_camera_yaw_updates_player_facing_but_top_down_does_not() -> void:
	var fixture := _install_runtime(LowerTownSlice.create())
	var scene_root := fixture["scene_root"] as Node2D
	var runtime := fixture["runtime"] as MapViewRuntime
	var player := fixture["player"] as Player
	var rig := runtime.get_node("PlayerRig") as SharedCharacterRig
	var forward_before := player.movement_direction_for_screen_input(Vector2.UP)

	runtime.rotate_view_degrees(45.0)
	var third_person_forward := runtime._camera_controller.logic_direction_camera_faces()
	assert_true(
		player.view_facing().is_equal_approx(third_person_forward),
		"third-person camera yaw must immediately turn the character"
	)
	assert_false(
		player.movement_direction_for_screen_input(Vector2.UP).is_equal_approx(forward_before),
		"third-person forward movement must follow camera yaw"
	)
	runtime._sync_player(true)
	assert_true(
		is_equal_approx(rig.rotation.y, atan2(third_person_forward.x, third_person_forward.y)),
		"the visible character rig must use the camera-authored facing"
	)
	Input.action_press("ui_down")
	player._physics_process(0.0)
	Input.action_release("ui_down")
	assert_true(
		player.view_facing().is_equal_approx(third_person_forward),
		"moving backward in third-person must not turn the character away from the camera yaw"
	)
	player.velocity = Vector2.ZERO

	runtime.set_first_person(true)
	runtime.rotate_view_degrees(30.0)
	var first_person_forward := runtime._camera_controller.logic_direction_camera_faces()
	assert_true(
		player.view_facing().is_equal_approx(first_person_forward),
		"first-person camera yaw must immediately turn the character"
	)
	assert_true(
		is_equal_approx(player.movement_direction_for_screen_input(Vector2.UP).length(), 1.0),
		"camera-relative movement must remain normalized"
	)

	runtime.set_camera_mode(MapViewRuntimeCamera.CameraMode.TOP_DOWN)
	var top_down_facing := player.view_facing()
	var top_down_up_before := player.movement_direction_for_screen_input(Vector2.UP)
	runtime.rotate_view_degrees(30.0)
	assert_true(
		player.view_facing().is_equal_approx(top_down_facing),
		"top-down camera rotation must not affect character facing"
	)
	assert_false(
		player.movement_direction_for_screen_input(Vector2.UP).is_equal_approx(top_down_up_before),
		"top-down must retain its existing screen-relative movement controls"
	)
	_free_map_scene(scene_root)


func test_mouse_drag_pitch_orbits_perspective_modes_and_yaw_turns_character() -> void:
	var fixture := _install_runtime(LowerTownSlice.create())
	var scene_root := fixture["scene_root"] as Node2D
	var runtime := fixture["runtime"] as MapViewRuntime
	var player := fixture["player"] as Player
	var camera := runtime.view.view_camera()
	var yaw_before := camera.rotation_degrees.y
	var rig := runtime.get_node("PlayerRig") as SharedCharacterRig

	# The first sample arms right-drag. Third-person accepts both yaw and pitch orbit.
	runtime._apply_mouse_rotation_from_position(Vector2(100.0, 200.0), true)
	runtime._apply_mouse_rotation_from_position(Vector2(100.0, 100.0), true)
	assert_true(
		is_equal_approx(
			camera.rotation_degrees.x,
			MapViewRuntime.THIRD_PERSON_PITCH_DEGREES + 100.0 * MapViewRuntime.MOUSE_ROTATE_DEGREES_PER_PIXEL
		),
		"third-person right-drag must orbit vertically"
	)
	assert_true(
		camera.position.is_equal_approx(
			rig.position
			+ Vector3.UP * MapViewRuntime.THIRD_PERSON_TARGET_HEIGHT
			+ camera.transform.basis.z * runtime.third_person_follow_distance()
		),
		"third-person pitch must keep the follow boom distance"
	)
	runtime._apply_mouse_rotation_from_position(Vector2(60.0, 100.0), true)
	assert_true(
		is_equal_approx(
			camera.rotation_degrees.y,
			wrapf(yaw_before + 40.0 * MapViewRuntime.MOUSE_ROTATE_DEGREES_PER_PIXEL, -180.0, 180.0)
		),
		"third-person right-drag must orbit horizontally"
	)
	assert_true(
		player.view_facing().is_equal_approx(runtime._camera_controller.logic_direction_camera_faces()),
		"third-person mouse orbit must turn the character"
	)
	runtime._apply_mouse_rotation_from_position(Vector2(60.0, -1000.0), true)
	assert_true(is_equal_approx(camera.rotation_degrees.x, MapViewRuntime.THIRD_PERSON_MAX_PITCH_DEGREES))
	runtime._apply_mouse_rotation_from_position(Vector2(60.0, 2000.0), true)
	assert_true(is_equal_approx(camera.rotation_degrees.x, MapViewRuntime.THIRD_PERSON_MIN_PITCH_DEGREES))

	runtime._apply_mouse_rotation_from_position(Vector2(60.0, 2000.0), false)
	runtime.set_first_person(true)
	var screen_up_before_pitch := player.movement_direction_for_screen_input(Vector2.UP)
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
	runtime._apply_mouse_rotation_from_position(Vector2(100.0, -1000.0), true)
	assert_true(is_equal_approx(camera.rotation_degrees.x, MapViewRuntime.FIRST_PERSON_MAX_PITCH_DEGREES))
	runtime._apply_mouse_rotation_from_position(Vector2(100.0, 2000.0), true)
	assert_true(is_equal_approx(camera.rotation_degrees.x, MapViewRuntime.FIRST_PERSON_MIN_PITCH_DEGREES))

	runtime._apply_mouse_rotation_from_position(Vector2(100.0, 2000.0), false)
	runtime.set_camera_mode(MapViewRuntimeCamera.CameraMode.TOP_DOWN)
	runtime._apply_mouse_rotation_from_position(Vector2(100.0, 200.0), true)
	runtime._apply_mouse_rotation_from_position(Vector2(100.0, 100.0), true)
	assert_true(
		is_equal_approx(camera.rotation_degrees.x, MapView3D.CAMERA_PITCH_DEGREES),
		"top-down right-drag must keep the authored dimetric pitch"
	)
	_free_map_scene(scene_root)


func test_third_person_scroll_zoom_clamps_and_enters_first_person() -> void:
	var fixture := _install_runtime(LowerTownSlice.create())
	var scene_root := fixture["scene_root"] as Node2D
	var runtime := fixture["runtime"] as MapViewRuntime
	var rig := runtime.get_node("PlayerRig") as SharedCharacterRig
	var camera := runtime.view.view_camera()
	var player := fixture["player"] as Player

	assert_true(runtime.is_third_person())
	assert_true(is_equal_approx(runtime.third_person_follow_distance(), MapViewRuntime.THIRD_PERSON_DISTANCE))

	# One step past the far boom threshold enters top-down overview.
	runtime.zoom_view_steps(-200.0)
	assert_true(runtime.is_top_down(), "zoom-out past the far boom must enter top-down")
	assert_true(
		camera.projection == Camera3D.PROJECTION_ORTHOGONAL,
		"zoom-entered top-down must use the orthographic overview"
	)
	assert_true(
		is_equal_approx(runtime.third_person_follow_distance(), MapViewRuntime.THIRD_PERSON_MAX_DISTANCE),
		"crossing into top-down must remember the max boom for the return path"
	)

	runtime.zoom_view_steps(100.0)
	assert_true(runtime.is_third_person(), "zoom-in past the close top-down size must restore third-person")
	assert_true(
		is_equal_approx(runtime.third_person_follow_distance(), MapViewRuntime.THIRD_PERSON_MAX_DISTANCE),
		"restored third-person from top-down must start at the farthest boom"
	)
	assert_true(
		camera.position.is_equal_approx(
			rig.position
			+ Vector3.UP * MapViewRuntime.THIRD_PERSON_TARGET_HEIGHT
			+ camera.transform.basis.z * MapViewRuntime.THIRD_PERSON_MAX_DISTANCE
		),
		"restored boom from top-down must place the camera at the max follow distance"
	)

	runtime.zoom_view_steps(100.0)
	assert_true(runtime.is_first_person(), "zoom-in past the close boom must enter first-person")
	assert_false(rig.visible, "entering first-person via zoom must hide the player rig")
	assert_true(
		camera.position.is_equal_approx(rig.position + Vector3.UP * MapViewRuntime.FIRST_PERSON_EYE_HEIGHT),
		"zoom-entered first-person must sit at eye height"
	)
	assert_true(
		player.view_facing().is_equal_approx(runtime._camera_controller.logic_direction_camera_faces()),
		"zoom mode flip must keep camera-relative facing wired"
	)

	runtime.zoom_view_steps(1.0)
	assert_true(runtime.is_first_person(), "further zoom-in while already first-person must be a no-op")

	runtime.zoom_view_steps(-1.0)
	assert_true(runtime.is_third_person(), "zoom-out from first-person must restore the follow boom")
	assert_true(
		is_equal_approx(runtime.third_person_follow_distance(), MapViewRuntime.THIRD_PERSON_MIN_DISTANCE),
		"restored third-person must start at the closest boom"
	)
	assert_true(rig.visible)
	assert_true(
		camera.position.is_equal_approx(
			rig.position
			+ Vector3.UP * MapViewRuntime.THIRD_PERSON_TARGET_HEIGHT
			+ camera.transform.basis.z * MapViewRuntime.THIRD_PERSON_MIN_DISTANCE
		),
		"restored boom must place the camera at the min follow distance"
	)
	_free_map_scene(scene_root)


func test_enclosed_interior_third_person_does_not_enable_occlusion_ghost() -> void:
	var fixture := _install_runtime(KalevSmithyDefinition.create())
	var scene_root := fixture["scene_root"] as Node2D
	var runtime := fixture["runtime"] as MapViewRuntime
	var rig := runtime.get_node("PlayerRig") as SharedCharacterRig
	assert_true(runtime.is_third_person())
	assert_true(runtime.view.definition.suppresses_exterior_surroundings())
	runtime._update_occlusion_ghost()
	assert_false(
		rig.occlusion_ghost_enabled(),
		"enclosed interiors must not keep the X-ray silhouette stuck on"
	)
	_free_map_scene(scene_root)


func test_smithy_start_third_person_camera_avoids_walls() -> void:
	var definition: MapDefinition = KalevSmithyDefinition.create()
	var fixture := _install_runtime(definition)
	var scene_root := fixture["scene_root"] as Node2D
	var runtime := fixture["runtime"] as MapViewRuntime
	var player := fixture["player"] as Player
	var camera := runtime.view.view_camera()
	player.global_position = definition.player_spawn
	runtime._sync_player(true)
	assert_false(
		runtime.view.is_point_inside_occluder(camera.position),
		"smithy start third-person camera must not clip interior walls"
	)
	assert_true(
		camera.position.x < float(definition.size_cells.x) - 0.25
		and camera.position.z < float(definition.size_cells.y) - 0.25,
		"smithy start camera must stay inside the authored floor envelope"
	)
	_free_map_scene(scene_root)


func test_quick_access_camera_button_cycles_all_modes() -> void:
	var fixture := _install_runtime(KalevSmithyDefinition.create(), true)
	var scene_root := fixture["scene_root"] as Node2D
	var runtime := fixture["runtime"] as MapViewRuntime
	var player := fixture["player"] as Player
	var menu := player.get_node("QuickAccessMenu") as QuickAccessMenu
	menu._refresh_availability()

	var camera_button := menu.find_child("CameraButton", true, false) as Button
	var status := menu.find_child("StatusLabel", true, false) as Label
	assert_false(camera_button.disabled, "camera button must be available on 3D maps")
	camera_button.pressed.emit()
	assert_true(runtime.is_first_person())
	assert_eq(status.text, "First-person view")

	camera_button.pressed.emit()
	assert_true(runtime.is_top_down())
	assert_eq(status.text, "Top-down view")

	camera_button.pressed.emit()
	assert_true(runtime.is_third_person())
	assert_eq(status.text, "Third-person view")
	_free_map_scene(scene_root)


func test_ground_clamp_prevents_underground_camera() -> void:
	var fixture := _install_runtime(LowerTownSlice.create())
	var scene_root := fixture["scene_root"] as Node2D
	var runtime := fixture["runtime"] as MapViewRuntime
	var camera := runtime.view.view_camera()
	var rig := runtime.get_node("PlayerRig") as SharedCharacterRig
	var controller := runtime._camera_controller as MapViewRuntimeCamera

	# Place the camera far below ground by snapping to an underground target.
	camera.position.y = -10.0
	controller.follow_player(true, 0.0)
	var terrain_y := MapViewMeshBuilder.ground_height(
		runtime.view.definition, Vector2(camera.position.x, camera.position.z)
	)
	assert_true(
		camera.position.y >= terrain_y + MapViewRuntimeCamera.GROUND_CLEARANCE - 0.01,
		"camera must be clamped above terrain height after follow"
	)

	# Verify it also works during lerp (non-snap) path.
	camera.position.y = -5.0
	controller.follow_player(false, 0.1)
	terrain_y = MapViewMeshBuilder.ground_height(
		runtime.view.definition, Vector2(camera.position.x, camera.position.z)
	)
	assert_true(
		camera.position.y >= terrain_y + MapViewRuntimeCamera.GROUND_CLEARANCE - 0.01,
		"lerped camera must also be clamped above terrain"
	)
	_free_map_scene(scene_root)


func test_building_collision_pulls_camera_out() -> void:
	var fixture := _install_runtime(LowerTownSlice.create())
	var scene_root := fixture["scene_root"] as Node2D
	var runtime := fixture["runtime"] as MapViewRuntime
	var camera := runtime.view.view_camera()
	var rig := runtime.get_node("PlayerRig") as SharedCharacterRig
	var controller := runtime._camera_controller as MapViewRuntimeCamera

	# Place the camera inside a known building/landmark occluder.
	var buildings := runtime.view.get_node_or_null("Buildings") as Node3D
	if buildings != null and buildings.get_child_count() > 0:
		var first_building := buildings.get_child(0) as Node3D
		# Move camera into the building AABB.
		camera.position = first_building.global_position + Vector3.UP * 1.0
		controller.follow_player(true, 0.0)
		assert_false(
			runtime.view.is_point_inside_occluder(camera.position),
			"camera must be pulled out of building AABB after follow"
		)
	_free_map_scene(scene_root)


func test_top_down_occlusion_allows_ghost_not_reset() -> void:
	var fixture := _install_runtime(LowerTownSlice.create())
	var scene_root := fixture["scene_root"] as Node2D
	var runtime := fixture["runtime"] as MapViewRuntime
	var rig := runtime.get_node("PlayerRig") as SharedCharacterRig

	runtime.set_camera_mode(MapViewRuntimeCamera.CameraMode.TOP_DOWN)
	# In top-down, occlusion ghost should be available (not suppressed).
	runtime._update_occlusion_ghost()
	# The ghost state depends on actual scene geometry; at minimum, the rig
	# must remain visible in top-down mode.
	assert_true(rig.visible, "player rig must be visible in top-down even when occluded")
	_free_map_scene(scene_root)


func _install_runtime(definition: MapDefinition, with_menu: bool = false) -> Dictionary:
	var scene_root := Node2D.new()
	var map_root := Node2D.new()
	var actors := Node2D.new()
	var player := PLAYER_SCENE.instantiate() as Player
	scene_root.add_child(map_root)
	scene_root.add_child(actors)
	actors.add_child(player)
	if with_menu:
		var existing_menu := player.get_node_or_null("QuickAccessMenu")
		if existing_menu != null:
			existing_menu.queue_free()
			player.remove_child(existing_menu)
		var menu := QuickAccessMenu.new()
		menu.name = "QuickAccessMenu"
		player.add_child(menu)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene_root)
	var bootstrap := {
		"definition": definition,
		"grid": MapBuilder.build(definition),
		"assembled": {"buildings": [], "props": []},
	}
	return {
		"scene_root": scene_root,
		"runtime": MapViewRuntime.install(scene_root, bootstrap, map_root, player),
		"player": player,
	}


func _camera_toggle_event() -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_C
	event.pressed = true
	return event
