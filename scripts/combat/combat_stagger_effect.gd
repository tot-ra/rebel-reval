class_name CombatStaggerEffect
extends RefCounted

## Reusable timed stagger status. Actors own one instance and decide how the
## active window affects their state machine; magic only applies this module.

signal applied(duration_sec: float)
signal expired

var remaining_sec: float = 0.0


func apply(duration_sec: float) -> bool:
	if duration_sec <= 0.0:
		return false
	remaining_sec = maxf(remaining_sec, duration_sec)
	applied.emit(remaining_sec)
	return true


func tick(delta: float) -> void:
	if delta <= 0.0 or remaining_sec <= 0.0:
		return
	remaining_sec = maxf(0.0, remaining_sec - delta)
	if is_zero_approx(remaining_sec):
		expired.emit()


func clear() -> void:
	remaining_sec = 0.0


func is_active() -> bool:
	return remaining_sec > 0.0


func remaining_duration_sec() -> float:
	return remaining_sec


## Adapter for actors that expose the shared apply_stagger contract.
static func apply_to(target: Node, duration_sec: float) -> bool:
	if target == null or not is_instance_valid(target) or duration_sec <= 0.0:
		return false
	if not target.has_method("apply_stagger"):
		return false
	target.call("apply_stagger", duration_sec)
	return true
