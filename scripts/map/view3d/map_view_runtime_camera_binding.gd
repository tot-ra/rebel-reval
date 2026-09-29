class_name MapViewRuntimeCameraBinding
extends RefCounted

## Runtime-side camera presentation binding. MapViewRuntimeCamera owns orbit,
## zoom, modes, and safety. This helper is the independently changing seam that
## keeps player screen-relative locomotion and the occlusion ghost in sync after
## those camera changes, so the facade does not duplicate that pairing.

var _host: MapViewRuntime


func configure(runtime_host: MapViewRuntime) -> void:
	_host = runtime_host


func logic_position_at_screen(screen_position: Vector2) -> Vector2:
	var origin := _host._camera.project_ray_origin(screen_position)
	var direction := _host._camera.project_ray_normal(screen_position)
	if is_zero_approx(direction.y):
		return MapViewBridge.world_to_logic(origin, _host._definition.cell_size)
	var distance := -origin.y / direction.y
	return MapViewBridge.world_to_logic(
		origin + direction * distance, _host._definition.cell_size
	)


func toggle_camera_view() -> void:
	_host._camera_controller.cycle_camera_mode()
	sync_movement_and_ghost()


func set_camera_mode(next_mode: MapViewRuntimeCamera.CameraMode) -> void:
	_host._camera_controller.set_camera_mode(next_mode)
	sync_movement_and_ghost()


func camera_mode() -> MapViewRuntimeCamera.CameraMode:
	return _host._camera_controller.camera_mode


func camera_mode_label() -> String:
	return _host._camera_controller.mode_label()


func set_first_person(enabled: bool) -> void:
	_host._camera_controller.set_first_person(enabled)
	sync_movement_and_ghost()


func is_first_person() -> bool:
	return _host._camera_controller.first_person


func is_third_person() -> bool:
	return (
		_host._camera_controller.camera_mode == MapViewRuntimeCamera.CameraMode.THIRD_PERSON
	)


func is_top_down() -> bool:
	return _host._camera_controller.camera_mode == MapViewRuntimeCamera.CameraMode.TOP_DOWN


func zoom_view_steps(steps: float) -> void:
	var mode_before: MapViewRuntimeCamera.CameraMode = _host._camera_controller.camera_mode
	_host._camera_controller.zoom_view_steps(steps)
	sync_if_mode_changed(mode_before)


func zoom_from_magnify_factor(factor: float) -> void:
	var mode_before: MapViewRuntimeCamera.CameraMode = _host._camera_controller.camera_mode
	_host._camera_controller.zoom_from_magnify_factor(factor)
	sync_if_mode_changed(mode_before)


func zoom_from_pan_delta(delta: Vector2) -> void:
	var mode_before: MapViewRuntimeCamera.CameraMode = _host._camera_controller.camera_mode
	_host._camera_controller.zoom_from_pan_delta(delta)
	sync_if_mode_changed(mode_before)


func third_person_follow_distance() -> float:
	return _host._camera_controller.third_person_follow_distance()


func apply_view_rotation(delta: float) -> void:
	var yaw_before := _host._camera.rotation_degrees.y
	_host._camera_controller.apply_view_rotation(delta)
	# Perspective modes keep movement and authored facing tied to camera yaw;
	# top-down only re-projects screen-relative movement after an actual orbit.
	if (
		_host._camera_controller.character_follows_camera()
		or not is_equal_approx(_host._camera.rotation_degrees.y, yaw_before)
	):
		configure_screen_relative_movement()


func apply_mouse_rotation_from_position(mouse_position: Vector2, button_pressed: bool) -> void:
	_host._camera_controller.apply_mouse_rotation_from_position(
		mouse_position, button_pressed
	)
	if button_pressed:
		configure_screen_relative_movement()


func is_camera_drag_active() -> bool:
	return _host._camera_controller.drag_rotating_view


func rotate_view_degrees(delta_degrees: float) -> void:
	_host._camera_controller.rotate_view_degrees(delta_degrees)
	configure_screen_relative_movement()


func update_occlusion_ghost() -> void:
	_host._camera_controller.update_occlusion_ghost()


func configure_screen_relative_movement() -> void:
	if not _host._player.has_method("set_screen_movement_basis"):
		return
	var viewport_size := _host._camera.get_viewport().get_visible_rect().size
	var center := viewport_size * 0.5
	var sample_px := MapViewRuntime.INPUT_PROJECTION_SAMPLE_PX
	var center_logic := logic_position_at_screen(center)
	var logic_right := (
		logic_position_at_screen(center + Vector2(sample_px, 0.0)) - center_logic
	)
	var logic_down := (
		logic_position_at_screen(center + Vector2(0.0, sample_px)) - center_logic
	)
	_host._player.call("set_screen_movement_basis", logic_right, logic_down)


func sync_movement_and_ghost() -> void:
	configure_screen_relative_movement()
	update_occlusion_ghost()


func sync_if_mode_changed(mode_before: MapViewRuntimeCamera.CameraMode) -> void:
	# Scroll can cross first-person <-> third-person <-> top-down; keep
	# movement/ghost in sync.
	if _host._camera_controller.camera_mode != mode_before:
		sync_movement_and_ghost()
