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
	var camera_was_inside_occluder := (
		view != null
		and view.is_point_inside_occluder(
			MapViewRuntimeCameraSafety._in_view(view, camera.position)
		)
	)
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


## ADR 0021: the swimmer presenter lowers the rig into the water, so the anchor that is
## normally feet + eye height would put the lens at or under the surface. It publishes
## the lift that keeps the camera above the swell while Kalev floats; the lift fades to
## zero once his head goes under so a dive carries the camera below the surface too.
## Components: third person, first person, top down.
func _swim_lift() -> Vector3:
	var rig := _controller.player_rig
	if rig == null or not rig.has_meta(&"camera_lift"):
		return Vector3.ZERO
	return rig.get_meta(&"camera_lift") as Vector3


## Share of the third-person boom kept while diving (MapViewSwimmerPresenter), 1 otherwise.
func _swim_boom_scale() -> float:
	var rig := _controller.player_rig
	if rig == null or not rig.has_meta(&"camera_boom_scale"):
		return 1.0
	return float(rig.get_meta(&"camera_boom_scale"))


func _follow_target() -> Vector3:
	var controller := _controller
	var camera := controller.camera
	var lift := _swim_lift()
	match controller.camera_mode:
		MapViewRuntimeCamera.CameraMode.FIRST_PERSON:
			return (
				controller.player_rig.position
				+ Vector3.UP * (MapViewRuntimeCamera.FIRST_PERSON_EYE_HEIGHT + lift.y)
			)
		MapViewRuntimeCamera.CameraMode.THIRD_PERSON:
			return controller._target.resolve_third_person_target(
				(
					controller.player_rig.position
					+ Vector3.UP * (MapViewRuntimeCamera.THIRD_PERSON_TARGET_HEIGHT + lift.x)
					+ camera.transform.basis.z
					* (controller._zoom.third_person_distance() * _swim_boom_scale())
				)
			)
		_:
			return (
				controller.player_rig.position
				+ Vector3.UP * lift.z
				+ camera.transform.basis.z * MapView3D.CAMERA_DISTANCE
			)
