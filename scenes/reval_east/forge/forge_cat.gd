class_name ForgeCat
extends CharacterBody2D

## Kalev's forge cat: resident animal driven by authored cat-only activity points (P2-061).
## Sleep, groom, warmth-seeking, and feeding anchors never claim human stations.

const WALK_SPEED := 14.0

const ACTIVITY_POINTS_PATH := "res://content/routines/kalev_smithy.json"
const ROUTINE_OVERLAY_PATH := "res://content/routines/forge_cat.json"

const ControllerScript := preload("res://scripts/world/smithy_routine_controller.gd")
const DefinitionScript := preload("res://scripts/world/smithy_routine_definition.gd")
const MartScript := preload("res://scenes/reval_east/forge/smithy_mart.gd")

enum ActivityMode {
	WALKING,
	ACTING,
}

@export var stable_id: StringName = &"char.forge_cat"
@export var rig_scene: PackedScene = preload("res://assets/storybook/forge_cat.tscn")

@onready var navigation_agent: NavigationAgent2D = get_node_or_null("NavigationAgent2D") as NavigationAgent2D

var _routine_controller: SmithyRoutineController
var _routine_active := false
var _phase_id: StringName = GameState.PHASE_PROLOGUE_DAY
var _time_band: StringName = &"any"
var _current_activity := &""
var _activity_mode := ActivityMode.ACTING
var _activity_seconds := 0.0
var _target_position := Vector2.ZERO
var _target_facing := Vector2.DOWN
var _last_facing := Vector2.DOWN
var _conversation_partner: Node2D = null
var _idle_retry_seconds := 0.0


func _ready() -> void:
	CollisionLayers.apply_npc(self)
	add_to_group(&"map_view_actor")
	_ensure_routine_controller()
	if _routine_controller.get_parent() == null:
		_routine_controller.name = "CatRoutineController"
		add_child(_routine_controller)


func configure_navigation(navigation_map: RID) -> void:
	if navigation_agent == null:
		return
	navigation_agent.set_navigation_map(navigation_map)
	_refresh_routine_state()


func set_routine_context(phase_id: StringName, time_band: StringName = &"any") -> void:
	_phase_id = phase_id
	_time_band = time_band
	_refresh_routine_state()


func set_conversation_partner(partner: Node2D) -> void:
	_conversation_partner = partner
	if partner != null:
		velocity = Vector2.ZERO


func _physics_process(delta: float) -> void:
	if not _routine_active:
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
		_:
			_idle_retry_seconds -= delta
			if _idle_retry_seconds <= 0.0:
				_advance_to_next_activity()
	_safe_move_and_slide()


func view_animation() -> StringName:
	if _conversation_partner != null and is_instance_valid(_conversation_partner):
		return &"idle"
	match _activity_mode:
		ActivityMode.WALKING:
			return &"walk"
		_:
			match _current_activity:
				&"ap.cat.sleep", &"ap.cat.warmth":
					return &"sleep"
				&"ap.cat.groom", &"ap.cat.feed":
					return &"lick"
				_:
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


func view_glyph_height() -> float:
	return 0.68


func current_activity() -> StringName:
	return _current_activity


func _refresh_routine_state() -> void:
	var should_run := _has_authored_schedule()
	if should_run and not _routine_active:
		_routine_active = true
		_routine_controller.reset_runtime_state()
		_advance_to_next_activity()
	elif not should_run and _routine_active:
		_stop_routine()
	set_physics_process(_routine_active)


func _has_authored_schedule() -> bool:
	if _routine_controller == null or _routine_controller.definition == null:
		return false
	var sequence := _routine_controller.definition.schedule_for(stable_id, _phase_id, _time_band)
	if not sequence.is_empty():
		return true
	return _routine_controller.definition.schedule_for(stable_id, _phase_id, &"any").size() > 0


func _stop_routine() -> void:
	_routine_active = false
	_current_activity = &""
	velocity = Vector2.ZERO
	if _routine_controller.active_activity_for(stable_id) != &"":
		_routine_controller.end_activity(stable_id, ControllerScript.REASON_CANCELLED)


func _ensure_routine_controller() -> void:
	if _routine_controller != null:
		return
	_routine_controller = ControllerScript.new()
	_load_routine_definitions()


func _load_routine_definitions() -> void:
	var definition := MartScript._merge_routine_overlay(ACTIVITY_POINTS_PATH, ROUTINE_OVERLAY_PATH)
	_routine_controller.configure(definition)


func _routine_context() -> Dictionary:
	return {
		"phase_id": _phase_id,
		"time_band": _time_band,
		"seed": 1343,
	}


func _advance_to_next_activity() -> void:
	var next := _routine_controller.pick_next_activity(stable_id, _routine_context())
	if next.is_empty():
		_current_activity = &""
		_activity_mode = ActivityMode.ACTING
		_idle_retry_seconds = 2.0
		return
	if not _routine_controller.begin_activity(stable_id, next, _routine_context()):
		_idle_retry_seconds = 2.0
		return
	_current_activity = next
	_begin_current_activity(true)


func _begin_current_activity(walk_to_target: bool) -> void:
	var point := _routine_controller.get_activity_point(_current_activity)
	if point == null:
		_finish_current_activity()
		return
	_target_position = point.approach_position
	_target_facing = point.facing
	if walk_to_target and _needs_walk_to_target():
		_activity_mode = ActivityMode.WALKING
		if navigation_agent != null:
			navigation_agent.target_position = _target_position
	else:
		_arrive_at_activity(point)


func _finish_current_activity() -> void:
	_routine_controller.end_activity(stable_id, ControllerScript.REASON_COMPLETED)
	_current_activity = &""
	_advance_to_next_activity()


func _arrive_at_activity(point: SmithyActivityPoint) -> void:
	velocity = Vector2.ZERO
	global_position = _target_position
	_last_facing = _target_facing
	_activity_mode = ActivityMode.ACTING
	_activity_seconds = _sample_activity_duration()


func _needs_walk_to_target() -> bool:
	var tolerance := float(MapTypes.DEFAULT_CELL_SIZE) * 0.35
	return global_position.distance_to(_target_position) > tolerance


func _sample_activity_duration() -> float:
	var point := _routine_controller.get_activity_point(_current_activity)
	if point == null:
		return 2.0
	return point.sample_duration_sec(1343)


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


func _safe_move_and_slide() -> void:
	if not is_inside_tree() or get_world_2d() == null:
		return
	move_and_slide()
