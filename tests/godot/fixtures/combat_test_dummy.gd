extends Node2D

class_name CombatTestDummy

var health := 20.0
var max_health := 20.0
var hit_count := 0


func _ready() -> void:
	add_to_group(&"combat_damageable")


func take_damage(amount: float, _source: Node = null) -> float:
	if amount <= 0.0 or health <= 0.0:
		return 0.0
	var previous := health
	health = clampf(health - amount, 0.0, max_health)
	var applied := previous - health
	if applied > 0.0:
		hit_count += 1
	return applied
