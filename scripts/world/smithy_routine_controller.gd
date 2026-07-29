class_name SmithyRoutineController
extends Node

## Reserves smithy activity points, selects deterministic schedules, and handles
## dialogue interruption without coordinate-only patrol loops (P2-058).
## Kalev domestic presentation helpers (P2-059) stay player-driven: prop states
## and held-item sockets update without autonomous player locomotion.

signal activity_began(actor_id: StringName, activity_id: StringName)
signal activity_ended(actor_id: StringName, activity_id: StringName, reason: StringName)
signal presentation_changed(prop_variants: Dictionary, held_socket: StringName)

const REASON_COMPLETED := &"completed"
const REASON_CANCELLED := &"cancelled"
const REASON_INTERRUPTED := &"interrupted"
const REASON_BLOCKED := &"blocked"
const REASON_NAVIGATION_FAILED := &"navigation_failed"

const FLAG_MART_MISSING := &"mart_missing"
const KALEV_ID := &"char.kalev"
const SMITHY_LOCATION_ID := &"loc.kalev_smithy"
const STATION_TOLERANCE_PX := float(MapTypes.DEFAULT_CELL_SIZE) * 0.35

const PointScript := preload("res://scripts/world/smithy_activity_point.gd")
const DefinitionScript := preload("res://scripts/world/smithy_routine_definition.gd")
const DayNightCycle := preload("res://scripts/global/day_night_cycle.gd")

var definition: SmithyRoutineDefinition
var presentation: Dictionary = {}

var _occupants: Dictionary = {}
var _active_assignments: Dictionary = {}
var _schedule_indices: Dictionary = {}
var _interrupted_states: Dictionary = {}
var _dialogue_hold: Dictionary = {}
var _presentation_held_socket: StringName = &""
var _station_reservations: Node


func _ready() -> void:
	if definition == null:
		definition = DefinitionScript.load_from_file()


func configure(next_definition: SmithyRoutineDefinition) -> void:
	definition = next_definition
	reset_runtime_state()


func set_station_reservations(reservations: Node) -> void:
	if _station_reservations == reservations:
		return
	if _station_reservations != null:
		for actor_id: StringName in _active_assignments.keys():
			_station_reservations.call(&"release_actor", actor_id)
	_station_reservations = reservations
	if _station_reservations == null:
		return
	for actor_id: StringName in _active_assignments.keys().duplicate():
		var activity_id: StringName = _active_assignments[actor_id]
		var point := get_activity_point(activity_id)
		if not bool(_station_reservations.call(&"try_reserve", actor_id, activity_id, point)):
			end_activity(actor_id, REASON_BLOCKED)


func configure_from_file(path: String) -> void:
	var next_definition := DefinitionScript.load_from_file(path)
	configure(next_definition)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		load_presentation_from_dict(parsed as Dictionary)


func load_presentation_from_dict(data: Dictionary) -> void:
	presentation = data.get("presentation", {}) as Dictionary


func reset_runtime_state() -> void:
	if _station_reservations != null:
		for actor_id: StringName in _active_assignments.keys():
			_station_reservations.call(&"release_actor", actor_id)
	_occupants.clear()
	_active_assignments.clear()
	_schedule_indices.clear()
	_interrupted_states.clear()
	_dialogue_hold.clear()
	_presentation_held_socket = &""


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
	if _station_reservations != null and not bool(
		_station_reservations.call(&"can_reserve", actor_id, activity_id, point)
	):
		return false
	return true


func begin_activity(actor_id: StringName, activity_id: StringName, context: Dictionary) -> bool:
	if not can_begin(actor_id, activity_id, context):
		return false
	var point := definition.get_activity_point(activity_id)
	if point == null:
		return false
	if _station_reservations != null and not bool(
		_station_reservations.call(&"try_reserve", actor_id, activity_id, point)
	):
		return false
	if point.exclusive:
		_occupants[activity_id] = actor_id
	_active_assignments[actor_id] = activity_id
	activity_began.emit(actor_id, activity_id)
	return true


