class_name SmithyHenning
extends CharacterBody2D

## Phase-gated prologue visitor driven by authored activity points (P2-060).
## Henning enters, inspects forge evidence, waits, addresses Kalev, then leaves
## instead of looping a permanent resident patrol.

const WALK_SPEED := 68.0
const ARRIVAL_DISTANCE := 10.0

const CHAIR_ROOT_OFFSET := Vector2.UP * 0.5 * MapTypes.DEFAULT_CELL_SIZE
const CHAIR_FACING := Vector2.UP

const ACTIVITY_POINTS_PATH := "res://content/routines/kalev_smithy.json"
const VISIT_ROUTINE_PATH := "res://content/routines/henning_smithy_visit.json"

const ControllerScript := preload("res://scripts/world/smithy_routine_controller.gd")
const DefinitionScript := preload("res://scripts/world/smithy_routine_definition.gd")

enum ActivityMode {
	WALKING,
	ACTING,
	SITTING_DOWN,
	SITTING,
	STANDING_UP,
}

@export var stable_id: StringName = &"char.henning"
@export var rig_scene: PackedScene = preload("res://assets/characters/variants/henning.tscn")

@onready var navigation_agent: NavigationAgent2D = get_node_or_null("NavigationAgent2D") as NavigationAgent2D

var _routine_controller: SmithyRoutineController
var _visit_active := false
var _visit_completed := false
var _phase_visible := true
var _current_activity := &""
var _activity_mode := ActivityMode.ACTING
var _activity_seconds := 0.0
var _target_position := Vector2.ZERO
var _target_facing := Vector2.DOWN
var _chair_position := Vector2.ZERO
var _last_facing := Vector2.DOWN
var _conversation_partner: Node2D = null
var _approach_reached := false


func _ready() -> void:
	CollisionLayers.apply_npc(self)
	add_to_group(&"map_view_actor")
	_ensure_routine_controller()
	if _routine_controller.get_parent() == null:
		_routine_controller.name = "HenningRoutineController"
		add_child(_routine_controller)
	_apply_visibility()


func _ensure_routine_controller() -> void:
	if _routine_controller != null:
		return
	_routine_controller = ControllerScript.new()
	_load_routine_definitions()


func set_station_reservations(reservations: Node) -> void:
	_ensure_routine_controller()
	_routine_controller.set_station_reservations(reservations)


func configure_navigation(navigation_map: RID, chair_position: Vector2) -> void:
	_chair_position = chair_position
	if navigation_agent == null:
		return
	navigation_agent.set_navigation_map(navigation_map)


func begin_prologue_visit() -> void:
	_ensure_routine_controller()
	if _visit_completed:
		return
	_visit_active = true
	_visit_completed = false
	_routine_controller.reset_runtime_state()
	global_position = _entry_position()
	_apply_visibility()
	_advance_to_next_activity()


func cancel_visit() -> void:
	_visit_active = false
	_current_activity = &""
	velocity = Vector2.ZERO
	if _routine_controller.active_activity_for(stable_id) != &"":
		_routine_controller.end_activity(stable_id, ControllerScript.REASON_CANCELLED)
	_apply_visibility()


func is_visit_complete() -> bool:
	return _visit_completed


func is_visit_active() -> bool:
	return _visit_active and not _visit_completed


func runtime_snapshot() -> Dictionary:
	return {
		"visit_active": _visit_active,
		"visit_completed": _visit_completed,
		"current_activity": String(_current_activity),
		"activity_mode": int(_activity_mode),
		"activity_seconds": _activity_seconds,
		"position": {"x": global_position.x, "y": global_position.y},
		"target_position": {"x": _target_position.x, "y": _target_position.y},
		"target_facing": {"x": _target_facing.x, "y": _target_facing.y},
		"last_facing": {"x": _last_facing.x, "y": _last_facing.y},
		"approach_reached": _approach_reached,
		"routine": _routine_controller.runtime_snapshot_for(stable_id),
	}


