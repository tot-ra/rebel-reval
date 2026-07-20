class_name EnemyCombatState
extends RefCounted

## Shared enemy AI states for watchman and sergeant (P1-025).
## Controllers must not fork these enums per archetype.

enum State {
	PATROL,
	DETECT,
	TELEGRAPH,
	ATTACK,
	REACT,
	DISENGAGE,
	DEAD,
}


static func display_name(state: State) -> String:
	match state:
		State.PATROL:
			return "patrol"
		State.DETECT:
			return "detect"
		State.TELEGRAPH:
			return "telegraph"
		State.ATTACK:
			return "attack"
		State.REACT:
			return "react"
		State.DISENGAGE:
			return "disengage"
		State.DEAD:
			return "dead"
		_:
			return "unknown"


static func is_combat_engaged(state: State) -> bool:
	return state in [
		State.DETECT,
		State.TELEGRAPH,
		State.ATTACK,
		State.REACT,
	]


static func allows_patrol_motion(state: State) -> bool:
	return state == State.PATROL or state == State.DISENGAGE
