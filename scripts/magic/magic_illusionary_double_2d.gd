class_name MagicIllusionaryDouble2D
extends Area2D

## Damageable decoy summoned from an authored effect plan. It remembers each
## affected enemy's target so cleanup restores AI state instead of merely
## deleting the node and leaving dangling target references.

signal health_changed(current: float, maximum: float)
signal expired(reason: StringName)

const AI_ENEMY_GROUP := &"combat_ai_enemy"
const DAMAGEABLE_GROUP := &"combat_damageable"
const EXPIRE_LIFETIME := &"lifetime"
const EXPIRE_DESTROYED := &"destroyed"

var source: Node2D
var spell_id: StringName = &""
var lifetime_sec := 0.0
var remaining_sec := 0.0
var health := 0.0
var max_health := 0.0
var collision_radius := 0.0
var aggro_radius := 0.0
var active := false

var _original_targets: Dictionary = {}


func configure(caster: Node2D, cast_spell_id: StringName, summon_plan: Dictionary) -> bool:
	var authored_lifetime := float(summon_plan.get("lifetime_sec", 0.0))
	var authored_health := float(summon_plan.get("health", 0.0))
	var authored_collision_radius := float(summon_plan.get("collision_radius", 0.0))
	var authored_aggro_radius := float(summon_plan.get("aggro_radius", 0.0))
	if (
		caster == null
		or authored_lifetime <= 0.0
		or authored_health <= 0.0
		or authored_collision_radius <= 0.0
		or authored_aggro_radius <= 0.0
	):
		return false
	source = caster
	spell_id = cast_spell_id
	lifetime_sec = authored_lifetime
	remaining_sec = authored_lifetime
	health = authored_health
	max_health = authored_health
	collision_radius = authored_collision_radius
	aggro_radius = authored_aggro_radius
	monitoring = true
	monitorable = true
	collision_layer = CollisionLayers.PLAYER
	collision_mask = CollisionLayers.MASK_PLAYER
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = collision_radius
	shape.shape = circle
	add_child(shape)
	add_to_group(DAMAGEABLE_GROUP)
	active = true
	queue_redraw()
	return true


## Activation happens after the executor adds the decoy to the SceneTree, so
## enemy discovery and global positions are valid in both gameplay and tests.
func activate() -> int:
	if not active or not is_inside_tree():
		return 0
	return _redirect_nearby_enemies()


func _physics_process(delta: float) -> void:
	advance(delta)


## Public deterministic step avoids frame timing in lifecycle tests.
func advance(delta: float) -> void:
	if not active or delta <= 0.0:
		return
	remaining_sec = maxf(0.0, remaining_sec - delta)
	if remaining_sec <= 0.0:
		_expire(EXPIRE_LIFETIME)
		return
	# Re-scan while alive so enemies entering the authored aggro radius can
	# acquire the decoy without overwriting the target remembered at first sight.
	_redirect_nearby_enemies()


func _exit_tree() -> void:
	# External scene teardown/free must obey the same target cleanup contract as
	# lifetime expiry and damage destruction.
	active = false
	_restore_targets()


func _redirect_nearby_enemies() -> int:
	var redirected := 0
	for candidate: Node in get_tree().get_nodes_in_group(AI_ENEMY_GROUP):
		var enemy := candidate as Node2D
		if not _can_redirect(enemy):
			continue
		var enemy_id := enemy.get_instance_id()
		if _original_targets.has(enemy_id):
			continue
		_original_targets[enemy_id] = {
			"enemy": enemy,
			"target": enemy.call("get_ai_target"),
		}
		enemy.call("set_ai_target", self)
		redirected += 1
	return redirected


func take_damage(
	amount: float,
	_source: Node = null,
	_damage_type: StringName = &"",
	_swing_id: int = 0,
	_pierces_guard: bool = false
) -> float:
	if not active or amount <= 0.0:
		return 0.0
	var applied := minf(amount, health)
	health -= applied
	health_changed.emit(health, max_health)
	if health <= 0.0:
		_expire(EXPIRE_DESTROYED)
	return applied


func _can_redirect(enemy: Node2D) -> bool:
	return (
		enemy != null
		and enemy != source
		and enemy.has_method("get_ai_target")
		and enemy.has_method("set_ai_target")
		and global_position.distance_to(enemy.global_position) <= aggro_radius
	)


func _expire(reason: StringName) -> void:
	if not active:
		return
	active = false
	_restore_targets()
	expired.emit(reason)
	queue_free()


func _restore_targets() -> void:
	for entry_value: Variant in _original_targets.values():
		var entry := entry_value as Dictionary
		var enemy := entry.get("enemy") as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		# Do not overwrite a newer combat decision made while the decoy lived.
		if enemy.call("get_ai_target") == self:
			enemy.call("set_ai_target", entry.get("target") as Node2D)
	_original_targets.clear()


func _draw() -> void:
	var outline := Color(0.46, 0.72, 0.9, 0.85)
	draw_circle(Vector2.ZERO, collision_radius, Color(0.25, 0.5, 0.78, 0.22))
	draw_arc(Vector2.ZERO, collision_radius, 0.0, TAU, 32, outline, 2.0)
	draw_line(Vector2(0.0, -collision_radius), Vector2(0.0, collision_radius), outline, 2.0)