func restore_runtime_snapshot(snapshot: Dictionary) -> bool:
	_ensure_routine_controller()
	_visit_active = bool(snapshot.get("visit_active", false))
	_visit_completed = bool(snapshot.get("visit_completed", false))
	_current_activity = StringName(String(snapshot.get("current_activity", "")))
	_activity_mode = int(snapshot.get("activity_mode", ActivityMode.ACTING))
	_activity_seconds = maxf(float(snapshot.get("activity_seconds", 0.0)), 0.0)
	global_position = _decode_vector(snapshot.get("position", {}) as Dictionary, global_position)
	_target_position = _decode_vector(snapshot.get("target_position", {}) as Dictionary, global_position)
	_target_facing = _decode_vector(snapshot.get("target_facing", {}) as Dictionary, Vector2.DOWN)
	_last_facing = _decode_vector(snapshot.get("last_facing", {}) as Dictionary, Vector2.DOWN)
	_approach_reached = bool(snapshot.get("approach_reached", false))
	var restored := _routine_controller.restore_runtime_snapshot_for(
		stable_id,
		snapshot.get("routine", {}) as Dictionary,
		_visit_context()
	)
	_apply_visibility()
	return restored


static func _decode_vector(value: Dictionary, fallback: Vector2) -> Vector2:
	if not value.has("x") or not value.has("y"):
		return fallback
	return Vector2(float(value["x"]), float(value["y"]))


func set_conversation_partner(partner: Node2D) -> void:
	_conversation_partner = partner
	if partner != null:
		velocity = Vector2.ZERO
		if _visit_active and _current_activity != &"":
			_routine_controller.interrupt_for_dialogue(
				stable_id,
				_visit_context()
			)


func interrupt_for_dialogue(partner: Node2D) -> void:
	set_conversation_partner(partner)


func resume_after_dialogue() -> void:
	_conversation_partner = null
	if not _visit_active:
		return
	if _routine_controller.resume_after_dialogue(stable_id):
		var resumed := _routine_controller.active_activity_for(stable_id)
		if not resumed.is_empty():
			_current_activity = resumed
			_begin_current_activity(false)
			return
	_advance_to_next_activity()


func _physics_process(delta: float) -> void:
	if not _visit_active or _visit_completed:
		velocity = Vector2.ZERO
		return
	if _conversation_partner != null and is_instance_valid(_conversation_partner):
		velocity = Vector2.ZERO
		_safe_move_and_slide()
		return
	match _activity_mode:
		ActivityMode.WALKING:
			_update_walk()
		ActivityMode.ACTING:
			_activity_seconds -= delta
			if _activity_seconds <= 0.0:
				_finish_current_activity()
		ActivityMode.SITTING_DOWN:
			_activity_seconds -= delta
			if _activity_seconds <= 0.0:
				_activity_mode = ActivityMode.SITTING
				_activity_seconds = _sample_activity_duration()
		ActivityMode.SITTING:
			_activity_seconds -= delta
			if _activity_seconds <= 0.0:
				_activity_mode = ActivityMode.STANDING_UP
				_activity_seconds = 1.2
		ActivityMode.STANDING_UP:
			_activity_seconds -= delta
			if _activity_seconds <= 0.0:
				_finish_current_activity()
	_safe_move_and_slide()


func view_animation() -> StringName:
	if _conversation_partner != null and is_instance_valid(_conversation_partner):
		return &"talk_gesture"
	match _activity_mode:
		ActivityMode.WALKING:
			return &"walk"
		ActivityMode.SITTING_DOWN:
			return &"sit_down"
		ActivityMode.SITTING:
			return &"sit_idle"
		ActivityMode.STANDING_UP:
			return &"sit_up"
		_:
			if _current_activity == &"ap.visitor.inspect":
				return &"talk_gesture"
			return &"idle"


func view_facing() -> Vector2:
	if _conversation_partner != null and is_instance_valid(_conversation_partner):
		var toward_player := _conversation_partner.global_position - global_position
		if toward_player.length_squared() > 1.0:
			return toward_player.normalized()
	if _activity_mode == ActivityMode.WALKING and not velocity.is_zero_approx():
		return velocity.normalized()
	if _target_facing.length_squared() > 0.01:
		return _target_facing
	return _last_facing


func set_phase_visibility(visible_state: bool) -> void:
	_phase_visible = visible_state
	if not visible_state:
		cancel_visit()
	_apply_visibility()


func _load_routine_definitions() -> void:
	var definition := DefinitionScript.load_from_file(ACTIVITY_POINTS_PATH)
	var visit_overlay := DefinitionScript.load_from_file(VISIT_ROUTINE_PATH)
	for actor_id in visit_overlay.visitor_sequences.keys():
		definition.visitor_sequences[actor_id] = visit_overlay.visitor_sequences[actor_id]
	_routine_controller.configure(definition)


