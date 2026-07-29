class_name SmithyActivityPoint
extends RefCounted

## Semantic station anchor for smithy domestic and forge beats (P2-058).
## Transforms are authored in pixel space at cell centres from the domestic-life plan.

var id: StringName = &""
var zone: StringName = &""
var approach_position: Vector2 = Vector2.ZERO
var facing: Vector2 = Vector2.DOWN
var prop_id: StringName = &""
var allowed_actors: Array[StringName] = []
var duration_min_sec: float = 1.0
var duration_max_sec: float = 3.0
var allowed_phases: Array[StringName] = []
var time_bands: Array[StringName] = []
var body_socket: StringName = &""
var hand_prop_socket: StringName = &""
var exclusive: bool = true
var fallback_activity_id: StringName = &""


static func from_dict(data: Dictionary) -> SmithyActivityPoint:
	var point := SmithyActivityPoint.new()
	point.id = StringName(str(data.get("id", "")))
	point.zone = StringName(str(data.get("zone", "")))
	point.approach_position = _parse_position(data.get("approach_position", {}))
	point.facing = _parse_facing(data.get("facing", "down"))
	point.prop_id = StringName(str(data.get("prop_id", "")))
	point.allowed_actors = _parse_string_name_array(data.get("allowed_actors", []))
	point.duration_min_sec = float(data.get("duration_min_sec", 1.0))
	point.duration_max_sec = float(data.get("duration_max_sec", 3.0))
	point.allowed_phases = _parse_string_name_array(data.get("allowed_phases", []))
	point.time_bands = _parse_string_name_array(data.get("time_bands", [&"any"]))
	point.body_socket = StringName(str(data.get("body_socket", "")))
	point.hand_prop_socket = StringName(str(data.get("hand_prop_socket", "")))
	point.exclusive = bool(data.get("exclusive", true))
	var fallback := str(data.get("fallback_activity_id", ""))
	if not fallback.is_empty():
		point.fallback_activity_id = StringName(fallback)
	return point


func allows_actor(actor_id: StringName) -> bool:
	return allowed_actors.is_empty() or allowed_actors.has(actor_id)


func allows_phase(phase_id: StringName) -> bool:
	return allowed_phases.is_empty() or allowed_phases.has(phase_id)


func allows_time_band(time_band: StringName) -> bool:
	if time_bands.is_empty() or time_bands.has(&"any"):
		return true
	return time_bands.has(time_band)


func sample_duration_sec(seed: int) -> float:
	if is_equal_approx(duration_min_sec, duration_max_sec):
		return duration_min_sec
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([id, seed])
	return lerpf(duration_min_sec, duration_max_sec, rng.randf())


static func cell_center_to_position(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * float(MapTypes.DEFAULT_CELL_SIZE)


static func _parse_position(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Dictionary:
		return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


static func _parse_facing(value: Variant) -> Vector2:
	match str(value).to_lower():
		"up":
			return Vector2.UP
		"left":
			return Vector2.LEFT
		"right":
			return Vector2.RIGHT
		_:
			return Vector2.DOWN


static func _parse_string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if value is Array:
		for entry in value:
			result.append(StringName(str(entry)))
	return result
