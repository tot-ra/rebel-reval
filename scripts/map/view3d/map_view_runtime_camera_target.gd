class_name MapViewRuntimeCameraTarget
extends RefCounted

## Third-person follow-target resolution for MapViewRuntimeCamera: interior floor
## margins, occluder pull-back, and exterior building avoidance. Split out under
## P0-185 so mode/zoom code stays under the architecture soft cap.

## Interior follow targets this close to the floor edge count as wall clips. The
## authored perimeter walls occupy a full cell, so leave that cell plus a small
## lens/mesh buffer between the camera and the room boundary. Without this
## clearance, the safety pass alternates between the wall AABB and the boom target.
const INTERIOR_FLOOR_EDGE_MARGIN := 1.05

var _controller: MapViewRuntimeCamera


func configure(controller: MapViewRuntimeCamera) -> void:
	_controller = controller


func resolve_third_person_target(target: Vector3) -> Vector3:
	var view := _controller.view
	if view == null or view.definition == null:
		return target
	var anchor := (
		_controller.player_rig.position
		+ Vector3.UP * MapViewRuntimeCamera.THIRD_PERSON_TARGET_HEIGHT
	)
	var direction := target - anchor
	var distance := direction.length()
	if is_zero_approx(distance):
		return target
	direction /= distance
	# Interior maps enforce floor-edge margins so the boom stays inside the room.
	# Exterior maps pull the target out of any building/landmark AABB it enters.
	if view.definition.suppresses_exterior_surroundings():
		while (
			distance > MapViewRuntimeCamera.THIRD_PERSON_MIN_DISTANCE
			and third_person_target_clips(target)
		):
			distance = maxf(MapViewRuntimeCamera.THIRD_PERSON_MIN_DISTANCE, distance * 0.75)
			target = anchor + direction * distance
	else:
		# A visual mass can legitimately contain the actor endpoint (for example
		# an open facade or an interior-facing spawn). There is no valid outward
		# direction in that case, so let the authored follow target remain exact.
		if not _controller.player_inside_occluder():
			while (
				distance > MapViewRuntimeCamera.THIRD_PERSON_MIN_DISTANCE
				and view.is_point_inside_occluder(target)
			):
				distance = maxf(MapViewRuntimeCamera.THIRD_PERSON_MIN_DISTANCE, distance * 0.75)
				target = anchor + direction * distance
	if view.definition.suppresses_exterior_surroundings():
		# A minimum boom can still leave a player near a perimeter wall with the
		# lens inside that wall's AABB. Clamp the final target to the walkable room
		# envelope so the next-frame safety pass cannot pull it back and forth.
		return clamp_interior_target(target)
	return target


func clamp_interior_target(target: Vector3) -> Vector3:
	var view := _controller.view
	var size := view.definition.size_cells
	var min_edge := INTERIOR_FLOOR_EDGE_MARGIN
	var max_x := maxf(min_edge, float(size.x) - min_edge)
	var max_z := maxf(min_edge, float(size.y) - min_edge)
	target.x = clampf(target.x, min_edge, max_x)
	target.z = clampf(target.z, min_edge, max_z)
	return target


func third_person_target_clips(target: Vector3) -> bool:
	var view := _controller.view
	if view.is_point_inside_occluder(target):
		return true
	var size := view.definition.size_cells
	return (
		target.x < INTERIOR_FLOOR_EDGE_MARGIN
		or target.x > float(size.x) - INTERIOR_FLOOR_EDGE_MARGIN
		or target.z < INTERIOR_FLOOR_EDGE_MARGIN
		or target.z > float(size.y) - INTERIOR_FLOOR_EDGE_MARGIN
	)
