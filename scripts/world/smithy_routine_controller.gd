class_name SmithyRoutineController
extends Node

## Reserves smithy activity points, selects deterministic schedules, and handles
## dialogue interruption without coordinate-only patrol loops (P2-058).

signal activity_began(actor_id: StringName, activity_id: StringName)
signal activity_ended(actor_id: StringName, activity_id: StringName, reason: StringName)

const REASON_COMPLETED := &"completed"
const REASON_CANCELLED := &"cancelled"
const REASON_INTERRUPTED := &"interrupted"
const REASON_BLOCKED := &"blocked"
const REASON_NAVIGATION_FAILED := &"navigation_failed"

const FLAG_MART_MISSING := &"mart_missing"

const PointScript := preload("res://scripts/world/smithy_activity_point.gd")
const DefinitionScript := preload("res://scripts/world/smithy_routine_definition.gd")

var definition: SmithyRoutineDefinition

var _occupants: Dictionary = {}
var _active_assignments: Dictionary = {}
var _schedule_indices: Dictionary = {}
var _interrupted_states: Dictionary = {}
var _dialogue_hold: Dictionary = {}


func _ready() -> void:
	if definition == null:
		definition = DefinitionScript.load_from_file()


func configure(next_definition: SmithyRoutineDefinition) -> void:
	definition = next_definition
	reset_runtime_state()


func reset_runtime_state() -> void:
	_occupants.clear()
	_active_assignments.clear()
	_schedule_indices.clear()
	_interrupted_states.clear()
	_dialogue_hold.clear()


func get_activity_point(activity_id: StringName) -> SmithyActivityPoint:
	if definition == null:
		return null
	return definition.get_activity_point(activity_id)


func is_occupied(activity_id: StringName) -> bool:
	return _occupants.has(activity_id)


func occupant_of(activity_id: StringName) -> StringName:
	return _occupants.get(activity_id, &"")


func active_activity_for(actor_id: StringName) -> StringName:
	return _active_assignments.get(actor_id, &"")


func can_begin(actor_id: StringName, activity_id: StringName, context: Dictionary) -> bool:
	if definition == null or activity_id.is_empty():
		return false
	if _dialogue_hold.get(actor_id, false):
		return false
	if not _active_assignments.get(actor_id, &"").is_empty():
		return false
	var point := definition.get_activity_point(activity_id)
	if point == null:
		return false
	if not point.allows_actor(actor_id):
		return false
	var phase_id: StringName = context.get("phase_id", GameState.PHASE_PROLOGUE_DAY)
	if not point.allows_phase(phase_id):
		return false
	var time_band: StringName = context.get("time_band", &"any")
	if not point.allows_time_band(time_band):
		return false
	if not _actor_present(actor_id, context):
		return false
	if point.exclusive and is_occupied(activity_id):
		return occupant_of(activity_id) == actor_id
	return true


func begin_activity(actor_id: StringName, activity_id: StringName, context: Dictionary) -> bool:
	if not can_begin(actor_id, activity_id, context):
		return false
	var point := definition.get_activity_point(activity_id)
	if point == null:
		return false
	if point.exclusive:
		_occupants[activity_id] = actor_id
	_active_assignments[actor_id] = activity_id
	activity_began.emit(actor_id, activity_id)
	return true


func end_activity(actor_id: StringName, reason: StringName = REASON_COMPLETED) -> void:
	var activity_id: StringName = _active_assignments.get(actor_id, &"")
	if activity_id.is_empty():
		return
	if _occupants.get(activity_id, &"") == actor_id:
		_occupants.erase(activity_id)
	_active_assignments.erase(actor_id)
	activity_ended.emit(actor_id, activity_id, reason)


func interrupt_for_dialogue(actor_id: StringName, context: Dictionary = {}) -> Dictionary:
	var activity_id: StringName = _active_assignments.get(actor_id, &"")
	if activity_id.is_empty():
		_dialogue_hold[actor_id] = true
		return {}
	var point := definition.get_activity_point(activity_id)
	var snapshot := {
		"activity_id": activity_id,
		"schedule_index": int(_schedule_indices.get(actor_id, 0)),
		"approach_reached": bool(context_approach_reached(actor_id)),
		"context": context.duplicate(),
	}
	_interrupted_states[actor_id] = snapshot
	_dialogue_hold[actor_id] = true
	if point != null and point.exclusive and _occupants.get(activity_id, &"") == actor_id:
		_occupants.erase(activity_id)
	_active_assignments.erase(actor_id)
	activity_ended.emit(actor_id, activity_id, REASON_INTERRUPTED)
	return snapshot.duplicate()


