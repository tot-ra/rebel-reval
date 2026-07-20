class_name CombatDefensePose
extends RefCounted

## Snapshot of defensive posture at the moment an incoming hit resolves.
## Shared by player and future combat actors so guard/parry/dodge rules stay one place.

## Keep aligned with CombatVitals.DEFAULT_PARRY_WINDOW_SEC (avoid class load cycles).
const DEFAULT_PARRY_WINDOW_SEC := 0.18

var is_action_invulnerable: bool = false
var is_guarding: bool = false
var guard_elapsed_sec: float = 0.0
var parry_window_sec: float = DEFAULT_PARRY_WINDOW_SEC


static func open() -> CombatDefensePose:
	return CombatDefensePose.new()


static func from_action_machine(
	machine: PlayerActionStateMachine,
	parry_window: float = DEFAULT_PARRY_WINDOW_SEC
) -> CombatDefensePose:
	var pose := CombatDefensePose.new()
	pose.parry_window_sec = maxf(0.0, parry_window)
	if machine == null:
		return pose
	pose.is_action_invulnerable = machine.is_invulnerable()
	pose.is_guarding = machine.state == PlayerActionState.State.GUARD
	if pose.is_guarding:
		pose.guard_elapsed_sec = machine.state_elapsed_sec
	return pose


func is_parry_window() -> bool:
	return is_guarding and guard_elapsed_sec <= parry_window_sec
