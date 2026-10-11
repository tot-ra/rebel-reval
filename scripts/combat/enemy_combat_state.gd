class_name EnemyCombatState
extends RefCounted

## Shared enemy AI states for watchman and sergeant (P1-025).
## Controllers must not fork these enums per archetype.

enum State {
	PATROL,
	DETECT,
	CHASE,
	TELEGRAPH,
	ATTACK,
	REACT,
	RETREAT,
	DISENGAGE,
	DEAD,
}


static func display_name(state: State) -> String:
	match state:
		State.PATROL:
			return "patrol"
		State.DETECT:
			return "detect"
		State.CHASE:
			return "chase"
		State.TELEGRAPH:
			return "telegraph"
		State.ATTACK:
			return "attack"
		State.REACT:
			return "react"
		State.RETREAT:
			return "retreat"
		State.DISENGAGE:
			return "disengage"
		State.DEAD:
			return "dead"
		_:
			return "unknown"


static func is_combat_engaged(state: State) -> bool:
	return (
		state
		in [
			State.DETECT,
			State.CHASE,
			State.TELEGRAPH,
			State.ATTACK,
			State.REACT,
			State.RETREAT,
		]
	)


static func allows_patrol_motion(state: State) -> bool:
	return state == State.PATROL or state == State.DISENGAGE
