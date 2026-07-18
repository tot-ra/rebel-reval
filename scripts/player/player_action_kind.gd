class_name PlayerActionKind
extends RefCounted

enum Kind {
	NONE,
	ATTACK,
	GUARD,
	DODGE,
}

const ACTION_ATTACK := &"player_attack"
const ACTION_GUARD := &"player_guard"
const ACTION_DODGE := &"player_dodge"

static func from_input_action(action: StringName) -> Kind:
	match action:
		ACTION_ATTACK:
			return Kind.ATTACK
		ACTION_GUARD:
			return Kind.GUARD
		ACTION_DODGE:
			return Kind.DODGE
		_:
			return Kind.NONE
