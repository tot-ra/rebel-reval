class_name ForgeCat
extends CharacterBody2D

## Placeholder/demo NPC: Kalev's forge cat.
## Moves around the smithy, sleeps, grooms, and stretches.

const WALK_SPEED := 52.0
const ARRIVAL_DISTANCE := 8.0
const IDLE_SECONDS := 1.5
const SLEEP_SECONDS := 4.0
const LICK_SECONDS := 3.0
const STRETCH_SECONDS := 2.0

const SPOTS: Array[Vector2] = [
	Vector2(6.5, 11.5) * MapTypes.DEFAULT_CELL_SIZE,
	Vector2(12.5, 6.5) * MapTypes.DEFAULT_CELL_SIZE,
	Vector2(20.5, 10.5) * MapTypes.DEFAULT_CELL_SIZE,
	Vector2(22.5, 6.5) * MapTypes.DEFAULT_CELL_SIZE,
	Vector2(8.5, 8.5) * MapTypes.DEFAULT_CELL_SIZE,
]

enum RoutineState {
	IDLE,
	WALKING,
	SLEEPING,
	LICKING,
	STRETCHING,
}

@export var stable_id: StringName = &"char.forge_cat"
@export var rig_scene: PackedScene = preload("res://assets/characters/cat/cat_rig.tscn")

@onready var navigation_agent: NavigationAgent2D = get_node_or_null("NavigationAgent2D") as NavigationAgent2D

var _state := RoutineState.IDLE
var _state_seconds := IDLE_SECONDS
var _last_facing := Vector2.DOWN
var _conversation_partner: Node2D = null


func _ready() -> void:
	CollisionLayers.apply_npc(self)
	add_to_group(&"map_view_actor")


func configure_navigation(navigation_map: RID) -> void:
	# Tests may construct the script without the packed scene's NavigationAgent2D.
	if navigation_agent == null:
		return
	navigation_agent.set_navigation_map(navigation_map)
	_begin_walk(_random_spot_index())


func set_conversation_partner(partner: Node2D) -> void:
	_conversation_partner = partner
	if partner != null:
		velocity = Vector2.ZERO


func _physics_process(delta: float) -> void:
	if _conversation_partner != null and is_instance_valid(_conversation_partner):
		velocity = Vector2.ZERO
		_safe_move_and_slide()
		return
	match _state:
		RoutineState.WALKING:
			_update_walk()
		_:
			velocity = Vector2.ZERO
			_state_seconds -= delta
			if _state_seconds <= 0.0:
				_advance_routine()
	_safe_move_and_slide()


func _safe_move_and_slide() -> void:
	# Unit tests call _physics_process on out-of-tree hosts; PhysicsServer needs a space.
	if not is_inside_tree() or get_world_2d() == null:
		return
	move_and_slide()


func view_animation() -> StringName:
	if _conversation_partner != null and is_instance_valid(_conversation_partner):
		return &"idle"
	match _state:
		RoutineState.WALKING:
			return &"walk"
		RoutineState.SLEEPING:
			return &"sleep"
		RoutineState.LICKING:
			return &"lick"
		RoutineState.STRETCHING:
			return &"stretch"
		_:
			return &"idle"


func view_facing() -> Vector2:
	if _conversation_partner != null and is_instance_valid(_conversation_partner):
		var toward_player := _conversation_partner.global_position - global_position
		if toward_player.length_squared() > 1.0:
			return toward_player.normalized()
	return velocity.normalized() if not velocity.is_zero_approx() else _last_facing


func view_glyph_height() -> float:
	return CatRig.view_glyph_height()


func _update_walk() -> void:
	if navigation_agent == null or navigation_agent.is_navigation_finished():
		_arrive()
		return
	var next_position := navigation_agent.get_next_path_position()
	var direction := global_position.direction_to(next_position)
	if direction.is_zero_approx():
		_arrive()
		return
	velocity = direction * WALK_SPEED
	_last_facing = direction


func _arrive() -> void:
	velocity = Vector2.ZERO
	var next_state := _random_rest_state()
	_set_state(next_state, _rest_seconds(next_state))


func _advance_routine() -> void:
	match _state:
		RoutineState.IDLE, RoutineState.SLEEPING, RoutineState.LICKING, RoutineState.STRETCHING:
			_begin_walk(_random_spot_index())


func _begin_walk(spot_index: int) -> void:
	_set_state(RoutineState.WALKING, 0.0)
	if navigation_agent != null:
		navigation_agent.target_position = SPOTS[spot_index]


func _set_state(next_state: RoutineState, seconds: float) -> void:
	_state = next_state
	_state_seconds = seconds


func _random_spot_index() -> int:
	return randi() % SPOTS.size()


func _random_rest_state() -> RoutineState:
	var roll := randf()
	if roll < 0.25:
		return RoutineState.SLEEPING
	if roll < 0.50:
		return RoutineState.LICKING
	if roll < 0.75:
		return RoutineState.STRETCHING
	return RoutineState.IDLE


func _rest_seconds(state: RoutineState) -> float:
	match state:
		RoutineState.SLEEPING:
			return SLEEP_SECONDS
		RoutineState.LICKING:
			return LICK_SECONDS
		RoutineState.STRETCHING:
			return STRETCH_SECONDS
		_:
			return IDLE_SECONDS
