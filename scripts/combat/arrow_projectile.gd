class_name ArrowProjectile
extends Node2D

## One loosed arrow on the 2D logic plane (task R-1755). The bow's strike spawns it
## instead of a melee pulse; it flies straight along the archer's facing, stops at
## the first wall, and hits the first combat actor or bystander it passes. Like
## MeleeAttackResolver it is deterministic: travel is speed x delta, never physics.
## MapViewMagicVfx mirrors it as an arrow in the 3D view (same contract as
## MagicProjectile2D: `active`, `impacted`, `expired`).

signal impacted(position: Vector2, targets: Array[Node2D])
signal expired

const HIT_RADIUS_PX := 14.0
## Shared with spell projectiles so one swing id never double-counts.
const DAMAGEABLE_GROUP := MeleeAttackResolver.DAMAGEABLE_GROUP
const BYSTANDER_GROUP := MeleeAttackResolver.BYSTANDER_GROUP

var source: Node2D
var direction := Vector2.RIGHT
var speed := 0.0
var remaining_range := 0.0
var damage := 0.0
var damage_type: StringName = &"pierce"
var pierces_guard := false
var active := false
var _swing_id := 0


## Spawns an arrow from `archer` along `facing` under `parent`, or returns null
## for a profile without missile numbers.
static func loose(
	archer: Node2D, facing: Vector2, profile: AttackProfile, parent: Node = null
) -> ArrowProjectile:
	if archer == null or profile == null or not profile.is_ranged() or facing.is_zero_approx():
		return null
	var arrow := ArrowProjectile.new()
	arrow.name = "Arrow"
	arrow.source = archer
	arrow.direction = facing.normalized()
	arrow.speed = profile.ranged_speed_px_per_sec
	arrow.remaining_range = profile.ranged_range_px
	arrow.damage = MeleeAttackResolver.scale_outgoing_damage(archer, profile.damage)
	arrow.damage_type = profile.damage_type
	arrow.pierces_guard = profile.pierces_guard
	arrow._swing_id = MeleeAttackResolver.allocate_swing_id()
	arrow.active = true
	var host := parent if parent != null else archer.get_parent()
	if host == null:
		arrow.free()
		return null
	host.add_child(arrow)
	arrow.global_position = archer.global_position
	return arrow


func _physics_process(delta: float) -> void:
	advance(delta)


## Deterministic step, public so tests drive it without physics frames.
func advance(delta: float) -> void:
	if not active or delta <= 0.0:
		return
	var travel := minf(speed * delta, remaining_range)
	var from := global_position
	var to := from + direction * travel
	var wall := _wall_between(from, to)
	if wall != Vector2.INF:
		to = wall
	# Swept test: the nearest target along this step's segment, so a fast arrow
	# cannot tunnel through a person standing between two frames.
	var target := _first_target_on(from, to)
	if target != null:
		global_position = target.global_position
		_hit(target)
		return
	global_position = to
	remaining_range -= travel
	if wall != Vector2.INF or remaining_range <= 0.0:
		active = false
		expired.emit()
		queue_free()


func _hit(target: Node2D) -> void:
	active = false
	var targets: Array[Node2D] = []
	var applied := float(
		target.call("take_damage", damage, source, damage_type, _swing_id, pierces_guard)
	)
	if applied > 0.0:
		targets.append(target)
	impacted.emit(global_position, targets)
	queue_free()


func _first_target_on(from: Vector2, to: Vector2) -> Node2D:
	if not is_inside_tree():
		return null
	var best: Node2D = null
	var best_t := INF
	var segment := to - from
	var length_squared := maxf(segment.length_squared(), 0.0001)
	for group: StringName in [DAMAGEABLE_GROUP, BYSTANDER_GROUP]:
		for node: Node in get_tree().get_nodes_in_group(group):
			var candidate := node as Node2D
			if candidate == null or candidate == source or not candidate.has_method("take_damage"):
				continue
			# Inline, not PlayerPrimaryAction.is_defeated: MapViewMagicVfx (and so the
			# .rrmap loader at startup) depends on this script, and PlayerPrimaryAction
			# pulls in autoload-dependent scripts that cannot compile that early.
			if candidate.has_method(&"is_combat_dead") and bool(candidate.call(&"is_combat_dead")):
				continue
			var t := clampf((candidate.global_position - from).dot(segment) / length_squared, 0.0, 1.0)
			var closest := from + segment * t
			if closest.distance_to(candidate.global_position) > HIT_RADIUS_PX:
				continue
			if t < best_t:
				best_t = t
				best = candidate
	return best


## First world-wall contact on the segment, or Vector2.INF. Physics queries are
## only valid inside a physics frame; a test stepping by hand flies through.
func _wall_between(from: Vector2, to: Vector2) -> Vector2:
	if not is_inside_tree() or not Engine.is_in_physics_frame():
		return Vector2.INF
	var query := PhysicsRayQueryParameters2D.create(from, to, CollisionLayers.WORLD)
	query.collide_with_areas = false
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return Vector2.INF
	return hit["position"] as Vector2
