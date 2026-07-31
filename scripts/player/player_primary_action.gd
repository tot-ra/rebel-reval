class_name PlayerPrimaryAction
extends RefCounted

## Resolves what the primary (left) click means in the character-relative camera
## modes: first-person and third-person.
##
## WHY: in those modes the character - not the cursor - is the pointer. An
## aggressive target in front of the player must answer with a swing, while a
## neutral or quest-giving character, a chest, a body, or a loose item must
## answer with dialogue/pickup/use. Click-to-move stays exclusive to top-down,
## where the cursor really does select a destination on the ground.

const DAMAGEABLE_GROUP := &"combat_damageable"

enum Intent {
	ATTACK,
	INTERACT,
}

## Hostiles slightly beyond weapon reach still resolve as ATTACK: swinging is the
## honest answer to an enemy closing in, and silently walking or talking instead
## would read as an unresponsive control.
const HOSTILE_SCAN_PX := 220.0
## Facing cones as dot products against the character's facing. Hostile targeting
## is deliberately tighter, so a foe at the shoulder cannot steal a click that was
## aimed at the chest directly ahead.
const HOSTILE_FACING_DOT := 0.35
const INTERACT_FACING_DOT := 0.0


## Returns {"intent": Intent, "target": Node}. ATTACK with a null target is the
## default: clicking at nothing in front is still a swing, not a move order.
static func resolve(actor: Node2D, facing: Vector2) -> Dictionary:
	var attack_result: Dictionary = {"intent": Intent.ATTACK, "target": null}
	if actor == null or actor.get_tree() == null:
		return attack_result
	var direction := facing.normalized() if not facing.is_zero_approx() else Vector2.ZERO

	var hostile := find_hostile_in_front(actor, direction)
	if hostile != null:
		attack_result["target"] = hostile
		return attack_result

	var interactable := Interactable.find_in_front_of_actor(actor, direction, INTERACT_FACING_DOT)
	if interactable != null:
		return {"intent": Intent.INTERACT, "target": interactable}
	return attack_result


## Closest live damageable inside the aggression cone, excluding the actor itself.
static func find_hostile_in_front(
	actor: Node2D,
	facing: Vector2,
	scan_px: float = HOSTILE_SCAN_PX,
	minimum_facing_dot: float = HOSTILE_FACING_DOT
) -> Node2D:
	if actor == null or actor.get_tree() == null:
		return null
	var best: Node2D = null
	var best_distance := INF
	var scan_squared := scan_px * scan_px
	for candidate_node: Node in actor.get_tree().get_nodes_in_group(DAMAGEABLE_GROUP):
		if candidate_node == actor or not candidate_node is Node2D:
			continue
		var candidate := candidate_node as Node2D
		if not candidate.has_method("take_damage") or is_defeated(candidate):
			continue
		var offset := candidate.global_position - actor.global_position
		var distance_squared := offset.length_squared()
		if distance_squared > scan_squared or is_zero_approx(distance_squared):
			continue
		if not facing.is_zero_approx() and facing.dot(offset.normalized()) < minimum_facing_dot:
			continue
		if distance_squared < best_distance:
			best_distance = distance_squared
			best = candidate
	return best


## Downed actors must not keep claiming clicks; looting a body goes through its
## own Interactable instead.
static func is_defeated(candidate: Node) -> bool:
	if candidate.has_method("is_combat_dead"):
		return bool(candidate.call("is_combat_dead"))
	if candidate.has_method("get_machine"):
		var machine: Variant = candidate.call("get_machine")
		if machine != null and machine.has_method("is_dead"):
			return bool(machine.call("is_dead"))
	return false
