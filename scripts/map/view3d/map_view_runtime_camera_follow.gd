class_name MapViewRuntimeCameraFollow
extends RefCounted

## Snap/lerp follow and mode-specific boom targets for MapViewRuntimeCamera. Split
## out under P0-185 so mode, orbit, and zoom delegates stay under the soft cap.

const FOLLOW_LERP_WEIGHT := 8.0
const SNAP_DISTANCE_WORLD := 6.0

var _controller: MapViewRuntimeCamera


func configure(controller: MapViewRuntimeCamera) -> void:
	_controller = controller


func follow_player(snap: bool, delta: float) -> void:
	var controller := _controller
	var camera := controller.camera
	var view := controller.view
	var target := _follow_target()
	var camera_was_inside_occluder := view != null and view.is_point_inside_occluder(camera.position)
	var camera_and_player_shared_occluder := (
		camera_was_inside_occluder and controller._safety.camera_and_player_share_occluder()
	)
	var camera_was_below_ground := controller._safety.camera_is_below_ground()
	if snap or camera.position.distance_to(target) > SNAP_DISTANCE_WORLD:
		camera.position = controller._shake.apply(delta, target)
	else:
		var lerped := camera.position.lerp(
			target, clampf(FOLLOW_LERP_WEIGHT * delta, 0.0, 1.0)
		)
		camera.position = controller._shake.apply(delta, lerped)
	controller._safety.enforce_camera_safety(
		camera_was_inside_occluder, camera_and_player_shared_occluder, camera_was_below_ground
	)
	view.update_terrain_detail_focus(controller.player_rig.position)


func _follow_target() -> Vector3:
	var controller := _controller
	var camera := controller.camera
	match controller.camera_mode:
		MapViewRuntimeCamera.CameraMode.FIRST_PERSON:
			return (
				controller.player_rig.position
				+ Vector3.UP * MapViewRuntimeCamera.FIRST_PERSON_EYE_HEIGHT
			)
		MapViewRuntimeCamera.CameraMode.THIRD_PERSON:
			return controller._target.resolve_third_person_target(
				(
					controller.player_rig.position
					+ Vector3.UP * MapViewRuntimeCamera.THIRD_PERSON_TARGET_HEIGHT
					+ camera.transform.basis.z * controller._zoom.third_person_distance()
				)
			)
		_:
			return (
				controller.player_rig.position
				+ camera.transform.basis.z * MapView3D.CAMERA_DISTANCE
			)
