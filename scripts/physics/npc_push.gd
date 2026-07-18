class_name NpcPush
extends RefCounted

## Gentle player displacement for non-hostile logic bodies. The player detects NPC
## collisions via its expanded mask; this helper applies the actual push motion
## on the NPC side so world geometry still blocks both actors.

const PUSH_GROUP := &"npc_pushable"
const HOSTILE_GROUP := &"hostile_npc"
const PUSH_META := &"_npc_push_motion"
const PUSH_SPEED_SCALE := 0.75
const MAX_PUSH_PER_FRAME := 28.0
const REACH_PADDING := 10.0


static func can_be_pushed(body: CharacterBody2D) -> bool:
	if body == null or not is_instance_valid(body):
		return false
	if body.is_in_group(HOSTILE_GROUP):
		return false
	if body.has_method("is_pushable_by_player"):
		return bool(body.call("is_pushable_by_player"))
	return body.is_in_group(PUSH_GROUP)


static func queue_push(body: CharacterBody2D, direction: Vector2, distance: float) -> void:
	if not can_be_pushed(body) or distance <= 0.0:
		return
	var motion := direction.normalized() * minf(distance * PUSH_SPEED_SCALE, MAX_PUSH_PER_FRAME)
	if motion.is_zero_approx():
		return
	var queued: Vector2 = body.get_meta(PUSH_META, Vector2.ZERO)
	body.set_meta(PUSH_META, queued + motion)


static func apply_queued_push(body: CharacterBody2D, delta: float) -> bool:
	var motion: Vector2 = body.get_meta(PUSH_META, Vector2.ZERO)
	if motion.is_zero_approx():
		return false
	body.remove_meta(PUSH_META)
	body.velocity = motion / maxf(delta, 0.001)
	body.move_and_slide()
	body.velocity = Vector2.ZERO
	return true


static func has_queued_push(body: CharacterBody2D) -> bool:
	return not body.get_meta(PUSH_META, Vector2.ZERO).is_zero_approx()


static func apply_player_contact_pushes(
	player: CharacterBody2D,
	movement_velocity: Vector2,
	delta: float
) -> void:
	if player == null or delta <= 0.0 or movement_velocity.is_zero_approx():
		return
	var push_distance := movement_velocity.length() * delta
	if push_distance <= 0.0:
		return
	var push_direction := movement_velocity.normalized()
	var reach := _player_push_reach(player)
	for node in player.get_tree().get_nodes_in_group(PUSH_GROUP):
		var body := node as CharacterBody2D
		if body == null or body == player or not can_be_pushed(body):
			continue
		var offset := body.global_position - player.global_position
		if offset.length_squared() > reach * reach:
			continue
		if push_direction.dot(offset) <= 0.0:
			continue
		queue_push(body, push_direction, push_distance)
		apply_queued_push(body, delta)


static func _player_push_reach(player: CharacterBody2D) -> float:
	var player_radius := 16.0
	var collision_shape := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null and collision_shape.shape is CapsuleShape2D:
		player_radius = (collision_shape.shape as CapsuleShape2D).radius
	return player_radius + 24.0 + REACH_PADDING


static func player_blocks_body(body: CharacterBody2D) -> bool:
	return overlaps_collision_mask(body, CollisionLayers.PLAYER)


static func overlaps_collision_mask(body: CharacterBody2D, mask: int) -> bool:
	return not overlapping_bodies(body, mask).is_empty()


static func overlapping_pushable_bodies(body: CharacterBody2D) -> Array[CharacterBody2D]:
	var pushable: Array[CharacterBody2D] = []
	for candidate in overlapping_bodies(body, CollisionLayers.NPC):
		if can_be_pushed(candidate):
			pushable.append(candidate)
	return pushable


static func overlapping_bodies(body: CharacterBody2D, mask: int) -> Array[CharacterBody2D]:
	var found: Array[CharacterBody2D] = []
	if body == null or not is_instance_valid(body):
		return found
	var collision_shape := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null or collision_shape.shape == null:
		return found
	var world := body.get_world_2d()
	if world == null:
		return found
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = collision_shape.shape
	params.transform = collision_shape.global_transform
	params.collision_mask = mask
	params.exclude = [body.get_rid()]
	for result in world.direct_space_state.intersect_shape(params, 16):
		var candidate := result.collider as CharacterBody2D
		if candidate != null and candidate != body:
			found.append(candidate)
	return found
