class_name MagicPersistentArea2D
extends Node2D

## Persistent area delivery for authored magic plans. It keeps targeting policy in
## content and applies a reusable timed effect without checking a spell ID.

signal ticked(position: Vector2, targets: Array[Node2D])
signal expired

const DAMAGEABLE_GROUP := &"combat_damageable"
const TARGET_ALLY := "ally"
const TARGET_HOSTILE := "hostile"
const HEALING_EFFECT_SCRIPT := preload("res://scripts/magic/magic_healing_over_time.gd")

var source: Node2D
var spell_id: StringName = &""
var radius: float = 0.0
var duration_sec: float = 0.0
var target_policy := TARGET_ALLY
var impact_effect: Dictionary = {}
var remaining_sec: float = 0.0
var active := false
var _target_effects: Dictionary = {}


func configure(
	caster: Node2D,
	cast_spell_id: StringName,
	area_radius: float,
	area_delivery: Dictionary,
	area_impact: Dictionary
) -> bool:
	if caster == null or area_radius <= 0.0 or area_delivery.is_empty() or area_impact.is_empty():
		return false
	if String(area_delivery.get("kind", "")) != "persistent_area":
		return false
	var policy := String(area_delivery.get("target_policy", ""))
	if policy not in [TARGET_ALLY, TARGET_HOSTILE]:
		return false
	var effect := HEALING_EFFECT_SCRIPT.new() as MagicHealingOverTime
	if not effect.configure(area_impact):
		return false
	source = caster
	spell_id = cast_spell_id
	radius = area_radius
	duration_sec = float(area_delivery.get("duration_sec", 0.0))
	target_policy = policy
	impact_effect = area_impact.duplicate(true)
	remaining_sec = duration_sec
	_target_effects.clear()
	active = duration_sec > 0.0
	queue_redraw()
	return active


func _process(delta: float) -> void:
	advance(delta)


## Public deterministic step keeps persistent ticks testable without awaiting frames.
func advance(delta: float) -> void:
	if not active or delta <= 0.0 or not is_inside_tree():
		return
	var elapsed := minf(delta, remaining_sec)
	remaining_sec = maxf(0.0, remaining_sec - elapsed)
	var affected: Array[Node2D] = []
	for candidate_node: Node in get_tree().get_nodes_in_group(DAMAGEABLE_GROUP):
		var candidate := candidate_node as Node2D
		if not _is_valid_target(candidate):
			continue
		if global_position.distance_to(candidate.global_position) > radius:
			continue
		var effect_state: Variant = _target_effects.get(candidate)
		if not effect_state is MagicHealingOverTime:
			effect_state = HEALING_EFFECT_SCRIPT.new() as MagicHealingOverTime
			if not (effect_state as MagicHealingOverTime).configure(impact_effect):
				continue
			_target_effects[candidate] = effect_state
		var healed := (effect_state as MagicHealingOverTime).tick(elapsed, candidate)
		if healed > 0.0:
			affected.append(candidate)
	ticked.emit(global_position, affected)
	if is_zero_approx(remaining_sec):
		active = false
		expired.emit()
		queue_free()


func is_active() -> bool:
	return active


func _is_valid_target(candidate: Node2D) -> bool:
	if candidate == null or not MagicHealingOverTime.can_receive(candidate):
		return false
	if candidate == source:
		return target_policy == TARGET_ALLY
	if candidate.has_method("is_hostile_to"):
		var hostile := bool(candidate.call("is_hostile_to", source))
		return hostile if target_policy == TARGET_HOSTILE else not hostile
	return target_policy == TARGET_HOSTILE


func _draw() -> void:
	var tint := (
		Color(0.35, 0.85, 0.72, 0.35)
		if target_policy == TARGET_ALLY
		else Color(0.85, 0.35, 0.3, 0.35)
	)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, tint, 2.0)
