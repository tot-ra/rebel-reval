class_name MagicAreaPulse2D
extends Node2D

## Generic immediate area delivery for authored magic plans. The pulse filters
## only damageable hostile actors and never synthesizes effects from spell IDs.

signal pulsed(position: Vector2, targets: Array[Node2D])
signal expired

const DAMAGEABLE_GROUP := &"combat_damageable"

var source: Node2D
var spell_id: StringName = &""
var radius: float = 0.0
## Optional cone (R-722): full circle at 360, otherwise centred on `direction`.
var arc_deg: float = 360.0
var direction := Vector2.RIGHT
var effect: Dictionary = {}
var active := false


func configure(
	caster: Node2D,
	cast_spell_id: StringName,
	pulse_radius: float,
	pulse_effect: Dictionary,
	cast_direction: Vector2 = Vector2.ZERO,
	pulse_arc_deg: float = 360.0
) -> bool:
	if caster == null or pulse_radius <= 0.0 or pulse_effect.is_empty():
		return false
	if pulse_arc_deg <= 0.0 or pulse_arc_deg > 360.0:
		return false
	source = caster
	spell_id = cast_spell_id
	radius = pulse_radius
	arc_deg = pulse_arc_deg
	if not cast_direction.is_zero_approx():
		direction = cast_direction.normalized()
	effect = pulse_effect.duplicate(true)
	active = true
	queue_redraw()
	return true


func pulse() -> Array[Node2D]:
	if not active or source == null or not is_inside_tree():
		return []
	active = false
	var affected: Array[Node2D] = []
	for candidate_node: Node in get_tree().get_nodes_in_group(DAMAGEABLE_GROUP):
		var candidate := candidate_node as Node2D
		if not _is_valid_target(candidate):
			continue
		if global_position.distance_to(candidate.global_position) > radius:
			continue
		if not _is_inside_arc(candidate.global_position - global_position):
			continue
		if _apply_effect(candidate):
			affected.append(candidate)
	pulsed.emit(global_position, affected)
	expired.emit()
	queue_free()
	return affected


func _is_valid_target(candidate: Node2D) -> bool:
	if candidate == null or candidate == source:
		return false
	if not candidate.has_method("take_damage"):
		return false
	# Dead AI hosts stay in the damageable group for outcome bookkeeping; a
	# pulse must not report them as affected.
	if candidate.has_method("is_combat_dead") and bool(candidate.call("is_combat_dead")):
		return false
	# Faction-aware actors opt into the same hostile filter. Actors without a
	# faction marker retain the combat-room default of being hostile targets.
	if candidate.has_method("is_hostile_to") and not bool(candidate.call("is_hostile_to", source)):
		return false
	return true


## A target on the caster has no bearing, so it counts as inside any cone.
## The small epsilon keeps targets exactly on the cone edge included, like the
## radius boundary.
func _is_inside_arc(offset: Vector2) -> bool:
	if arc_deg >= 360.0 or offset.is_zero_approx():
		return true
	var half_arc := deg_to_rad(arc_deg * 0.5)
	return absf(direction.angle_to(offset)) <= half_arc + 0.0001


func _apply_effect(target: Node2D) -> bool:
	var kind := String(effect.get("kind", ""))
	if kind == "stagger":
		return CombatStaggerEffect.apply_to(target, float(effect.get("duration_sec", 0.0)))
	if kind == "knockback":
		return CombatKnockbackEffect.apply_to(
			target, _knockback_heading(target) * float(effect.get("distance", 0.0)),
			float(effect.get("duration_sec", 0.0))
		)
	if kind == "damage":
		var amount := float(effect.get("amount", 0.0))
		if amount <= 0.0:
			return false
		target.call("take_damage", amount, source, StringName(String(effect.get("damage_type", "magic"))))
		return true
	return false


## Pushes point away from the caster; a target standing on the caster is
## pushed along the cast direction instead of an arbitrary axis.
func _knockback_heading(target: Node2D) -> Vector2:
	var away := target.global_position - global_position
	return direction if away.is_zero_approx() else away.normalized()


func _draw() -> void:
	var color := Color(0.67, 0.48, 0.24, 0.8)
	if arc_deg >= 360.0:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, color, 2.0)
		return
	var half_arc := deg_to_rad(arc_deg * 0.5)
	var start := direction.angle() - half_arc
	var finish := direction.angle() + half_arc
	draw_arc(Vector2.ZERO, radius, start, finish, 32, color, 2.0)
	draw_line(Vector2.ZERO, Vector2.from_angle(start) * radius, color, 2.0)
	draw_line(Vector2.ZERO, Vector2.from_angle(finish) * radius, color, 2.0)
