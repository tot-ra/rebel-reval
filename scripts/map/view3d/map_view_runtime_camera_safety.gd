class_name MapViewRuntimeCameraSafety
extends RefCounted

## Post-follow collision, ground clamp, line-of-sight recovery, and occlusion
## ghost for MapViewRuntimeCamera. Split out under P0-185 so the mode/zoom owner
## stays under the architecture soft cap.

const GROUND_CLEARANCE := 0.3
const BUILDING_PULL_ITERATIONS := 4
const BUILDING_PULL_STEP := 0.6
const VISIBILITY_PULL_STEP := 0.6
const VISIBILITY_PULL_ITERATIONS := 4
## Relief line of sight aims at the player's chest (the middle occlusion probe)
## and treats a sample closer than the clearance to the ground as blocked.
const TERRAIN_SIGHT_HEIGHT := 1.1
const TERRAIN_SIGHT_STEP := 0.5
const TERRAIN_SIGHT_CLEARANCE := 0.05

var _controller: MapViewRuntimeCamera


func configure(controller: MapViewRuntimeCamera) -> void:
	_controller = controller


func player_inside_occluder() -> bool:
	var view := _controller.view
	var player_rig := _controller.player_rig
	return (
		view != null
		and player_rig != null
		and view.is_point_inside_occluder(_in_view(view, player_rig.position))
	)


func camera_and_player_share_occluder() -> bool:
	var view := _controller.view
	var player_rig := _controller.player_rig
	var camera := _controller.camera
	if view == null or player_rig == null:
		return false
	var camera_local := _in_view(view, camera.position)
	var player_local := _in_view(view, player_rig.position)
	for bounds in view._occluder_bounds:
		if bounds.has_point(camera_local) and bounds.has_point(player_local):
			return true
	return false


func camera_is_below_ground() -> bool:
	var view := _controller.view
	var camera := _controller.camera
	if view == null or view.definition == null:
		return false
	var terrain_y := MapViewMeshBuilder.ground_height(
		view.definition, _view_local_xz(view, Vector2(camera.position.x, camera.position.z))
	)
	return camera.position.y < terrain_y


func enforce_camera_safety(
	camera_was_inside_occluder: bool,
	camera_and_player_shared_occluder: bool,
	camera_was_below_ground: bool
) -> void:
	_clamp_above_ground(camera_was_below_ground)
	_pull_out_of_buildings(camera_was_inside_occluder and not camera_and_player_shared_occluder)
	_ensure_player_visible()


func update_occlusion_ghost() -> void:
	var controller := _controller
	var camera := controller.camera
	var view := controller.view
	var player_rig := controller.player_rig
	if (
		controller.first_person
		or (
			view != null
			and view.definition != null
			and view.definition.suppresses_exterior_surroundings()
		)
	):
		player_rig.set_occlusion_ghost(false)
		return
	var to_camera := _in_view(view, camera.position)
	var occluded := false
	for height in MapViewRuntimeCamera.OCCLUSION_PROBE_HEIGHTS:
		var from := _in_view(view, player_rig.position + Vector3.UP * height)
		if view.is_segment_occluded(from, to_camera):
			occluded = true
			break
	player_rig.set_occlusion_ghost(occluded)


func _clamp_above_ground(camera_was_below_ground: bool) -> void:
	var view := _controller.view
	var camera := _controller.camera
	if view == null or view.definition == null:
		return
	if (
		_controller.camera_mode == MapViewRuntimeCamera.CameraMode.THIRD_PERSON
		and not camera_was_below_ground
	):
		return
	var world_xz := _view_local_xz(view, Vector2(camera.position.x, camera.position.z))
	var terrain_y := MapViewMeshBuilder.ground_height(view.definition, world_xz)
	var min_y := terrain_y + GROUND_CLEARANCE
	if camera.position.y < min_y:
		camera.position.y = min_y


func _pull_out_of_buildings(camera_was_inside_occluder: bool) -> void:
	var view := _controller.view
	var camera := _controller.camera
	if view == null or not camera_was_inside_occluder:
		return
	if _controller.camera_mode == MapViewRuntimeCamera.CameraMode.FIRST_PERSON:
		return
	for _pass in range(BUILDING_PULL_ITERATIONS):
		if not view.is_point_inside_occluder(_in_view(view, camera.position)):
			return
		var local_camera := _in_view(view, camera.position)
		var candidate := _best_occluder_exit(local_camera)
		if candidate.is_equal_approx(local_camera):
			return
		camera.position = _from_view(view, candidate)


