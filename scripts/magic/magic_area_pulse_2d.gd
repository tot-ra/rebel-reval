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
var effect: Dictionary = {}
var active := false


func configure(
	caster: Node2D,
	cast_spell_id: StringName,
	pulse_radius: float,
	pulse_effect: Dictionary
) -> bool:
	if caster == null or pulse_radius <= 0.0 or pulse_effect.is_empty():
		return false
	source = caster
	spell_id = cast_spell_id
	radius = pulse_radius
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
	# Faction-aware actors opt into the same hostile filter. Actors without a
	# faction marker retain the combat-room default of being hostile targets.
	if candidate.has_method("is_hostile_to") and not bool(candidate.call("is_hostile_to", source)):
		return false
	return true


func _apply_effect(target: Node2D) -> bool:
	var kind := String(effect.get("kind", ""))
	if kind == "stagger":
		return CombatStaggerEffect.apply_to(target, float(effect.get("duration_sec", 0.0)))
	if kind == "damage":
		var amount := float(effect.get("amount", 0.0))
		if amount <= 0.0:
			return false
		target.call("take_damage", amount, source, StringName(String(effect.get("damage_type", "magic"))))
		return true
	return false


func _draw() -> void:
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(0.67, 0.48, 0.24, 0.8), 2.0)
