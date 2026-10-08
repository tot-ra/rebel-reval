class_name VegetationInteractionBuffer
extends RefCounted

## Ring buffer of recent body positions that press the grass down (R-1327).
## Why: a single push centre snaps shut the instant the walker moves on; keeping
## the last few footfalls for a few seconds leaves a visible lane through tall
## grass that then springs back. Session-only, capped, no allocation per frame
## beyond the shader array, and deterministic for the same position history.

const CAPACITY := 8
## Seconds a pressed spot takes to spring fully back.
const LIFETIME := 4.0
## A new entry is only recorded after the walker moved this far (world units).
const MIN_SPACING := 0.45

var _pos: Array[Vector2] = []
var _heading: Array[Vector2] = []
var _stamp: Array[float] = []


func size() -> int:
	return _pos.size()


func clear() -> void:
	_pos.clear()
	_heading.clear()
	_stamp.clear()


## Records the walker at `p` heading `heading` (any length) at time `now`.
## Returns true when an entry was added. The oldest entry is evicted at capacity.
func push(p: Vector2, heading: Vector2, now: float) -> bool:
	if not _pos.is_empty() and _pos[_pos.size() - 1].distance_to(p) < MIN_SPACING:
		return false
	if _pos.size() >= CAPACITY:
		_pos.remove_at(0)
		_heading.remove_at(0)
		_stamp.remove_at(0)
	_pos.append(p)
	_heading.append(heading.normalized() if heading.length_squared() > 0.0001 else Vector2.ZERO)
	_stamp.append(now)
	return true


## Remaining press of entry `i` at `now`, 1 fresh .. 0 sprung back (eased out).
func strength(i: int, now: float) -> float:
	var age := clampf((now - _stamp[i]) / LIFETIME, 0.0, 1.0)
	return (1.0 - age) * (1.0 - age)


func position_of(i: int) -> Vector2:
	return _pos[i]


## Shader array, always CAPACITY long: (x, z, heading angle, press 0..1).
## Unused slots have zero press.
func to_shader_array(now: float) -> PackedVector4Array:
	var out := PackedVector4Array()
	out.resize(CAPACITY)
	for i in _pos.size():
		var s := strength(i, now)
		out[i] = Vector4(_pos[i].x, _pos[i].y, atan2(_heading[i].y, _heading[i].x), s)
	return out
