class_name MeleeAttackResolver
extends RefCounted

const DAMAGEABLE_GROUP := &"combat_damageable"

## Monotonic id shared by every take_damage call from one strike pulse.
## CombatVitals uses it so one swing cannot damage the same actor twice.
static var _next_swing_id: int = 1


## Resolves one deterministic melee pulse on the 2D logic plane. Presentation
## rigs stay visual-only, so combat uses the same stable positions as movement,
## collision, and navigation.
static func strike(
	attacker: Node2D,
	facing: Vector2,
	reach_px: float,
	minimum_facing_dot: float,
	damage: float,
	damage_type: StringName = &"blunt"
) -> Array[Node2D]:
	var hits: Array[Node2D] = []
	if attacker == null or attacker.get_tree() == null or facing.is_zero_approx():
		return hits
	var swing_id := _allocate_swing_id()
	var attack_direction := facing.normalized()
	var reach_squared := reach_px * reach_px
	for candidate_node: Node in attacker.get_tree().get_nodes_in_group(DAMAGEABLE_GROUP):
		if candidate_node == attacker or not candidate_node is Node2D:
			continue
		var candidate := candidate_node as Node2D
		if not candidate.has_method("take_damage"):
			continue
		var offset := candidate.global_position - attacker.global_position
		if offset.is_zero_approx() or offset.length_squared() > reach_squared:
			continue
		if attack_direction.dot(offset.normalized()) < minimum_facing_dot:
			continue
		var applied := float(candidate.call("take_damage", damage, attacker, damage_type, swing_id))
		if applied > 0.0:
			hits.append(candidate)
	return hits


static func _allocate_swing_id() -> int:
	var swing_id := _next_swing_id
	_next_swing_id += 1
	return swing_id
