class_name CombatHitResult
extends RefCounted

## Outcome of one incoming combat pulse against shared vitals.
const OUTCOME_IGNORED := &"ignored"
const OUTCOME_INVULNERABLE := &"invulnerable"
const OUTCOME_PARRIED := &"parried"
const OUTCOME_GUARDED := &"guarded"
const OUTCOME_HIT := &"hit"

var outcome: StringName = OUTCOME_IGNORED
var requested_damage: float = 0.0
var health_damage: float = 0.0
var stamina_damage: float = 0.0
var died: bool = false
var swing_id: int = 0


static func make(
	outcome_name: StringName,
	requested: float = 0.0,
	health: float = 0.0,
	stamina: float = 0.0,
	is_dead: bool = false,
	id: int = 0
) -> CombatHitResult:
	var result := CombatHitResult.new()
	result.outcome = outcome_name
	result.requested_damage = requested
	result.health_damage = health
	result.stamina_damage = stamina
	result.died = is_dead
	result.swing_id = id
	return result
