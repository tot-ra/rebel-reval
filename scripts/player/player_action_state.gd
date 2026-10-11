class_name PlayerActionState
extends RefCounted

enum State {
	MOVE,
	ATTACK,
	GUARD,
	DODGE,
	HIT,
	RECOVERY,
	ROLL,
	CAST,
}


static func allows_movement(state: State) -> bool:
	return state == State.MOVE


static func is_action_locked(state: State) -> bool:
	return state != State.MOVE


static func display_name(state: State) -> String:
	match state:
		State.MOVE:
			return "move"
		State.ATTACK:
			return "attack"
		State.GUARD:
			return "guard"
		State.DODGE:
			return "dodge"
		State.HIT:
			return "hit"
		State.RECOVERY:
			return "recovery"
		State.ROLL:
			return "roll"
		State.CAST:
			return "cast"
		_:
			return "unknown"