func end_activity(actor_id: StringName, reason: StringName = REASON_COMPLETED) -> void:
	var activity_id: StringName = _active_assignments.get(actor_id, &"")
	if activity_id.is_empty():
		if _station_reservations != null:
			_station_reservations.call(&"release_actor", actor_id)
		return
	if _occupants.get(activity_id, &"") == actor_id:
		_occupants.erase(activity_id)
	_active_assignments.erase(actor_id)
	if _station_reservations != null:
		_station_reservations.call(&"release_actor", actor_id)
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
	if _station_reservations != null:
		_station_reservations.call(&"release_actor", actor_id)
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
	if _station_reservations != null:
		_station_reservations.call(&"release_actor", actor_id)


func runtime_snapshot_for(actor_id: StringName) -> Dictionary:
	return {
		"active_activity": String(active_activity_for(actor_id)),
		"schedule_index": int(_schedule_indices.get(actor_id, 0)),
		"dialogue_hold": bool(_dialogue_hold.get(actor_id, false)),
		"interrupted": (_interrupted_states.get(actor_id, {}) as Dictionary).duplicate(true),
	}


func restore_runtime_snapshot_for(
	actor_id: StringName,
	snapshot: Dictionary,
	context: Dictionary
) -> bool:
	end_activity(actor_id, REASON_CANCELLED)
	_schedule_indices[actor_id] = int(snapshot.get("schedule_index", 0))
	_dialogue_hold[actor_id] = bool(snapshot.get("dialogue_hold", false))
	var interrupted: Dictionary = snapshot.get("interrupted", {}) as Dictionary
	if interrupted.is_empty():
		_interrupted_states.erase(actor_id)
	else:
		_interrupted_states[actor_id] = interrupted.duplicate(true)
	var activity_id := StringName(String(snapshot.get("active_activity", "")))
	if activity_id.is_empty() or _dialogue_hold[actor_id]:
		return activity_id.is_empty()
	return begin_activity(actor_id, activity_id, context)


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


static func time_band_for_cycle_progress(progress: float) -> StringName:
	var hour := DayNightCycle.progress_to_hour(progress)
	if hour >= 5.0 and hour < 7.0:
		return &"dawn"
	if hour >= 7.0 and hour < 11.0:
		return &"morning"
	if hour >= 11.0 and hour < 14.0:
		return &"midday"
	if hour >= 17.0 and hour < 21.0:
		return &"evening"
	return &"any"


func build_kalev_context(state: GameState, time_band: StringName, extra: Dictionary = {}) -> Dictionary:
	var context := {
		"phase_id": GameState.PHASE_PROLOGUE_DAY,
		"time_band": time_band,
		"seed": 1343,
		"mart_missing": true,
		"visitor_allowed": false,
	}
	if state != null:
		context["phase_id"] = state.get_phase()
		context["mart_missing"] = state.get_flag(&"mart_missing")
	for key in extra.keys():
		context[key] = extra[key]
	return context


