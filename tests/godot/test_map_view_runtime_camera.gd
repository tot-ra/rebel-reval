extends "res://tests/godot/map_view_3d_test_base.gd"

## P0-143: practical-camera attributes attach only in perspective follow modes.
## R-1744: painted-iso preset, its cycle/zoom placement and the roof cutaway.


func test_perspective_modes_attach_practical_camera_attributes() -> void:
	var fixture := _install_runtime(KalevSmithyDefinition.create())
	var scene_root := fixture["scene_root"] as Node2D
	var runtime := fixture["runtime"] as MapViewRuntime
	var camera := runtime.view.view_camera()
	var controller := runtime._camera_controller as MapViewRuntimeCamera

	assert_true(runtime.is_third_person())
	_assert_perspective_attributes(camera, MapViewRuntimeCamera.CameraMode.THIRD_PERSON)

	runtime.set_first_person(true)
	_assert_perspective_attributes(camera, MapViewRuntimeCamera.CameraMode.FIRST_PERSON)

	runtime.set_camera_mode(MapViewRuntimeCamera.CameraMode.TOP_DOWN)
	assert_eq(camera.attributes, null, "top-down must clear camera attributes for full sharpness")
	assert_true(controller.perspective_camera_attributes() != null)

	runtime.set_camera_mode(MapViewRuntimeCamera.CameraMode.THIRD_PERSON)
	_assert_perspective_attributes(camera, MapViewRuntimeCamera.CameraMode.THIRD_PERSON)
	_free_map_scene(scene_root)


## R-1744: the painted-iso preset is a high telephoto perspective overview.
func test_painted_iso_preset_frames_telephoto_overview() -> void:
	var fixture := _install_runtime(KalevSmithyDefinition.create())
	var scene_root := fixture["scene_root"] as Node2D
	var runtime := fixture["runtime"] as MapViewRuntime
	var camera := runtime.view.view_camera()
	var controller := runtime._camera_controller as MapViewRuntimeCamera
	runtime.view.painted_iso_camera = true

	runtime.set_camera_mode(MapViewRuntimeCamera.CameraMode.PAINTED_ISO)
	assert_eq(camera.projection, Camera3D.PROJECTION_PERSPECTIVE, "iso keeps a true perspective")
	assert_true(is_equal_approx(camera.fov, MapViewRuntimeCamera.PAINTED_ISO_FOV_DEGREES))
	assert_true(camera.fov >= 25.0 and camera.fov <= 32.0, "telephoto lens band")
	assert_true(
		is_equal_approx(camera.rotation_degrees.x, MapViewRuntimeCamera.PAINTED_ISO_PITCH_DEGREES)
	)
	var target := (
		controller.player_rig.position
		+ Vector3.UP * MapViewRuntimeCamera.THIRD_PERSON_TARGET_HEIGHT
	)
	var boom := camera.position.distance_to(target)
	assert_true(
		absf(boom - MapViewRuntimeCamera.PAINTED_ISO_DISTANCE) < 0.01,
		"iso boom must sit %.1f m out, got %.2f" % [MapViewRuntimeCamera.PAINTED_ISO_DISTANCE, boom]
	)
	assert_true(runtime.is_overview(), "iso is an overview: the cursor aims, not the character")
	assert_false(runtime.is_top_down(), "iso must not report the orthographic mode")
	assert_false(controller.character_follows_camera())
	assert_eq(runtime.camera_mode_label(), "Painted iso view")
	if camera.attributes is CameraAttributesPractical:
		assert_false(
			(camera.attributes as CameraAttributesPractical).dof_blur_far_enabled,
			"far blur would soften Kalev 30-45 m from the lens"
		)

	controller.look_pitch_degrees(-40.0)
	assert_true(
		is_equal_approx(
			camera.rotation_degrees.x, MapViewRuntimeCamera.PAINTED_ISO_MIN_PITCH_DEGREES
		)
	)
	controller.look_pitch_degrees(40.0)
	assert_true(
		is_equal_approx(
			camera.rotation_degrees.x, MapViewRuntimeCamera.PAINTED_ISO_MAX_PITCH_DEGREES
		)
	)
	_free_map_scene(scene_root)


