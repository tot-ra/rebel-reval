extends Node2D

class_name CombatTestDummy

## Minimal combat actor used by headless tests. Shares CombatVitals with Player
## so guard/parry/dodge/death resolution is exercised on a non-player body.

signal died
signal health_changed(current: float, maximum: float)

var health := 20.0
var max_health := 20.0
var stamina := 40.0
var max_stamina := 40.0
var hit_count := 0
var last_result: CombatHitResult
var combat_vitals := CombatVitals.new()
var defense_pose := CombatDefensePose.open()


func _ready() -> void:
	add_to_group(&"combat_damageable")
	combat_vitals.configure(health, max_health, stamina, max_stamina)
	if not combat_vitals.died.is_connected(_on_died):
		combat_vitals.died.connect(_on_died)


func _process(delta: float) -> void:
	combat_vitals.tick(delta)


func set_guarding(guarding: bool, elapsed_sec: float = 0.0) -> void:
	defense_pose.is_guarding = guarding
	defense_pose.guard_elapsed_sec = maxf(0.0, elapsed_sec)
	defense_pose.is_action_invulnerable = false


func set_dodging(dodging: bool) -> void:
	defense_pose.is_action_invulnerable = dodging
	if dodging:
		defense_pose.is_guarding = false


func take_damage(
	amount: float,
	_source: Node = null,
	_damage_type: StringName = &"",
	swing_id: int = 0,
	pierces_guard: bool = false
) -> float:
	combat_vitals.health = health
	combat_vitals.max_health = max_health
	combat_vitals.stamina = stamina
	combat_vitals.max_stamina = max_stamina
	var result := combat_vitals.resolve_hit(amount, defense_pose, swing_id, pierces_guard)
	last_result = result
	health = combat_vitals.health
	stamina = combat_vitals.stamina
	if result.health_damage > 0.0:
		hit_count += 1
		health_changed.emit(health, max_health)
	return result.health_damage


func _on_died() -> void:
	died.emit()
