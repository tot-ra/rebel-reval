extends Node2D

class_name CombatTestDummy

## Shared combat actor for headless tests and the P1-024 combat room.
## Uses CombatVitals so guard/parry/dodge/death match the player contracts.

signal died
signal health_changed(current: float, maximum: float)
signal hit_resolved(result: CombatHitResult)

var health := 20.0
var max_health := 20.0
var stamina := 40.0
var max_stamina := 40.0
var hit_count := 0
var last_result: CombatHitResult
var combat_vitals := CombatVitals.new()
var defense_pose := CombatDefensePose.open()
var display_name := "Dummy"


func _ready() -> void:
	add_to_group(&"combat_damageable")
	combat_vitals.configure(health, max_health, stamina, max_stamina)
	if not combat_vitals.died.is_connected(_on_died):
		combat_vitals.died.connect(_on_died)


func _process(delta: float) -> void:
	combat_vitals.tick(delta)


func configure_resources(
	current_health: float,
	health_cap: float,
	current_stamina: float,
	stamina_cap: float
) -> void:
	health = current_health
	max_health = health_cap
	stamina = current_stamina
	max_stamina = stamina_cap
	combat_vitals.configure(health, max_health, stamina, max_stamina)
	hit_count = 0
	last_result = null


func set_guarding(guarding: bool, elapsed_sec: float = 0.0) -> void:
	defense_pose.is_guarding = guarding
	defense_pose.guard_elapsed_sec = maxf(0.0, elapsed_sec)
	defense_pose.is_action_invulnerable = false


func set_dodging(dodging: bool) -> void:
	defense_pose.is_action_invulnerable = dodging
	if dodging:
		defense_pose.is_guarding = false


func clear_hit_invulnerability() -> void:
	combat_vitals.tick(combat_vitals.hit_invulnerability_sec + 0.05)
	combat_vitals.reset_swing_tracking()


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
	hit_resolved.emit(result)
	if result.health_damage > 0.0:
		hit_count += 1
		health_changed.emit(health, max_health)
	return result.health_damage


func _on_died() -> void:
	died.emit()
