class_name MagicProjectile2D
extends Node2D

## Generic projectile delivery for authored magic effect plans. Spell identity stays in
## content; this node only understands reusable delivery, impact, and area modules.

signal impacted(position: Vector2, targets: Array[Node2D])
signal expired

const DAMAGEABLE_GROUP := &"combat_damageable"
const DEFAULT_HIT_RADIUS := 18.0

var source: Node2D
var spell_id: StringName = &""
var direction := Vector2.RIGHT
var speed := 0.0
var remaining_range := 0.0
var impact_effect: Dictionary = {}
var area_effect: Dictionary = {}
var active := false


func configure(
	caster: Node2D,
	cast_spell_id: StringName,
	cast_direction: Vector2,
	effect_plan: Dictionary
) -> bool:
	var delivery: Variant = effect_plan.get("delivery", {})
	var impact: Variant = effect_plan.get("impact", {})
	if not delivery is Dictionary or not impact is Dictionary:
		return false
	var delivery_dict := delivery as Dictionary
	if String(delivery_dict.get("kind", "")) != "projectile":
		return false
	speed = float(delivery_dict.get("speed", 0.0))
	remaining_range = float(delivery_dict.get("range", 0.0))
	if speed <= 0.0 or remaining_range <= 0.0:
		return false
	source = caster
	spell_id = cast_spell_id
	direction = cast_direction.normalized()
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	impact_effect = (impact as Dictionary).duplicate(true)
	var authored_area: Variant = effect_plan.get("area", {})
	area_effect = (authored_area as Dictionary).duplicate(true) if authored_area is Dictionary else {}
	active = true
	queue_redraw()
	return true


func _physics_process(delta: float) -> void:
	advance(delta)


## Public deterministic step keeps the same execution path testable without awaiting frames.
func advance(delta: float) -> void:
	if not active or delta <= 0.0:
		return
	var travel := minf(speed * delta, remaining_range)
	global_position += direction * travel
	remaining_range -= travel
	var target := _nearest_target(DEFAULT_HIT_RADIUS)
	if target != null:
		_resolve_impact(target)
	elif remaining_range <= 0.0:
		active = false
		expired.emit()
		queue_free()


func _nearest_target(radius: float) -> Node2D:
	if not is_inside_tree():
		return null
	var nearest: Node2D
	var nearest_distance := radius
	for candidate_node: Node in get_tree().get_nodes_in_group(DAMAGEABLE_GROUP):
		var candidate := candidate_node as Node2D
		if candidate == null or candidate == source or not candidate.has_method("take_damage"):
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance <= nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest


func _resolve_impact(primary: Node2D) -> void:
	active = false
	var affected: Array[Node2D] = []
	_apply_damage(primary, impact_effect)
	affected.append(primary)
	var radius := float(area_effect.get("radius", 0.0))
	var splash: Variant = area_effect.get("effect", {})
	if radius > 0.0 and splash is Dictionary and is_inside_tree():
		for candidate_node: Node in get_tree().get_nodes_in_group(DAMAGEABLE_GROUP):
			var candidate := candidate_node as Node2D
			if (
				candidate == null
				or candidate == source
				or candidate == primary
				or not candidate.has_method("take_damage")
			):
				continue
			if global_position.distance_to(candidate.global_position) <= radius:
				_apply_damage(candidate, splash as Dictionary)
				affected.append(candidate)
	impacted.emit(global_position, affected)
	queue_free()


func _apply_damage(target: Node2D, effect: Dictionary) -> void:
	if String(effect.get("kind", "")) != "damage":
		return
	var amount := float(effect.get("amount", 0.0))
	if amount <= 0.0:
		return
	var damage_type := StringName(String(effect.get("damage_type", "magic")))
	target.call("take_damage", amount, source, damage_type)


func _draw() -> void:
	# Procedural presentation avoids coupling the reusable prototype to legacy HUD art.
	draw_circle(Vector2.ZERO, 8.0, Color(1.0, 0.25, 0.04, 0.95))
	draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.85, 0.25, 1.0))