func list_available_activities(actor_id: StringName, context: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	if definition == null:
		return result
	var phase_id: StringName = context.get("phase_id", GameState.PHASE_PROLOGUE_DAY)
	var time_band: StringName = context.get("time_band", &"any")
	var sequence := definition.schedule_for(actor_id, phase_id, time_band)
	for activity_id in sequence:
		if can_begin(actor_id, activity_id, context):
			result.append(activity_id)
	var any_sequence := definition.schedule_for(actor_id, phase_id, &"any")
	for activity_id in any_sequence:
		if result.has(activity_id):
			continue
		if can_begin(actor_id, activity_id, context):
			result.append(activity_id)
	return result


func phase_entry_prop_variants(phase_id: StringName, time_band: StringName) -> Dictionary:
	var phase_entry: Variant = presentation.get("phase_entry", {})
	if not phase_entry is Dictionary:
		return {}
	var phase_map: Dictionary = phase_entry.get(phase_id, {}) as Dictionary
	if phase_map.is_empty():
		phase_map = phase_entry.get(String(phase_id), {}) as Dictionary
	var band_map: Variant = phase_map.get(time_band, {})
	if not band_map is Dictionary:
		band_map = phase_map.get(String(time_band), {})
	return _string_keyed_variant_map(band_map as Dictionary)


func activity_effect(activity_id: StringName) -> Dictionary:
	var effects: Variant = presentation.get("activity_effects", {})
	if not effects is Dictionary:
		return {}
	var effect: Variant = effects.get(activity_id, {})
	if not effect is Dictionary:
		effect = effects.get(String(activity_id), {})
	return (effect as Dictionary).duplicate(true)


func activity_prop_variants(activity_id: StringName) -> Dictionary:
	var effect := activity_effect(activity_id)
	var props: Variant = effect.get("props", {})
	if props is Dictionary:
		return _string_keyed_variant_map(props as Dictionary)
	return {}


func activity_held_socket(activity_id: StringName) -> StringName:
	var effect := activity_effect(activity_id)
	var point := get_activity_point(activity_id)
	var socket := StringName(str(effect.get("held_socket", "")))
	if socket.is_empty() and point != null:
		socket = point.hand_prop_socket
	return socket


func activity_body_socket(activity_id: StringName) -> StringName:
	var effect := activity_effect(activity_id)
	var socket := StringName(str(effect.get("body_socket", "")))
	if socket.is_empty():
		var point := get_activity_point(activity_id)
		if point != null:
			socket = point.body_socket
	return socket


func station_within_tolerance(actor_position: Vector2, activity_id: StringName) -> bool:
	var point := get_activity_point(activity_id)
	if point == null:
		return false
	return actor_position.distance_to(point.approach_position) <= STATION_TOLERANCE_PX


func station_facing(activity_id: StringName) -> Vector2:
	var point := get_activity_point(activity_id)
	if point == null:
		return Vector2.DOWN
	return point.facing


func presentation_held_socket() -> StringName:
	return _presentation_held_socket


func clear_presentation_held_socket() -> void:
	_presentation_held_socket = &""


func apply_kalev_activity_presentation(activity_id: StringName, context: Dictionary) -> Dictionary:
	var prop_variants := activity_prop_variants(activity_id)
	_presentation_held_socket = activity_held_socket(activity_id)
	presentation_changed.emit(prop_variants, _presentation_held_socket)
	if not activity_id.is_empty() and can_begin(KALEV_ID, activity_id, context):
		begin_activity(KALEV_ID, activity_id, context)
	return prop_variants


func complete_kalev_activity_presentation(activity_id: StringName, reason: StringName = REASON_COMPLETED) -> void:
	if active_activity_for(KALEV_ID) == activity_id:
		end_activity(KALEV_ID, reason)
	_presentation_held_socket = &""
	presentation_changed.emit({}, &"")


func persist_prop_variants(state: GameState, prop_variants: Dictionary) -> void:
	if state == null:
		return
	for prop_key in prop_variants.keys():
		var prop_id := StringName(String(prop_key))
		var variant := String(prop_variants[prop_key])
		state.map_world_state.record_object_delta(
			SMITHY_LOCATION_ID,
			prop_id,
			{"style_variant": variant}
		)


func restore_prop_variants_from_state(state: GameState, definition: MapDefinition) -> Dictionary:
	var restored := {}
	if state == null or definition == null:
		return restored
	for prop in definition.props:
		var prop_id: StringName = prop.get("id", &"")
		if prop_id.is_empty():
			continue
		var delta := state.map_world_state.object_delta(SMITHY_LOCATION_ID, prop_id)
		if delta.has("style_variant"):
			var variant := StringName(String(delta["style_variant"]))
			prop["style_variant"] = variant
			restored[String(prop_id)] = String(variant)
	return restored


static func _string_keyed_variant_map(source: Dictionary) -> Dictionary:
	var result := {}
	for key in source.keys():
		result[String(key)] = String(source[key])
	return result
