class_name MapViewRuntimeCameraFollow
extends RefCounted

## Snap/lerp follow and mode-specific boom targets for MapViewRuntimeCamera. Split
## out under P0-185 so mode, orbit, and zoom delegates stay under the soft cap.

const FOLLOW_LERP_WEIGHT := 8.0
const SNAP_DISTANCE_WORLD := 6.0
## The painted-iso boom glides a little slower than the close follow so the far
## telephoto frame drifts after Kalev instead of jittering with each step.
const PAINTED_ISO_FOLLOW_LERP_WEIGHT := 5.0

## Safety pushes (ground, walls, line of sight) ease out at this rate once the
## obstruction clears, so the lens glides back instead of popping.
const SAFETY_RELAX_WEIGHT := 5.0

var _controller: MapViewRuntimeCamera
## Unconstrained boom position the lerp runs on. Lerping from the safety-corrected
## position made the camera fight its own correction every frame (pushed out by a
## wall or the ground, pulled back in by the lerp toward a target inside it), which
## shook the whole frame.
var _free_position := Vector3.ZERO
var _last_output := Vector3.ZERO
var _has_state := false


func configure(controller: MapViewRuntimeCamera) -> void:
	_controller = controller


func follow_player(snap: bool, delta: float) -> void:
	var controller := _controller
	var camera := controller.camera
	var view := controller.view
	var target := _follow_target()
	# Something else (orbit, mode switch, teleport) moved the camera: adopt that
	# position as the new unconstrained one instead of fighting it.
	if not _has_state or not camera.position.is_equal_approx(_last_output):
		_free_position = camera.position
	_has_state = true
	camera.position = _free_position
	if snap or camera.position.distance_to(target) > SNAP_DISTANCE_WORLD:
		camera.position = controller._shake.apply(delta, target)
	else:
		var weight := (
			PAINTED_ISO_FOLLOW_LERP_WEIGHT
			if controller.camera_mode == MapViewRuntimeCamera.CameraMode.PAINTED_ISO
			else FOLLOW_LERP_WEIGHT
		)
		var lerped := camera.position.lerp(target, clampf(weight * delta, 0.0, 1.0))
		camera.position = controller._shake.apply(delta, lerped)
	_free_position = camera.position
	# Judge wall and ground contact on this frame's unconstrained boom. Judging it on
	# last frame's corrected output flip-flopped: a pushed-out lens read as clear, so
	# the next frame skipped the push and the lerp sank it back into the wall or slope.
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
	controller._safety.enforce_camera_safety(
		camera_was_inside_occluder, camera_and_player_shared_occluder, camera_was_below_ground
	)
	# Pushes toward the player apply at once; a shrinking push eases out. The ground
	# clamp is re-applied so easing never dips the lens under the terrain.
	var safe_position := camera.position
	var relaxed := safe_position
	if _has_state and delta > 0.0:
		var previous_push := _last_output - _free_position
		var new_push := safe_position - _free_position
		if new_push.length_squared() < previous_push.length_squared():
			relaxed = _free_position + previous_push.lerp(
				new_push, clampf(SAFETY_RELAX_WEIGHT * delta, 0.0, 1.0)
			)
	camera.position = relaxed
	controller._safety.clamp_to_ground()
	_last_output = camera.position
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
		MapViewRuntimeCamera.CameraMode.PAINTED_ISO:
			# No wall pull-in: the roof cutaway and the occlusion ghost keep Kalev
			# readable, so the telephoto frame never lurches toward him.
			return (
				controller.player_rig.position
				+ Vector3.UP * (MapViewRuntimeCamera.THIRD_PERSON_TARGET_HEIGHT + lift.z)
				+ camera.transform.basis.z * controller._zoom.painted_iso_distance()
			)
		_:
			return (
				controller.player_rig.position
				+ Vector3.UP * lift.z
				+ camera.transform.basis.z * MapView3D.CAMERA_DISTANCE
			)
