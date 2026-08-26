class_name MagicCastExecutor2D
extends RefCounted

## Bridges validated/resourced cast results into reusable world delivery nodes.

const PROJECTILE_SCRIPT := preload("res://scripts/magic/magic_projectile_2d.gd")
const AREA_PULSE_SCRIPT := preload("res://scripts/magic/magic_area_pulse_2d.gd")


static func execute(
	cast_result: Dictionary,
	caster: Node2D,
	direction: Vector2,
	host: Node = null
) -> Node2D:
	if not bool(cast_result.get("ok", false)) or caster == null:
		return null
	var effect: Variant = cast_result.get("effect", {})
	if not effect is Dictionary:
		return null
	var effect_dict := effect as Dictionary
	var delivery: Variant = effect_dict.get("delivery", {})
	if not delivery is Dictionary:
		return null

	var parent := host if host != null else caster.get_parent()
	if parent == null:
		return null
	var delivery_kind := String((delivery as Dictionary).get("kind", ""))
	if delivery_kind == "projectile":
		return _execute_projectile(cast_result, caster, direction, parent, effect_dict)
	if delivery_kind == "area_pulse":
		return _execute_area_pulse(cast_result, caster, parent, effect_dict)
	return null


static func _execute_projectile(
	cast_result: Dictionary,
	caster: Node2D,
	direction: Vector2,
	parent: Node,
	effect: Dictionary
) -> Node2D:
	var projectile := PROJECTILE_SCRIPT.new() as Node2D
	if not projectile.configure(
		caster,
		StringName(String(cast_result.get("target_id", ""))),
		direction,
		effect
	):
		projectile.free()
		return null
	parent.add_child(projectile)
	projectile.global_position = caster.global_position
	return projectile


static func _execute_area_pulse(
	cast_result: Dictionary,
	caster: Node2D,
	parent: Node,
	effect: Dictionary
) -> Node2D:
	var delivery := effect.get("delivery", {}) as Dictionary
	var pulse_effect := effect.get("impact", {}) as Dictionary
	var pulse := AREA_PULSE_SCRIPT.new() as Node2D
	if not pulse.configure(
		caster,
		StringName(String(cast_result.get("target_id", ""))),
		float(delivery.get("radius", 0.0)),
		pulse_effect
	):
		pulse.free()
		return null
	parent.add_child(pulse)
	pulse.global_position = caster.global_position
	pulse.call("pulse")
	return pulse
