class_name WorkersDistrictBandit
extends CombatRoomEnemy

## Persistent hostile actor for the Workers' District. The 2D body owns combat
## positions and damage; MapViewRuntime mirrors this node into the bandit rig so
## the same enemy can be encountered in the 3D district without a second combat
## implementation.

const BANDIT_RIG_SCENE := preload("res://assets/characters/variants/bandit.tscn")

@export var rig_scene: PackedScene = BANDIT_RIG_SCENE
@export var stable_id: StringName = &"enemy.bandit.workers_district"
@export var chase_speed: float = 125.0
@export var retreat_speed: float = 150.0
@export var retreat_distance: float = 180.0

var _last_facing := Vector2.LEFT
var _bandit_target: Node2D
var _home_position := Vector2.ZERO
## MapViewRuntime reads this common field for locomotion scaling on every actor.
var velocity: Vector2 = Vector2.ZERO

@onready var navigation_agent: NavigationAgent2D = get_node_or_null("NavigationAgent2D")


func _ready() -> void:
	super()
	add_to_group(&"map_view_actor")
	add_to_group(&"workers_district_enemy")
	_home_position = global_position


func configure_bandit(target: Node2D = null) -> void:
	configure(EnemyArchetype.bandit(), Color(0.32, 0.14, 0.10, 1.0))
	set_ai_target(target)
	_bandit_target = target
	_home_position = global_position
	_last_facing = Vector2.LEFT
	velocity = Vector2.ZERO


func set_navigation_map(map: RID) -> void:
	if navigation_agent != null and map.is_valid():
		navigation_agent.set_navigation_map(map)


func _physics_process(delta: float) -> void:
	if machine.is_dead():
		velocity = Vector2.ZERO
		return
	tick_ai(delta)
	_update_motion(delta)


func _update_motion(delta: float) -> void:
	velocity = Vector2.ZERO
	if delta <= 0.0 or _bandit_target == null or not is_instance_valid(_bandit_target):
		return
	match machine.state:
		EnemyCombatState.State.CHASE:
			_move_toward_position(_bandit_target.global_position, chase_speed, delta)
		EnemyCombatState.State.RETREAT:
			var away := global_position - _bandit_target.global_position
			if away.is_zero_approx():
				away = global_position - _home_position
			if away.is_zero_approx():
				away = Vector2.LEFT
			_move_toward_position(global_position + away.normalized() * retreat_distance, retreat_speed, delta)
		_:
			pass
	if not velocity.is_zero_approx():
		_last_facing = velocity.normalized()


func _move_toward_position(destination: Vector2, speed: float, delta: float) -> void:
	var waypoint := destination
	if navigation_agent != null and navigation_agent.get_navigation_map().is_valid():
		navigation_agent.target_position = destination
		if not navigation_agent.is_navigation_finished():
			var next_path_position := navigation_agent.get_next_path_position()
			# The server may need one sync frame after a map is assigned. Do not freeze
			# the enemy while it temporarily reports the actor's current position.
			if not next_path_position.is_equal_approx(global_position):
				waypoint = next_path_position
	var direction := waypoint - global_position
	if direction.is_zero_approx():
		return
	velocity = direction.normalized() * speed
	# This actor is a lightweight Node2D logic proxy. Navigation supplies the safe
	# route while the mirrored 3D rig remains presentation-only.
	global_position += velocity * delta


func view_facing() -> Vector2:
	if not velocity.is_zero_approx():
		return velocity.normalized()
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
		EnemyCombatState.State.CHASE, EnemyCombatState.State.RETREAT:
			return &"run"
		EnemyCombatState.State.DISENGAGE:
			return &"walk"
		EnemyCombatState.State.TELEGRAPH:
			return &"guard"
		_:
			return &"idle"


func is_pushable_by_player() -> bool:
	return false
