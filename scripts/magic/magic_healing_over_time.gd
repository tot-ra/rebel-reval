class_name MagicHealingOverTime
extends RefCounted

## Reusable deterministic healing-over-time effect. The effect owns its lifetime and
## cadence; delivery nodes only decide which actors receive it.

signal healed(amount: float)
signal expired

var amount: float = 0.0
var duration_sec: float = 0.0
var tick_interval_sec: float = 0.0
var remaining_sec: float = 0.0
var _tick_accumulator_sec: float = 0.0


func configure(effect: Dictionary) -> bool:
	amount = float(effect.get("amount", 0.0))
	duration_sec = float(effect.get("duration_sec", 0.0))
	tick_interval_sec = float(effect.get("tick_interval_sec", 0.0))
	if amount <= 0.0 or duration_sec <= 0.0 or tick_interval_sec <= 0.0:
		return false
	remaining_sec = duration_sec
	_tick_accumulator_sec = 0.0
	return true


func tick(delta: float, target: Node) -> float:
	if delta <= 0.0 or not is_active() or target == null or not is_instance_valid(target):
		return 0.0
	var elapsed := minf(delta, remaining_sec)
	remaining_sec = maxf(0.0, remaining_sec - elapsed)
	_tick_accumulator_sec += elapsed
	var total_healed := 0.0
	while _tick_accumulator_sec >= tick_interval_sec:
		_tick_accumulator_sec -= tick_interval_sec
		total_healed += apply_to(target, amount)
	if not is_active():
		expired.emit()
	return total_healed


func is_active() -> bool:
	return remaining_sec > 0.0


func remaining_duration_sec() -> float:
	return remaining_sec


## Adapts the shared combat_vitals contract without requiring spell-specific actor
## code. Actors may override this with receive_magic_heal for custom presentation.
static func apply_to(target: Node, heal_amount: float) -> float:
	if target == null or not is_instance_valid(target) or heal_amount <= 0.0:
		return 0.0
	if target.has_method("receive_magic_heal"):
		return maxf(0.0, float(target.call("receive_magic_heal", heal_amount)))
	var raw_vitals: Variant = target.get("combat_vitals")
	if not raw_vitals is CombatVitals:
		return 0.0
	var vitals: CombatVitals = raw_vitals as CombatVitals
	var previous_health := vitals.health
	vitals.health = minf(vitals.max_health, vitals.health + heal_amount)
	var healed_amount := vitals.health - previous_health
	if healed_amount <= 0.0:
		return 0.0
	target.set("health", vitals.health)
	if target.has_signal("health_changed"):
		target.emit_signal("health_changed", vitals.health, vitals.max_health)
	return healed_amount