func resume_after_dialogue(actor_id: StringName) -> bool:
	_dialogue_hold[actor_id] = false
	var snapshot: Variant = _interrupted_states.get(actor_id, {})
	if snapshot is Dictionary and not snapshot.is_empty():
		var activity_id: StringName = snapshot.get("activity_id", &"")
		_schedule_indices[actor_id] = int(snapshot.get("schedule_index", 0))
		var context: Dictionary = snapshot.get("context", {})
		if context.is_empty():
			context = {"phase_id": GameState.PHASE_PROLOGUE_DAY, "time_band": &"any"}
		_interrupted_states.erase(actor_id)
		if activity_id.is_empty():
			return false
		if not can_begin(actor_id, activity_id, context):
			return false
		return begin_activity(actor_id, activity_id, context)
	_interrupted_states.erase(actor_id)
	return false


func cancel_after_dialogue(actor_id: StringName) -> void:
	_dialogue_hold[actor_id] = false
	_interrupted_states.erase(actor_id)
	_active_assignments.erase(actor_id)


func context_approach_reached(_actor_id: StringName) -> bool:
	return false


func pick_next_activity(actor_id: StringName, context: Dictionary) -> StringName:
	if definition == null:
		return &""
	var phase_id: StringName = context.get("phase_id", GameState.PHASE_PROLOGUE_DAY)
	var time_band: StringName = context.get("time_band", &"any")
	var seed := int(context.get("seed", 0))
	var sequence := definition.schedule_for(actor_id, phase_id, time_band)
	if sequence.is_empty():
		sequence = definition.visitor_sequence_for(actor_id, phase_id)
	if sequence.is_empty():
		return &""
	var start_index := int(_schedule_indices.get(actor_id, 0)) % maxi(sequence.size(), 1)
	for offset in sequence.size():
		var index := (start_index + offset) % sequence.size()
		var activity_id: StringName = sequence[index]
		if can_begin(actor_id, activity_id, context):
			_schedule_indices[actor_id] = index + 1
			return activity_id
		var fallback_id := resolve_blocked_target(actor_id, activity_id, context)
		if not fallback_id.is_empty() and can_begin(actor_id, fallback_id, context):
			_schedule_indices[actor_id] = index + 1
			return fallback_id
	return &""


func resolve_blocked_target(
	actor_id: StringName,
	activity_id: StringName,
	context: Dictionary
) -> StringName:
	var point := get_activity_point(activity_id)
	if point == null:
		return &""
	if point.exclusive and is_occupied(activity_id) and occupant_of(activity_id) != actor_id:
		if not point.fallback_activity_id.is_empty():
			return point.fallback_activity_id
		return &""
	return resolve_navigation_failure(actor_id, activity_id, context)


func resolve_navigation_failure(
	actor_id: StringName,
	activity_id: StringName,
	context: Dictionary
) -> StringName:
	var point := get_activity_point(activity_id)
	if point == null:
		return &""
	if not point.fallback_activity_id.is_empty() and can_begin(actor_id, point.fallback_activity_id, context):
		return point.fallback_activity_id
	return &""


func report_navigation_failure(actor_id: StringName, activity_id: StringName, context: Dictionary) -> StringName:
	var point := get_activity_point(activity_id)
	var fallback_id := &""
	if point != null and not point.fallback_activity_id.is_empty():
		fallback_id = point.fallback_activity_id
	end_activity(actor_id, REASON_NAVIGATION_FAILED)
	if not fallback_id.is_empty() and can_begin(actor_id, fallback_id, context):
		begin_activity(actor_id, fallback_id, context)
		return fallback_id
	return &""


func requires_approach_before_start(actor_id: StringName, activity_id: StringName, actor_position: Vector2) -> bool:
	var point := get_activity_point(activity_id)
	if point == null:
		return true
	var tolerance := float(MapTypes.DEFAULT_CELL_SIZE) * 0.35
	return actor_position.distance_to(point.approach_position) > tolerance


func _actor_present(actor_id: StringName, context: Dictionary) -> bool:
	if actor_id == &"char.mart" and bool(context.get(FLAG_MART_MISSING, false)):
		return false
	if actor_id == &"char.henning":
		var visitor_allowed := bool(context.get("visitor_allowed", false))
		var phase_id: StringName = context.get("phase_id", GameState.PHASE_PROLOGUE_DAY)
		if phase_id != GameState.PHASE_PROLOGUE_DAY and not visitor_allowed:
			return false
	return true
