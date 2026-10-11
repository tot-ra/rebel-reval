class_name MagicHealingOverTime
extends RefCounted

## Reusable deterministic healing-over-time effect (`kind: heal_over_time`).
## The effect owns its per-target heal budget and cadence; delivery nodes only
## decide which actors receive it and when it advances.

signal healed(amount: float)
signal expired

const KIND := "heal_over_time"

var amount: float = 0.0
var duration_sec: float = 0.0
var tick_interval_sec: float = 0.0
var remaining_sec: float = 0.0
var _tick_accumulator_sec: float = 0.0


func configure(effect: Dictionary) -> bool:
	if String(effect.get("kind", "")) != KIND:
		return false
	amount = float(effect.get("amount", 0.0))
	duration_sec = float(effect.get("duration_sec", 0.0))
	tick_interval_sec = float(effect.get("tick_interval_sec", 0.0))
	if amount <= 0.0 or duration_sec <= 0.0 or tick_interval_sec <= 0.0:
		return false
	remaining_sec = duration_sec
	_tick_accumulator_sec = 0.0
	return true


## Advances the effect by `delta` and applies every tick that falls inside it.
## Large deltas apply the same ticks as many small ones, so results do not
## depend on frame rate. Returns the health actually restored.
func tick(delta: float, target: Node) -> float:
	if delta <= 0.0 or not is_active() or not can_receive(target):
		return 0.0
	var elapsed := minf(delta, remaining_sec)
	remaining_sec = maxf(0.0, remaining_sec - elapsed)
	_tick_accumulator_sec += elapsed
	var total_healed := 0.0
	# The small epsilon keeps a tick that lands exactly on the expiry boundary
	# (e.g. 6 s / 1 s) from being lost to float accumulation error.
	while _tick_accumulator_sec + 0.000001 >= tick_interval_sec:
		_tick_accumulator_sec = maxf(0.0, _tick_accumulator_sec - tick_interval_sec)
		total_healed += apply_to(target, amount)
	if total_healed > 0.0:
		healed.emit(total_healed)
	if not is_active():
		expired.emit()
	return total_healed


func is_active() -> bool:
	return remaining_sec > 0.0


func remaining_duration_sec() -> float:
	return remaining_sec


## True for living actors that expose either the custom heal hook or shared vitals.
static func can_receive(target: Node) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if target.has_method("receive_magic_heal"):
		return true
	var raw_vitals: Variant = target.get("combat_vitals")
	if not raw_vitals is CombatVitals:
		return false
	return not (raw_vitals as CombatVitals).is_dead() and _field_health(target, raw_vitals) > 0.0


## Adapts the shared combat_vitals contract without requiring spell-specific actor
## code. Actors that mirror vitals into their own fields (player, HUD bars) may
## implement receive_magic_heal(amount) -> float instead.
static func apply_to(target: Node, heal_amount: float) -> float:
	if target == null or not is_instance_valid(target) or heal_amount <= 0.0:
		return 0.0
	if target.has_method("receive_magic_heal"):
		return maxf(0.0, float(target.call("receive_magic_heal", heal_amount)))
	var raw_vitals: Variant = target.get("combat_vitals")
	if not raw_vitals is CombatVitals:
		return 0.0
	var vitals: CombatVitals = raw_vitals as CombatVitals
	# Combat actors keep a `health` field that is authoritative between hits.
	vitals.health = _field_health(target, vitals)
	var healed_amount := vitals.heal(heal_amount)
	if healed_amount <= 0.0:
		return 0.0
	if target.get("health") != null:
		target.set("health", vitals.health)
	if target.has_signal("health_changed"):
		target.emit_signal("health_changed", vitals.health, vitals.max_health)
	return healed_amount


static func _field_health(target: Node, vitals: CombatVitals) -> float:
	var field: Variant = target.get("health")
	if field is float or field is int:
		return float(field)
	return vitals.health
