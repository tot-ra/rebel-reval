class_name MissionAllyController
extends RefCounted

## Applies scripted ally support during mission encounters (P5-008).
## Why: Act 2 missions need allies that heal or bolster the player without
## introducing party-control UI or direct-input delegation.

signal support_applied(ally_id: StringName, amount: float)

var profile: MissionAllyScript = MissionAllyScript.healer()
var _cooldown_sec: float = 0.0


func configure(script_profile: MissionAllyScript) -> void:
	profile = script_profile if script_profile != null else MissionAllyScript.healer()
	_cooldown_sec = 0.0


func tick(delta: float, ally_position: Vector2, target: Node2D) -> float:
	if delta <= 0.0 or profile == null or target == null or not is_instance_valid(target):
		return 0.0
	if ally_position.distance_to(target.global_position) > profile.support_radius:
		return 0.0
	_cooldown_sec -= delta
	if _cooldown_sec > 0.0:
		return 0.0
	_cooldown_sec = profile.heal_interval_sec
	var healed := _apply_support(target, profile.heal_amount)
	if healed > 0.0:
		support_applied.emit(profile.id, healed)
	return healed


func _apply_support(target: Node2D, amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	if target.has_method("receive_ally_support"):
		return float(target.call("receive_ally_support", amount))
	if target.get("combat_vitals") is CombatVitals:
		var vitals: CombatVitals = target.combat_vitals
		var previous := vitals.health
		vitals.health = minf(vitals.max_health, vitals.health + amount)
		var healed := vitals.health - previous
		if healed > 0.0:
			target.set("health", vitals.health)
			vitals.health_changed.emit(vitals.health, vitals.max_health)
		return healed
	return 0.0