func _best_occluder_exit(point: Vector3) -> Vector3:
	var view := _controller.view
	var best := point
	var best_count := view._occluder_bounds.size() + 1
	var best_distance := 1.0e20
	for bounds: AABB in view._occluder_bounds:
		if not bounds.has_point(point):
			continue
		var candidates: Array[Vector3] = [
			Vector3(bounds.position.x - 0.01, point.y, point.z),
			Vector3(bounds.end.x + 0.01, point.y, point.z),
			Vector3(point.x, bounds.position.y - 0.01, point.z),
			Vector3(point.x, bounds.end.y + 0.01, point.z),
			Vector3(point.x, point.y, bounds.position.z - 0.01),
			Vector3(point.x, point.y, bounds.end.z + 0.01),
		]
		for candidate: Vector3 in candidates:
			var containing_count := 0
			for other_bounds: AABB in view._occluder_bounds:
				if other_bounds.has_point(candidate):
					containing_count += 1
			var distance := point.distance_squared_to(candidate)
			if (
				containing_count < best_count
				or (containing_count == best_count and distance < best_distance)
			):
				best = candidate
				best_count = containing_count
				best_distance = distance
	return best


func _ensure_player_visible() -> void:
	var controller := _controller
	var view := controller.view
	var camera := controller.camera
	var player_rig := controller.player_rig
	if view == null:
		return
	if player_inside_occluder():
		return
	if view.definition != null and view.definition.suppresses_exterior_surroundings():
		return
	var player_pos := player_rig.position
	if not _line_of_sight_blocked(camera.position, player_pos):
		return
	if controller.camera_mode == MapViewRuntimeCamera.CameraMode.TOP_DOWN:
		return
	var dir := camera.position - player_pos
	var distance := dir.length()
	if distance < 0.1:
		return
	dir /= distance
	for i in range(VISIBILITY_PULL_ITERATIONS):
		distance *= VISIBILITY_PULL_STEP
		if distance < MapViewRuntimeCamera.THIRD_PERSON_MIN_DISTANCE:
			break
		var candidate := player_pos + dir * distance
		if not _line_of_sight_blocked(candidate, player_pos):
			camera.position = candidate
			return
	camera.position = player_pos + Vector3.UP * MapViewRuntimeCamera.THIRD_PERSON_TARGET_HEIGHT


## Buildings occlude through the view's occluder boxes. On relief (ADR 0023,
## WB-03) a rising bank between camera and player occludes too, so the same
## pull-in recovers from it instead of leaving the camera looking into the slope.
func _line_of_sight_blocked(from: Vector3, player_pos: Vector3) -> bool:
	var view := _controller.view
	if view.is_segment_occluded(_in_view(view, from), _in_view(view, player_pos)):
		return true
	var chest := player_pos + Vector3.UP * TERRAIN_SIGHT_HEIGHT
	return segment_under_ground(
		view.definition, _in_view(view, from), _in_view(view, chest)
	)


## True when the straight segment dips below the rendered ground anywhere between
## its ends. Samples every TERRAIN_SIGHT_STEP world units, excluding both ends
## (the target sits above the player's feet, which legitimately touch the
## ground). Flat maps return false without sampling, so their camera behaviour is
## unchanged.
static func segment_under_ground(definition: MapDefinition, from: Vector3, to: Vector3) -> bool:
	if definition == null or not MapTerrainMovement.has_relief(definition):
		return false
	var length := from.distance_to(to)
	var steps := int(ceil(length / TERRAIN_SIGHT_STEP))
	for step in range(1, steps):
		var point := from.lerp(to, float(step) / float(steps))
		var ground := MapViewMeshBuilder.ground_height(definition, Vector2(point.x, point.z))
		if point.y < ground + TERRAIN_SIGHT_CLEARANCE:
			return true
	return false


static func _in_view(view: MapView3D, world_point: Vector3) -> Vector3:
	if view == null:
		return world_point
	var parent := view.get_parent() as Node3D
	if parent == null:
		return world_point
	return world_point - parent.position


static func _from_view(view: MapView3D, local_point: Vector3) -> Vector3:
	if view == null:
		return local_point
	var parent := view.get_parent() as Node3D
	if parent == null:
		return local_point
	return local_point + parent.position


static func _view_local_xz(view: MapView3D, world_xz: Vector2) -> Vector2:
	if view == null:
		return world_xz
	var parent := view.get_parent() as Node3D
	if parent == null:
		return world_xz
	return world_xz - Vector2(parent.position.x, parent.position.z)
