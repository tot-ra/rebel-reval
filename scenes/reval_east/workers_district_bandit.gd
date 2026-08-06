class_name WorkersDistrictBandit
extends CombatRoomEnemy

## Persistent hostile actor for the Workers' District. The 2D body owns combat
## positions and damage; MapViewRuntime mirrors this node into the bandit rig so
## the same enemy can be encountered in the 3D district without a second combat
## implementation.

const BANDIT_RIG_SCENE := preload("res://assets/characters/variants/bandit.tscn")

@export var rig_scene: PackedScene = BANDIT_RIG_SCENE
@export var stable_id: StringName = &"enemy.bandit.workers_district"

var _last_facing := Vector2.LEFT
var _bandit_target: Node2D
## MapViewRuntime reads this common field for locomotion scaling on every actor.
var velocity: Vector2 = Vector2.ZERO


func _ready() -> void:
	super()
	add_to_group(&"map_view_actor")
	add_to_group(&"workers_district_enemy")


func configure_bandit(target: Node2D = null) -> void:
	configure(EnemyArchetype.bandit(), Color(0.32, 0.14, 0.10, 1.0))
	set_ai_target(target)
	_bandit_target = target
	_last_facing = Vector2.LEFT


func _physics_process(delta: float) -> void:
	if machine.is_dead():
		return
	tick_ai(delta)


func view_facing() -> Vector2:
	if _bandit_target != null and is_instance_valid(_bandit_target):
		var toward_player := _bandit_target.global_position - global_position
		if toward_player.length_squared() > 1.0:
			return toward_player.normalized()
	return _last_facing


func view_animation() -> StringName:
	if machine.is_dead():
		return &"fall"
	match machine.state:
		EnemyCombatState.State.ATTACK:
			return machine.archetype.attack_animation
		EnemyCombatState.State.REACT:
			return &"hit"
		EnemyCombatState.State.PATROL, EnemyCombatState.State.DISENGAGE:
			return &"walk"
		_:
			return &"guard" if machine.state == EnemyCombatState.State.TELEGRAPH else &"idle"


func is_pushable_by_player() -> bool:
	return false