func _visit_context() -> Dictionary:
	return {
		"phase_id": GameState.PHASE_PROLOGUE_DAY,
		"time_band": &"any",
		"seed": 1343,
		"visitor_allowed": true,
	}


func _advance_to_next_activity() -> void:
	var next := _routine_controller.pick_next_activity(stable_id, _visit_context())
	if next.is_empty():
		_complete_visit()
		return
	if not _routine_controller.begin_activity(stable_id, next, _visit_context()):
		_complete_visit()
		return
	_current_activity = next
	_begin_current_activity(true)


func _begin_current_activity(walk_to_target: bool) -> void:
	var point := _routine_controller.get_activity_point(_current_activity)
	if point == null:
		_finish_current_activity()
		return
	_target_position = _resolve_target_position(point)
	_target_facing = _resolve_target_facing(point)
	_approach_reached = false
	if walk_to_target and _needs_walk_to_target():
		_activity_mode = ActivityMode.WALKING
		if navigation_agent != null:
			navigation_agent.target_position = _target_position
	else:
		_arrive_at_activity(point)


func _finish_current_activity() -> void:
	if _activity_mode == ActivityMode.SITTING or _activity_mode == ActivityMode.SITTING_DOWN:
		_activity_mode = ActivityMode.STANDING_UP
		_activity_seconds = 1.2
		return
	_routine_controller.end_activity(stable_id, ControllerScript.REASON_COMPLETED)
	if _current_activity == &"ap.visitor.leave":
		_complete_visit()
		return
	_current_activity = &""
	_advance_to_next_activity()


func _complete_visit() -> void:
	_visit_active = false
	_visit_completed = true
	_current_activity = &""
	velocity = Vector2.ZERO
	_routine_controller.end_activity(stable_id, ControllerScript.REASON_COMPLETED)
	_apply_visibility()


func _arrive_at_activity(point: SmithyActivityPoint) -> void:
	_approach_reached = true
	velocity = Vector2.ZERO
	global_position = _target_position
	_last_facing = _target_facing
	if point.body_socket == &"sit":
		_activity_mode = ActivityMode.SITTING_DOWN
		_activity_seconds = 1.2
	else:
		_activity_mode = ActivityMode.ACTING
		_activity_seconds = _sample_activity_duration()


func _needs_walk_to_target() -> bool:
	var tolerance := float(MapTypes.DEFAULT_CELL_SIZE) * 0.35
	return global_position.distance_to(_target_position) > tolerance


func _resolve_target_position(point: SmithyActivityPoint) -> Vector2:
	if point.body_socket == &"sit" and point.prop_id == &"work_chair" and _chair_position != Vector2.ZERO:
		return _chair_position + CHAIR_ROOT_OFFSET
	return point.approach_position


func _resolve_target_facing(point: SmithyActivityPoint) -> Vector2:
	if point.body_socket == &"sit" and point.prop_id == &"work_chair":
		return CHAIR_FACING
	return point.facing


func _sample_activity_duration() -> float:
	var point := _routine_controller.get_activity_point(_current_activity)
	if point == null:
		return 2.0
	return point.sample_duration_sec(1343)


func _entry_position() -> Vector2:
	var point := _routine_controller.get_activity_point(&"ap.visitor.enter")
	if point != null:
		return point.approach_position
	return global_position


func _update_walk() -> void:
	if navigation_agent == null or navigation_agent.is_navigation_finished():
		var point := _routine_controller.get_activity_point(_current_activity)
		if point != null:
			_arrive_at_activity(point)
		return
	var next_position := navigation_agent.get_next_path_position()
	var direction := global_position.direction_to(next_position)
	if direction.is_zero_approx():
		var point := _routine_controller.get_activity_point(_current_activity)
		if point != null:
			_arrive_at_activity(point)
		return
	velocity = direction * WALK_SPEED
	_last_facing = direction


func _apply_visibility() -> void:
	var show := _phase_visible and _visit_active and not _visit_completed
	visible = show
	set_physics_process(show)


func _safe_move_and_slide() -> void:
	if not is_inside_tree() or get_world_2d() == null:
		return
	move_and_slide()