## R-1744: views that opt in put painted iso between third person and top-down
## in both the `C` cycle and the zoom continuum; other views keep the old chain.
func test_painted_iso_joins_cycle_and_zoom_only_where_offered() -> void:
	var fixture := _install_runtime(KalevSmithyDefinition.create())
	var scene_root := fixture["scene_root"] as Node2D
	var runtime := fixture["runtime"] as MapViewRuntime
	var camera := runtime.view.view_camera()

	runtime.set_first_person(true)
	runtime.toggle_camera_view()
	assert_true(runtime.is_top_down(), "without the view opt-in first person cycles to top-down")

	runtime.view.painted_iso_camera = true
	runtime.set_first_person(true)
	runtime.toggle_camera_view()
	assert_eq(runtime.camera_mode(), MapViewRuntimeCamera.CameraMode.PAINTED_ISO)
	runtime.toggle_camera_view()
	assert_true(runtime.is_top_down(), "iso cycles on to the orthographic overview")
	runtime.toggle_camera_view()
	assert_true(runtime.is_third_person())

	runtime.zoom_view_steps(-100.0)
	assert_eq(
		runtime.camera_mode(),
		MapViewRuntimeCamera.CameraMode.PAINTED_ISO,
		"zooming out past the farthest boom enters painted iso"
	)
	var controller := runtime._camera_controller as MapViewRuntimeCamera
	assert_true(
		is_equal_approx(
			controller.painted_iso_distance(), MapViewRuntimeCamera.PAINTED_ISO_MIN_DISTANCE
		)
	)
	runtime.zoom_view_steps(-1.0)
	assert_true(controller.painted_iso_distance() > MapViewRuntimeCamera.PAINTED_ISO_MIN_DISTANCE)
	runtime.zoom_view_steps(-100.0)
	assert_true(runtime.is_top_down(), "zooming out past 45 m enters the orthographic overview")
	runtime.zoom_view_steps(100.0)
	assert_eq(runtime.camera_mode(), MapViewRuntimeCamera.CameraMode.PAINTED_ISO)
	assert_true(
		is_equal_approx(
			controller.painted_iso_distance(), MapViewRuntimeCamera.PAINTED_ISO_MAX_DISTANCE
		),
		"zooming in from top-down resumes iso at the farthest boom"
	)
	runtime.zoom_view_steps(100.0)
	assert_true(runtime.is_third_person(), "zooming in past 30 m returns to third person")
	assert_eq(camera.projection, Camera3D.PROJECTION_PERSPECTIVE)
	_free_map_scene(scene_root)


## R-1744: the city roof materials receive the cutaway sight line while iso is on.
func test_roof_cutaway_reaches_city_roof_materials() -> void:
	var tile := CityBuildingBuilder.roof_material(&"tile") as ShaderMaterial
	var shingle := CityBuildingBuilder.roof_material(&"shingle") as ShaderMaterial
	var player := Vector3(10.0, 1.15, -4.0)
	var lens := Vector3(10.0, 30.0, 20.0)
	CityBuildingBuilder.set_roof_cutaway(true, player, lens)
	for mat: ShaderMaterial in [tile, shingle]:
		assert_true(bool(mat.get_shader_parameter("cutaway_on")))
		assert_eq(mat.get_shader_parameter("cutaway_player"), player)
		assert_eq(mat.get_shader_parameter("cutaway_camera"), lens)
	CityBuildingBuilder.set_roof_cutaway(false, Vector3.ZERO, Vector3.ZERO)
	for mat: ShaderMaterial in [tile, shingle]:
		assert_false(bool(mat.get_shader_parameter("cutaway_on")))


func _assert_perspective_attributes(
	camera: Camera3D, mode: MapViewRuntimeCamera.CameraMode
) -> void:
	assert_true(camera.attributes is CameraAttributesPractical)
	var attrs := camera.attributes as CameraAttributesPractical
	var rendering_method := str(
		ProjectSettings.get_setting("rendering/renderer/rendering_method", "")
	)
	var auto_exposure_supported := rendering_method == "forward_plus"
	var dof_supported := rendering_method in ["forward_plus", "mobile"]
	assert_eq(attrs.auto_exposure_enabled, auto_exposure_supported)
	if auto_exposure_supported:
		assert_true(
			is_equal_approx(
				attrs.auto_exposure_scale, MapViewRuntimeCamera.PERSPECTIVE_AUTO_EXPOSURE_SCALE
			)
		)
		assert_true(
			is_equal_approx(
				attrs.exposure_sensitivity, MapViewRuntimeCamera.PERSPECTIVE_EXPOSURE_SENSITIVITY
			)
		)
	assert_false(attrs.dof_blur_near_enabled, "near blur would soften the player in close follow")
	assert_eq(
		attrs.dof_blur_far_enabled,
		dof_supported,
		"DOF must only be enabled on renderers that support it"
	)
	if not dof_supported:
		return
	match mode:
		MapViewRuntimeCamera.CameraMode.THIRD_PERSON:
			assert_true(
				is_equal_approx(
					attrs.dof_blur_amount, MapViewRuntimeCamera.THIRD_PERSON_DOF_BLUR_AMOUNT
				)
			)
			assert_true(
				is_equal_approx(
					attrs.dof_blur_far_distance, MapViewRuntimeCamera.THIRD_PERSON_DOF_FAR_DISTANCE
				)
			)
		MapViewRuntimeCamera.CameraMode.FIRST_PERSON:
			assert_true(
				is_equal_approx(
					attrs.dof_blur_amount, MapViewRuntimeCamera.FIRST_PERSON_DOF_BLUR_AMOUNT
				)
			)
			assert_true(
				is_equal_approx(
					attrs.dof_blur_far_distance, MapViewRuntimeCamera.FIRST_PERSON_DOF_FAR_DISTANCE
				)
			)


func _install_runtime(definition: MapDefinition) -> Dictionary:
	var scene_root := Node2D.new()
	var map_root := Node2D.new()
	var actors := Node2D.new()
	var player := PLAYER_SCENE.instantiate() as Player
	scene_root.add_child(map_root)
	scene_root.add_child(actors)
	actors.add_child(player)
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
