class_name ComparisonRoomProjection
extends RefCounted

## Logical-to-screen projection for the P0-035 comparison room variants.

const ROOM_CENTER := Vector2(640, 360)
const ISO_X_AXIS := Vector2(0.72, 0.32)
const ISO_Y_AXIS := Vector2(-0.62, 0.32)

var orthogonal := false


static func for_orthogonal(enabled: bool) -> ComparisonRoomProjection:
	var projection := ComparisonRoomProjection.new()
	projection.orthogonal = enabled
	return projection


func project_point(logical_point: Vector2) -> Vector2:
	if orthogonal:
		return logical_point
	return ROOM_CENTER + project_vector(logical_point - ROOM_CENTER)


func project_vector(logical_vector: Vector2) -> Vector2:
	if orthogonal:
		return logical_vector
	return ISO_X_AXIS * logical_vector.x + ISO_Y_AXIS * logical_vector.y


func unproject_point(projected_point: Vector2) -> Vector2:
	if orthogonal:
		return projected_point
	var projected_offset := projected_point - ROOM_CENTER
	var determinant := ISO_X_AXIS.x * ISO_Y_AXIS.y - ISO_Y_AXIS.x * ISO_X_AXIS.x
	var logical_x := (projected_offset.x * ISO_Y_AXIS.y - ISO_Y_AXIS.x * projected_offset.y) / determinant
	var logical_y := (ISO_X_AXIS.x * projected_offset.y - projected_offset.x * ISO_X_AXIS.y) / determinant
	return ROOM_CENTER + Vector2(logical_x, logical_y)


func projected_rect_points(center: Vector2, size: Vector2) -> PackedVector2Array:
	var half_size := size * 0.5
	return PackedVector2Array([
		project_point(center + Vector2(-half_size.x, -half_size.y)),
		project_point(center + Vector2(half_size.x, -half_size.y)),
		project_point(center + Vector2(half_size.x, half_size.y)),
		project_point(center + Vector2(-half_size.x, half_size.y)),
	])


func projected_rect_offsets(center: Vector2, size: Vector2) -> PackedVector2Array:
	var projected_center := project_point(center)
	var global_points := projected_rect_points(center, size)
	var offsets := PackedVector2Array()
	for point in global_points:
		offsets.append(point - projected_center)
	return offsets
