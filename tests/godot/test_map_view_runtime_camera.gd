extends "res://tests/godot/map_view_3d_test_base.gd"

## P0-143: practical-camera attributes attach only in perspective follow modes.


func test_perspective_modes_attach_practical_camera_attributes() -> void:
	var fixture := _install_runtime(LowerTownSlice.create())
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


func _assert_perspective_attributes(camera: Camera3D, mode: MapViewRuntimeCamera.CameraMode) -> void:
	assert_true(camera.attributes is CameraAttributesPractical)
	var attrs := camera.attributes as CameraAttributesPractical
	assert_true(attrs.auto_exposure_enabled)
	assert_true(
		is_equal_approx(attrs.auto_exposure_scale, MapViewRuntimeCamera.PERSPECTIVE_AUTO_EXPOSURE_SCALE)
	)
	assert_true(
		is_equal_approx(attrs.exposure_sensitivity, MapViewRuntimeCamera.PERSPECTIVE_EXPOSURE_SENSITIVITY)
	)
	assert_false(attrs.dof_blur_near_enabled, "near blur would soften the player in close follow")
	assert_true(attrs.dof_blur_far_enabled)
	match mode:
		MapViewRuntimeCamera.CameraMode.THIRD_PERSON:
			assert_true(
				is_equal_approx(attrs.dof_blur_amount, MapViewRuntimeCamera.THIRD_PERSON_DOF_BLUR_AMOUNT)
			)
			assert_true(
				is_equal_approx(attrs.dof_blur_far_distance, MapViewRuntimeCamera.THIRD_PERSON_DOF_FAR_DISTANCE)
			)
		MapViewRuntimeCamera.CameraMode.FIRST_PERSON:
			assert_true(
				is_equal_approx(attrs.dof_blur_amount, MapViewRuntimeCamera.FIRST_PERSON_DOF_BLUR_AMOUNT)
			)
			assert_true(
				is_equal_approx(attrs.dof_blur_far_distance, MapViewRuntimeCamera.FIRST_PERSON_DOF_FAR_DISTANCE)
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
