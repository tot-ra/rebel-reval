class_name SmithyHenning
extends CharacterBody2D

## Lightweight prologue showcase for Captain Henning. The logic body remains the
## future interaction/combat authority while MapViewRuntime mirrors it to 3D.

const WALK_SPEED := 68.0
const ARRIVAL_DISTANCE := 10.0
const IDLE_SECONDS := 2.5
const GESTURE_SECONDS := 1.35
const SIT_DOWN_SECONDS := 1.2
const SIT_IDLE_SECONDS := 3.0
const SIT_UP_SECONDS := 1.2

const ROUTE: Array[Vector2] = [
	Vector2(9.5, 11.5) * MapTypes.DEFAULT_CELL_SIZE,
	Vector2(13.5, 7.5) * MapTypes.DEFAULT_CELL_SIZE,
	# The final stop doubles as a chair-height animation showcase. A dedicated
	# chair prop can be snapped here later without changing NPC gameplay state.
	Vector2(9.5, 11.5) * MapTypes.DEFAULT_CELL_SIZE,
]

enum RoutineState {
	WALKING,
	IDLE,
	GESTURING,
	SITTING_DOWN,
	SITTING,
	STANDING_UP,
}

@export var stable_id: StringName = &"char.henning"
@export var rig_scene: PackedScene = preload("res://assets/characters/variants/henning.tscn")

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D

var _state := RoutineState.IDLE
var _state_seconds := IDLE_SECONDS
var _route_index := 0
var _last_facing := Vector2.DOWN


func _ready() -> void:
	add_to_group(&"map_view_actor")


func configure_navigation(navigation_map: RID) -> void:
	navigation_agent.set_navigation_map(navigation_map)
	_route_index = _nearest_route_index()
	_begin_walk((_route_index + 1) % ROUTE.size())


func _physics_process(delta: float) -> void:
	if _state == RoutineState.WALKING:
		_update_walk()
	else:
		velocity = Vector2.ZERO
		_state_seconds -= delta
		if _state_seconds <= 0.0:
			_advance_routine()
	move_and_slide()


func view_animation() -> StringName:
	match _state:
		RoutineState.WALKING:
			return &"walk"
		RoutineState.GESTURING:
			return &"talk_gesture"
		RoutineState.SITTING_DOWN:
			return &"sit_down"
		RoutineState.SITTING:
			return &"sit_idle"
		RoutineState.STANDING_UP:
			return &"sit_up"
		_:
			return &"idle"


func view_facing() -> Vector2:
	return velocity.normalized() if not velocity.is_zero_approx() else _last_facing


func _update_walk() -> void:
	if navigation_agent.is_navigation_finished():
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
	if _route_index == ROUTE.size() - 1:
		_set_state(RoutineState.SITTING_DOWN, SIT_DOWN_SECONDS)
	else:
		_set_state(RoutineState.IDLE, IDLE_SECONDS)


func _advance_routine() -> void:
	match _state:
		RoutineState.IDLE:
			_set_state(RoutineState.GESTURING, GESTURE_SECONDS)
		RoutineState.GESTURING:
			_begin_walk((_route_index + 1) % ROUTE.size())
		RoutineState.SITTING_DOWN:
			_set_state(RoutineState.SITTING, SIT_IDLE_SECONDS)
		RoutineState.SITTING:
			_set_state(RoutineState.STANDING_UP, SIT_UP_SECONDS)
		RoutineState.STANDING_UP:
			_begin_walk(0)


func _begin_walk(next_index: int) -> void:
	_route_index = next_index
	_set_state(RoutineState.WALKING, 0.0)
	navigation_agent.target_position = ROUTE[_route_index]


func _set_state(next_state: RoutineState, seconds: float) -> void:
	_state = next_state
	_state_seconds = seconds


func _nearest_route_index() -> int:
	var nearest := 0
	var nearest_distance := INF
	for index in ROUTE.size():
		var distance := global_position.distance_squared_to(ROUTE[index])
		if distance < nearest_distance:
			nearest = index
			nearest_distance = distance
	return nearest
