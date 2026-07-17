class_name MapTransform
extends RefCounted

## Exact local-cell transform. Mirrors are applied before clockwise rotation.

var rotation_degrees: int
var mirror_x: bool
var mirror_y: bool


func _init(rotation_degrees_value: int = 0, mirror_x_value: bool = false, mirror_y_value: bool = false) -> void:
	rotation_degrees = rotation_degrees_value
	mirror_x = mirror_x_value
	mirror_y = mirror_y_value


func is_valid() -> bool:
	return rotation_degrees % 90 == 0


func quarter_turns() -> int:
	return posmod(rotation_degrees / 90, 4)


func transform_cell(cell: Vector2i) -> Vector2i:
	var transformed := Vector2i(-cell.x if mirror_x else cell.x, -cell.y if mirror_y else cell.y)
	match quarter_turns():
		1:
			return Vector2i(-transformed.y, transformed.x)
		2:
			return -transformed
		3:
			return Vector2i(transformed.y, -transformed.x)
	return transformed


func transform_vector(vector: Vector2) -> Vector2:
	var transformed := Vector2(-vector.x if mirror_x else vector.x, -vector.y if mirror_y else vector.y)
	match quarter_turns():
		1:
			return Vector2(-transformed.y, transformed.x)
		2:
			return -transformed
		3:
			return Vector2(transformed.y, -transformed.x)
	return transformed


func transform_rect(rect: Rect2i) -> Rect2i:
	if rect.size.x <= 0 or rect.size.y <= 0:
		return rect
	# Transform occupied-cell corners, not geometric half-open boundaries. This
	# keeps point cells and one-cell rectangles aligned under reflection.
	var last := rect.end - Vector2i.ONE
	var corners: Array[Vector2i] = [
		transform_cell(rect.position),
		transform_cell(Vector2i(last.x, rect.position.y)),
		transform_cell(Vector2i(rect.position.x, last.y)),
		transform_cell(last),
	]
	var minimum := corners[0]
	var maximum := corners[0]
	for corner in corners:
		minimum = Vector2i(mini(minimum.x, corner.x), mini(minimum.y, corner.y))
		maximum = Vector2i(maxi(maximum.x, corner.x), maxi(maximum.y, corner.y))
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)


func transform_cardinal(value: StringName) -> StringName:
	var vector := _cardinal_vector(value)
	if vector == Vector2i.ZERO:
		return value
	return _vector_cardinal(transform_cell(vector))


func transform_axis(value: StringName) -> StringName:
	if value not in [&"x", &"y", &"z"]:
		return value
	if quarter_turns() % 2 == 0:
		return value
	if value == &"x":
		return &"z"
	if value in [&"y", &"z"]:
		return &"x" if value == &"z" else &"y"
	return value


static func _cardinal_vector(value: StringName) -> Vector2i:
	match value:
		&"north":
			return Vector2i.UP
		&"east":
			return Vector2i.RIGHT
		&"south":
			return Vector2i.DOWN
		&"west":
			return Vector2i.LEFT
	return Vector2i.ZERO


static func _vector_cardinal(value: Vector2i) -> StringName:
	match value:
		Vector2i.UP:
			return &"north"
		Vector2i.RIGHT:
			return &"east"
		Vector2i.DOWN:
			return &"south"
		Vector2i.LEFT:
			return &"west"
	return &""
