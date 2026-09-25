class_name CombatKnockbackEffect
extends RefCounted

## Reusable knockback slide (R-722). Actors own one instance, feed it their
## frame delta, and move by the returned offset; magic only applies the module.
## The slide eases out over a fixed short window, and each step returns
## f(t1) - f(t0), so one big step and many small steps land on the same spot.

signal applied(displacement: Vector2)
signal finished

## Push time. Short enough to read as a shove, long enough for the mirrored
## 3D rig to show the travel instead of a teleport.
const SLIDE_SEC := 0.2

var _displacement := Vector2.ZERO
var _elapsed_sec := 0.0


## A new push replaces any unfinished slide instead of adding to it, so
## overlapping gusts never exceed one authored distance.
func apply(displacement: Vector2) -> bool:
	if displacement.is_zero_approx():
		return false
	_displacement = displacement
	_elapsed_sec = 0.0
	applied.emit(displacement)
	return true


## Returns the offset to add to the actor's position for this step.
func step(delta: float) -> Vector2:
	if delta <= 0.0 or not is_active():
		return Vector2.ZERO
	var before := _progress(_elapsed_sec)
	_elapsed_sec = minf(SLIDE_SEC, _elapsed_sec + delta)
	var offset := _displacement * (_progress(_elapsed_sec) - before)
	if _elapsed_sec >= SLIDE_SEC:
		_displacement = Vector2.ZERO
		finished.emit()
	return offset


func clear() -> void:
	_displacement = Vector2.ZERO
	_elapsed_sec = 0.0


func is_active() -> bool:
	return not _displacement.is_zero_approx()


func remaining_displacement() -> Vector2:
	if not is_active():
		return Vector2.ZERO
	return _displacement * (1.0 - _progress(_elapsed_sec))


static func _progress(elapsed_sec: float) -> float:
	var t := clampf(elapsed_sec / SLIDE_SEC, 0.0, 1.0)
	return 1.0 - (1.0 - t) * (1.0 - t)


## Adapter for actors that expose the shared apply_knockback contract.
static func apply_to(target: Node, displacement: Vector2, duration_sec: float) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if displacement.is_zero_approx() or duration_sec <= 0.0:
		return false
	if not target.has_method("apply_knockback"):
		return false
	target.call("apply_knockback", displacement, duration_sec)
	return true
