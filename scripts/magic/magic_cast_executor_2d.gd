class_name MagicCastExecutor2D
extends RefCounted

## Bridges validated/resourced cast results into reusable world delivery nodes.

const PROJECTILE_SCRIPT := preload("res://scripts/magic/magic_projectile_2d.gd")
const AREA_PULSE_SCRIPT_PATH := "res://scripts/magic/magic_area_pulse_2d.gd"
const ILLUSIONARY_DOUBLE_SCRIPT := preload("res://scripts/magic/magic_illusionary_double_2d.gd")


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
	if delivery_kind == "persistent_area":
		return _execute_persistent_area(cast_result, caster, parent, effect_dict)
	if delivery_kind == "summon":
		return _execute_summon(cast_result, caster, direction, parent, effect_dict)
	if delivery_kind == "self":
		return _execute_self(cast_result, caster, effect_dict)
	return null


## Self delivery spawns nothing: the authored modifier module lands on the
## caster's own vitals. Returns the caster on success so callers can treat the
## result like any other delivery that entered the world.
static func _execute_self(cast_result: Dictionary, caster: Node2D, effect: Dictionary) -> Node2D:
	var module: Variant = effect.get("modifier", {})
	if not module is Dictionary:
		return null
	if not CombatTimedModifiers.apply_module_to(
		caster, module as Dictionary, StringName(String(cast_result.get("target_id", "")))
	):
		return null
	return caster


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
	var pulse_script := load(AREA_PULSE_SCRIPT_PATH) as Script
	if pulse_script == null:
		return null
	var pulse := pulse_script.new() as Node2D
	var pulse_effect := effect.get("impact", {}) as Dictionary
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


## Persistent areas stay at the cast point and advance on their own _process.
static func _execute_persistent_area(
	cast_result: Dictionary,
	caster: Node2D,
	parent: Node,
	effect: Dictionary
) -> Node2D:
	var delivery := effect.get("delivery", {}) as Dictionary
	var impact: Variant = effect.get("impact", {})
	if not impact is Dictionary:
		return null
	var area := MagicPersistentArea2D.new()
	if not area.configure(
		caster,
		StringName(String(cast_result.get("target_id", ""))),
		float(delivery.get("radius", 0.0)),
		delivery,
		impact as Dictionary
	):
		area.free()
		return null
	parent.add_child(area)
	area.global_position = caster.global_position
	return area


static func _execute_summon(
	cast_result: Dictionary,
	caster: Node2D,
	direction: Vector2,
	parent: Node,
	effect: Dictionary
) -> Node2D:
	var delivery := effect.get("delivery", {}) as Dictionary
	if String(delivery.get("summon_kind", "")) != "illusionary_double":
		return null
	var summon := ILLUSIONARY_DOUBLE_SCRIPT.new() as Node2D
	if not summon.call(
		"configure",
		caster,
		StringName(String(cast_result.get("target_id", ""))),
		delivery
	):
		summon.free()
		return null
	parent.add_child(summon)
	var spawn_offset := float(delivery.get("spawn_offset", 0.0))
	var spawn_direction := direction.normalized()
	if spawn_direction.is_zero_approx():
		spawn_direction = Vector2.RIGHT
	summon.global_position = caster.global_position + spawn_direction * spawn_offset
	summon.call("activate")
	return summon
