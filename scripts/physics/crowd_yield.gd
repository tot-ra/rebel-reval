class_name CrowdYield
extends RefCounted

## Soft "excuse me" for the ambient crowd. Crowd actors (CitizenActor,
## CitySiteActor) are not collidable by the player, otherwise a market or a church
## door full of people walls Kalev off. Instead each actor eases sideways out of
## the player's way and eases back once he has passed. No aggression, no animation:
## pure logistics. The offset is applied on the logic body, the 3D rig mirrors it.

const PLAYER_GROUP := &"player_body"
## Logic pixels: inside this distance an actor starts to give way.
const YIELD_RADIUS := 34.0
## Furthest an actor is displaced from where its schedule wants it.
const MAX_OFFSET := 30.0
const EASE_SPEED := 90.0


## Returns the new offset for an actor whose scheduled position is `home`.
static func step_offset(
	current: Vector2, home: Vector2, player_pos: Vector2, player_velocity: Vector2, delta: float
) -> Vector2:
	var target := Vector2.ZERO
	var away := (home + current) - player_pos
	var dist := away.length()
	if dist < YIELD_RADIUS:
		var dir := away / dist if dist > 0.001 else _side_of(player_velocity)
		# Prefer stepping sideways of the player's heading so a doorway crowd opens
		# like a corridor instead of being pushed along the walking line.
		if player_velocity.length_squared() > 4.0:
			var heading := player_velocity.normalized()
			var lateral := Vector2(-heading.y, heading.x)
			var side := signf(away.dot(lateral))
			dir = (lateral * (side if side != 0.0 else 1.0) * 0.8 + dir * 0.6).normalized()
		target = dir * MAX_OFFSET
	return current.move_toward(target, EASE_SPEED * delta)


static func find_player(tree: SceneTree) -> CharacterBody2D:
	return tree.get_first_node_in_group(PLAYER_GROUP) as CharacterBody2D if tree != null else null


static func _side_of(velocity: Vector2) -> Vector2:
	if velocity.length_squared() <= 0.01:
		return Vector2.RIGHT
	return Vector2(-velocity.y, velocity.x).normalized()
